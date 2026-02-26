---
name: solidity-deployer
description: >
  Deployment gate for Solidity contracts. Use before any deployment to testnet, mainnet, or
  public fork environments. Triggers on: "deploy this contract", "run the deploy script",
  "let's go to testnet", "deploy to mainnet", "how do I deploy", "deployment configuration",
  or any mention of broadcasting transactions or deploy scripts. Enforces: forge script (not forge
  create), pre-deployment checklist, simulation before broadcast, on-chain verification,
  multisig ownership transfer, and deployment manifest generation. No manual deployments allowed.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge, cast)
metadata:
  author: Zaryab
  version: "1.0"
---

## When

Before any deployment to any network — testnet, mainnet, or any public fork.
Also when the user says "deploy this", "run the deploy script", "let's go to mainnet",
or asks about deployment configuration or gas estimation.

## The strict rules

```
NO MANUAL DEPLOYMENTS. ALL DEPLOYMENTS VIA FORGE SCRIPTS WITH SIMULATION FIRST AND ON-CHAIN VERIFICATION.
```

No `forge create`. No Remix deployments. No Hardhat deploy scripts.
Every deployment must be:
1. A `Script` contract in `script/Deploy<ContractName>.s.sol`
2. Run as a dry-run simulation first (no `--broadcast`)
3. Run with `--broadcast --verify` together (not verified separately)
4. Documented in a deployment manifest

## Hard Gate

No deployment proceeds until the pre-deployment checklist is complete. Every item must pass.

## Mandatory Checklist

### Pre-Deployment Checklist (All Items Must Pass)

| # | Check | Command | Expected Result |
|---|---|---|---|
| 1 | All tests pass (unit, fuzz, invariant, fork) | `forge test` | 0 failures, 0 errors |
| 2 | No compiler warnings | `forge build` | Exit code 0, no warnings in output |
| 3 | No `console.log` / `console2.log` in `src/` | `grep -rn "console" src/` | No matches |
| 4 | No `TODO` or `FIXME` in `src/` | `grep -rn "TODO\|FIXME" src/` | No matches |
| 5 | No test-only imports in `src/` | `grep -rn "forge-std/Test\|forge-std/console" src/` | No matches |
| 6 | Slither clean (all findings triaged) | `slither . --filter-paths "test,script,lib"` | No untriaged High/Critical |
| 7 | Gas snapshot committed | `git status .gas-snapshot` | File is committed |
| 8 | Contract size under 24,576 bytes | `forge build --sizes` | All contracts < 24576 bytes |
| 9 | All NatSpec complete | Manual review | No undocumented public/external functions |
| 10 | Config file exists for target network | `cat script/config/<network>.json` | File exists and is correct |
| 11 | Multisig address verified in config | Review `script/config/<network>.json` | `multisig` field is a verified safe address |
| 12 | Deploy script ends with ownership transfer | Manual review of deploy script | `transferOwnership(multisig)` is last call |

## Deployment Script Structure

### Directory Layout

```
script/
├── Deploy<ContractName>.s.sol     # Main deployment script
├── DeployProxy<ContractName>.s.sol # Proxy deployment script (if upgradeable)
└── config/
    ├── mainnet.json               # Mainnet constructor args + addresses
    ├── sepolia.json               # Sepolia testnet args
    ├── arbitrum.json              # Arbitrum mainnet args (if multi-chain)
    └── base.json                  # Base mainnet args (if multi-chain)
```

### Config File Format (network-specific parameters)

```json
{
  "network": "mainnet",
  "chainId": 1,
  "asset": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "multisig": "0x<gnosis-safe-address>",
  "treasury": "0x<treasury-address>",
  "oracle": "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  "timelockDelay": 86400,
  "initialFeesBps": 100,
  "maxDepositPerTx": "1000000000000000000000000"
}
```

Config files must not contain private keys or mnemonic phrases. Never commit secrets.

### Standard Deployment Script Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IVault} from "../src/interfaces/IVault.sol";

contract DeployVault is Script {
    // ── Configuration ─────────────────────────────────────────────────────────
    string constant CONFIG_PATH_PREFIX = "script/config/";

    function run() public {
        // 1. Load network config
        string memory network = vm.envString("NETWORK"); // e.g., "sepolia", "mainnet"
        string memory configPath = string.concat(CONFIG_PATH_PREFIX, network, ".json");
        string memory config = vm.readFile(configPath);

        address asset      = vm.parseJsonAddress(config, ".asset");
        address multisig   = vm.parseJsonAddress(config, ".multisig");
        uint256 initialFee = vm.parseJsonUint(config, ".initialFeesBps");

        console2.log("Network:  ", network);
        console2.log("Asset:    ", asset);
        console2.log("Multisig: ", multisig);
        console2.log("Fee:      ", initialFee, "bps");

        // 2. Simulation: verify config is correct before spending gas
        // This block runs without --broadcast for dry-run verification
        require(asset != address(0), "DeployVault: asset address is zero");
        require(multisig != address(0), "DeployVault: multisig address is zero");
        require(initialFee <= 1000, "DeployVault: initial fee exceeds max (1000 bps)");

        // 3. Deploy
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));

        Vault vault = new Vault(asset);
        console2.log("Vault deployed at:", address(vault));

        // 4. Post-deploy configuration (before ownership transfer)
        vault.setFee(initialFee);
        console2.log("Fee set to:", initialFee, "bps");

        // 5. Transfer ownership to multisig LAST
        // This must be the final step — deployer loses all privileged access
        vault.transferOwnership(multisig);
        console2.log("Ownership transferred to multisig:", multisig);

        vm.stopBroadcast();

        // 6. Write deployment manifest
        string memory manifest = vm.serializeAddress("manifest", "address", address(vault));
        manifest = vm.serializeAddress("manifest", "owner", multisig);
        manifest = vm.serializeUint("manifest", "blockNumber", block.number);
        manifest = vm.serializeString("manifest", "network", network);
        manifest = vm.serializeString("manifest", "commitHash",
            vm.envOr("COMMIT_HASH", string("unknown")));
        vm.writeJson(manifest, string.concat("deployments/", network, "/Vault.json"));
    }
}
```

### Upgradeable Contract Deployment Script

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultV1} from "../src/VaultV1.sol";

contract DeployProxyVault is Script {
    function run() public {
        string memory network = vm.envString("NETWORK");
        string memory config = vm.readFile(string.concat("script/config/", network, ".json"));

        address asset    = vm.parseJsonAddress(config, ".asset");
        address multisig = vm.parseJsonAddress(config, ".multisig");

        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));

        // 1. Deploy implementation (do NOT initialize implementation directly)
        VaultV1 implementation = new VaultV1();
        console2.log("Implementation deployed at:", address(implementation));

        // 2. Encode initialize() call for proxy constructor
        bytes memory initData = abi.encodeCall(
            VaultV1.initialize,
            (asset, msg.sender) // use deployer as initial owner — transfer to multisig below
        );

        // 3. Deploy proxy pointing to implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        VaultV1 vault = VaultV1(address(proxy));
        console2.log("Proxy deployed at:", address(proxy));

        // 4. Post-deploy configuration
        vault.setFee(100); // 1% initial fee

        // 5. Transfer ownership to multisig LAST
        vault.transferOwnership(multisig);
        console2.log("Ownership transferred to multisig:", multisig);

        vm.stopBroadcast();

        // 6. Write manifest with both proxy and implementation addresses
        string memory manifest = vm.serializeAddress("manifest", "proxy", address(proxy));
        manifest = vm.serializeAddress("manifest", "implementation", address(implementation));
        manifest = vm.serializeAddress("manifest", "owner", multisig);
        manifest = vm.serializeUint("manifest", "blockNumber", block.number);
        vm.writeJson(manifest, string.concat("deployments/", network, "/VaultProxy.json"));
    }
}
```

## Forge Commands

```bash
# Step 1: Dry run (no --broadcast) — ALWAYS run this first
NETWORK=sepolia DEPLOYER_KEY=$DEPLOYER_KEY \
  forge script script/DeployVault.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_KEY \
  -vvvv

# Step 2: Verify the dry run output looks correct, then broadcast
NETWORK=sepolia DEPLOYER_KEY=$DEPLOYER_KEY COMMIT_HASH=$(git rev-parse HEAD) \
  forge script script/DeployVault.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_KEY \
  -vvvv

# For mainnet: use --slow flag to pace transaction submissions
NETWORK=mainnet DEPLOYER_KEY=$DEPLOYER_KEY COMMIT_HASH=$(git rev-parse HEAD) \
  forge script script/DeployVault.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $DEPLOYER_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_KEY \
  --slow \
  -vvvv
```

## Post-Deployment Verification

### Verification Checklist

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Source code verified on explorer | Check Etherscan manually | "Contract Source Code Verified" shown |
| 2 | Owner is multisig, not EOA | `cast call <addr> "owner()(address)"` | Multisig address |
| 3 | Fee set correctly | `cast call <addr> "withdrawalFeeBps()(uint256)"` | Expected value |
| 4 | Proxy → implementation slot (if proxy) | `cast storage <proxy> <slot>` | Implementation address |
| 5 | Deployment manifest written | `cat deployments/<network>/<contract>.json` | File exists with correct values |
| 6 | Block explorer shows correct constructor args | Manual review on Etherscan | Matches config file |

### Verification Commands

```bash
# Verify owner is multisig, NOT deployer EOA
cast call $CONTRACT_ADDRESS "owner()(address)" --rpc-url $RPC_URL
# Expected: multisig address

# Verify basic function call returns expected values
cast call $CONTRACT_ADDRESS "withdrawalFeeBps()(uint256)" --rpc-url $RPC_URL
# Expected: 100 (1%)

# For upgradeable contracts: verify proxy storage slots
# EIP-1967 implementation slot
cast storage $PROXY_ADDRESS \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url $RPC_URL
# Expected: implementation address

# EIP-1967 admin slot (Transparent proxy only)
cast storage $PROXY_ADDRESS \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 \
  --rpc-url $RPC_URL
# Expected: ProxyAdmin address
```

## Output Artifacts

- `script/Deploy<ContractName>.s.sol` — deployment script
- `script/config/<network>.json` — network-specific configuration
- `deployments/<network>/<ContractName>.json` — deployment manifest

### Deployment Manifest Format

`deployments/<network>/<ContractName>.json`

```json
{
  "name": "Vault",
  "address": "0x1234...abcd",
  "proxy": "0x1234...abcd",
  "implementation": "0xabcd...1234",
  "network": "mainnet",
  "chainId": 1,
  "blockNumber": 19500000,
  "txHash": "0x...",
  "deployer": "0x... (EOA, not multisig)",
  "owner": "0x... (multisig address)",
  "constructorArgs": {
    "asset": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  },
  "config": {
    "initialFeesBps": 100
  },
  "verified": true,
  "verificationUrl": "https://etherscan.io/address/0x...",
  "timestamp": "2025-01-15T10:30:00Z",
  "commitHash": "abc123def456..."
}
```

The manifest is a first-class project artifact. Commit it alongside the code.

## Terminal State

Deployment complete. Exit to:
- `solidity-upgrader` — if future upgrades are planned (pre-register the upgrade path)
- `solidity-audit-prep` — if preparing for external audit
- Done — if this is a final production deployment with no further changes planned

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "It's just a testnet deploy, I don't need a script" | Testnet deploys establish patterns. A bad testnet deploy script becomes the mainnet deploy script. |
| "I'll verify the contract later" | Unverified contracts cannot be audited or trusted. `--verify` runs in the same command as `--broadcast`. There is no "later." |
| "The deployer can transfer ownership after deployment" | "After" is when keys get compromised. The ownership transfer is the last line of the deploy script, not a TODO. |
| "I'll write the manifest manually" | Manual manifests are wrong. Write it from the script output. |
| "forge create is faster" | Speed is not a value in production deployments. Reproducibility is. |
| "We can skip slither for testnet" | Slither is run before testnet too. Deploying unreviewed code to any public network is a security risk. |
