# Deployment Checklist

Reference document for `solidity-deployer`. Loaded by the skill when preparing or executing a deployment.

---

## Pre-Deployment Checklist with Remediation

| # | Check | Command | Expected Result | Remediation if Failing |
|---|---|---|---|---|
| 1 | All tests pass | `forge test` | 0 failures, 0 errors | Fix the failing tests. Do not deploy with any test failure. |
| 2 | No compiler warnings | `forge build` | Exit code 0, no warnings | Fix all warnings. Treat every warning as a potential bug. |
| 3 | No `console.log` in `src/` | `grep -rn "console" src/` | No matches | Remove all console statements. They waste gas and leak information. |
| 4 | No `TODO` or `FIXME` in `src/` | `grep -rn "TODO\|FIXME" src/` | No matches | Resolve all outstanding TODOs before deploying. |
| 5 | No test-only imports in `src/` | `grep -rn "forge-std/Test\|forge-std/console" src/` | No matches | Remove forge-std imports from production code. |
| 6 | Slither clean | `slither . --filter-paths "test,script,lib"` | No untriaged High/Critical | Triage each finding: fix it or document why it is a false positive. |
| 7 | Gas snapshot committed | `git status .gas-snapshot` | File is committed | Run `forge snapshot` and commit `.gas-snapshot`. |
| 8 | Contract size under limit | `forge build --sizes` | All contracts < 24576 bytes | Refactor or use libraries. EIP-170 limit is hard. |
| 9 | All NatSpec complete | Manual review | No undocumented public/external functions | Add NatSpec to every public and external function, event, error, and state variable. |
| 10 | Config file exists | `cat script/config/<network>.json` | File exists | Create the config file using the template below. |
| 11 | Multisig address verified | Review config | `multisig` is a Gnosis Safe | Verify the address on the block explorer. It must be a multisig, not an EOA. |
| 12 | Ownership transfer is last call | Manual review | `transferOwnership(multisig)` is last line | Add the ownership transfer as the final call in the deploy script. |

---

## Post-Deployment Checklist

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Source code verified on explorer | Check Etherscan manually | "Contract Source Code Verified" shown |
| 2 | Owner is multisig, not EOA | `cast call <addr> "owner()(address)" --rpc-url $RPC_URL` | Multisig address |
| 3 | Fee / key parameter set correctly | `cast call <addr> "<getter>()(uint256)" --rpc-url $RPC_URL` | Value from config file |
| 4 | Proxy implementation slot (if proxy) | `cast storage <proxy> 0x360894...bbc --rpc-url $RPC_URL` | Implementation address |
| 5 | Deployment manifest written and committed | `cat deployments/<network>/<contract>.json` | File exists with correct values |
| 6 | Constructor args on Etherscan | Manual review | Matches `script/config/<network>.json` |

---

## Network Config Templates

### mainnet.json

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

### sepolia.json

```json
{
  "network": "sepolia",
  "chainId": 11155111,
  "asset": "0x<sepolia-usdc-or-mock-address>",
  "multisig": "0x<test-multisig-or-eoa-for-testnet>",
  "treasury": "0x<treasury-address>",
  "oracle": "0x<sepolia-chainlink-feed>",
  "timelockDelay": 300,
  "initialFeesBps": 100,
  "maxDepositPerTx": "1000000000000000000000000"
}
```

### arbitrum.json

```json
{
  "network": "arbitrum",
  "chainId": 42161,
  "asset": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  "multisig": "0x<gnosis-safe-on-arbitrum>",
  "treasury": "0x<treasury-address>",
  "oracle": "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3",
  "timelockDelay": 86400,
  "initialFeesBps": 100,
  "maxDepositPerTx": "1000000000000000000000000"
}
```

Config files must never contain private keys, mnemonics, or any credentials. Store all secrets in `.env` (gitignored).

---

## Common Deployment Mistakes

### 1. Uninitialized Proxy

**What happens:** The implementation contract is deployed but `initialize()` is not called through the proxy. All state remains at zero values.

**Detection:**
```bash
cast call $PROXY "owner()(address)" --rpc-url $RPC_URL
# Returns: 0x0000000000000000000000000000000000000000
```

**Fix:** Use `ERC1967Proxy(address(implementation), initData)` where `initData` encodes the `initialize()` call. Never deploy a proxy with empty `initData` for a contract that has an initializer.

### 2. Wrong Owner After Deployment

**What happens:** Ownership transfer was forgotten or placed before other configuration calls that require owner access. The multisig now owns the contract, but the deployer already called `transferOwnership` — so the deployer can no longer configure anything.

**Detection:**
```bash
cast call $CONTRACT "owner()(address)" --rpc-url $RPC_URL
# Returns: deployer EOA instead of multisig
```

**Fix:** Ownership transfer must be the absolute last call in the broadcast block. All configuration calls (`setFee`, `setOracle`, etc.) must precede `transferOwnership`.

### 3. Wrong Constructor Arguments

**What happens:** The config file has a stale or wrong address. For example, `asset` points to a testnet token on mainnet.

**Detection:**
```bash
cast call $CONTRACT "asset()(address)" --rpc-url $RPC_URL
# Returns: wrong address
```

**Fix:** The deploy script validates all config addresses with `require(addr != address(0), ...)` checks before broadcasting. Add specific sanity checks for known addresses (e.g., assert the asset is the expected token by checking its symbol).

### 4. Contract Not Verified

**What happens:** `--verify` flag was omitted or the Etherscan API key was wrong. The contract appears on-chain but source code is not visible.

**Detection:** Visit `https://etherscan.io/address/<contract>` — shows "Contract" tab with bytecode only, no source.

**Fix:** Re-run verification manually:
```bash
forge verify-contract $CONTRACT_ADDRESS src/Vault.sol:Vault \
  --etherscan-api-key $ETHERSCAN_KEY \
  --chain mainnet \
  --constructor-args $(cast abi-encode "constructor(address)" $ASSET_ADDRESS)
```

### 5. Missing Deployment Manifest

**What happens:** The manifest was not written (e.g., `vm.writeJson` path was wrong, or the `deployments/` directory did not exist).

**Detection:**
```bash
cat deployments/mainnet/Vault.json
# File not found
```

**Fix:** Create the `deployments/<network>/` directory before running the script. Verify the path in `vm.writeJson` matches. Commit the manifest file.

---

## Environment Variables Reference

The following must be set in `.env` (never committed) before any deployment:

```bash
# Required for all deployments
DEPLOYER_KEY=0x...         # Private key of the deployer EOA (never a multisig key)
NETWORK=mainnet            # Target network (must match a file in script/config/)

# Required for broadcasting (not needed for dry runs)
MAINNET_RPC_URL=https://...
SEPOLIA_RPC_URL=https://...
ARBITRUM_RPC_URL=https://...

# Required for on-chain verification
ETHERSCAN_KEY=...
ARBISCAN_KEY=...           # For Arbitrum deployments
BASESCAN_KEY=...           # For Base deployments

# Optional: captured for the deployment manifest
COMMIT_HASH=$(git rev-parse HEAD)
```

Load them before running scripts:
```bash
source .env
```

---

## Multisig Setup Guidance

### Threshold Recommendations

| TVL / Risk Level | Minimum Threshold |
|---|---|
| Testnet / low TVL | 2 of 3 |
| Production / medium TVL | 3 of 5 |
| High TVL / critical infrastructure | 4 of 7 or higher |

### Gnosis Safe Setup

1. Deploy a new Safe at [app.safe.global](https://app.safe.global) on the target network.
2. Add signers with hardware wallets (Ledger, Trezor) — never software wallets for mainnet multisig.
3. Set the threshold per the table above.
4. Verify the Safe address on the block explorer before using it in the config.
5. Test a small transaction (e.g., ETH send to self) to confirm signer access works.
6. Record the Safe address in `script/config/<network>.json` as the `multisig` field.

### After Ownership Transfer

- The deployer EOA loses all privileged access immediately after `transferOwnership`.
- All future admin calls must go through the Safe's transaction queue.
- Set up role-based Safe apps (e.g., Zodiac Roles module) for operational actions that don't require full multisig sign-off.
- Establish a key rotation plan before going to mainnet.
