# Proxy Pattern Guide

Reference document for `solidity-upgrader`. Loaded by the skill when implementing or auditing a proxy upgrade.

---

## Section 1: Pattern Comparison Table

| Pattern | When to Use | Upgrade Location | Key Risk | OZ Contract |
|---|---|---|---|---|
| **UUPS** | Default for new projects. Cheaper proxy. Can become non-upgradeable. | Implementation (`_authorizeUpgrade`) | Empty `_authorizeUpgrade` = anyone can upgrade | `UUPSUpgradeable` |
| **Transparent** | When admin must never call user functions accidentally. | Proxy (`ProxyAdmin`) | More expensive. ProxyAdmin adds complexity. | `TransparentUpgradeableProxy` |
| **Beacon** | Factory: many identical proxies sharing one impl. | Beacon contract | Single point of failure: bad upgrade breaks all. | `BeaconProxy`, `UpgradeableBeacon` |
| **Diamond (EIP-2535)** | Truly modular multiple-facet contracts. Rarely the right choice. | Multiple facets | Extreme complexity. Storage collision risk across facets. | N/A |

### When to Choose Each Pattern

**UUPS** is the default. Use it unless you have a specific reason not to:
- Lower gas cost (no admin check on every user call)
- The upgrade logic lives in the implementation, so a new implementation can remove upgradeability if needed
- Simpler deployment (no ProxyAdmin contract)

**Transparent** when:
- You have an admin who might accidentally call user functions through the proxy
- You want the upgrade path to be entirely independent of the implementation code
- You are upgrading existing Transparent proxies (do not migrate to UUPS mid-lifecycle)

**Beacon** when:
- You deploy many identical proxies (e.g., per-user vault, per-pool contract)
- You need to upgrade all instances atomically with a single transaction

**Diamond** almost never. The added complexity rarely justifies itself. If you find yourself reaching for Diamond, decompose the contract into separate purpose-specific contracts instead.

---

## Section 2: UUPS Security Checklist

```
[ ] _authorizeUpgrade has access control (not empty)
[ ] _disableInitializers() in implementation constructor
[ ] initializer modifier on initialize() (not just onlyOwner)
[ ] reinitializer(N) for each subsequent version
[ ] upgradeToAndCall() used (not upgradeTo + initialize separately)
[ ] __gap declared and sized correctly
```

### Correct UUPS Implementation Pattern

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract VaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public withdrawalFeeBps;

    // Disable initializers on the implementation contract itself
    // Without this, anyone can initialize the implementation and potentially use it
    // as an attack vector (e.g., self-destruct via delegatecall in older Solidity)
    constructor() {
        _disableInitializers();
    }

    // initializer ensures this can only run once
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        withdrawalFeeBps = 100;
    }

    // _authorizeUpgrade MUST have access control
    // An empty _authorizeUpgrade means ANYONE can upgrade your contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // Reserve storage slots for future variables
    uint256[49] private __gap;
}
```

### Wrong Pattern (Empty `_authorizeUpgrade`)

```solidity
// CRITICAL VULNERABILITY: anyone can upgrade this contract
function _authorizeUpgrade(address) internal override {}
```

---

## Section 3: Storage Slot References

### EIP-1967 Standard Slots

```
EIP-1967 implementation slot:
0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

EIP-1967 admin slot (Transparent proxy only):
0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

EIP-1967 beacon slot:
0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
```

### Reading Slots with Cast

```bash
# Read the current implementation address from a UUPS or Transparent proxy
cast storage $PROXY_ADDRESS \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url $RPC_URL

# Read the ProxyAdmin address from a Transparent proxy
cast storage $PROXY_ADDRESS \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 \
  --rpc-url $RPC_URL

# Read the beacon address from a Beacon proxy
cast storage $PROXY_ADDRESS \
  0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 \
  --rpc-url $RPC_URL
```

### Why These Slots

EIP-1967 slots are computed as `keccak256("eip1967.<purpose>") - 1`. The `-1` offset prevents
the slot from being the direct output of a keccak256 call, making accidental collision
with normal storage variables cryptographically infeasible.

---

## Section 4: Inheritance Layout Examples

The Solidity compiler assigns storage slots starting from slot 0 and proceeding through each parent
contract in the order they appear in the `is` clause (left to right, depth first).

### Example: UUPS + Ownable + ERC4626

```solidity
contract VaultV1 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable
```

Running `forge inspect VaultV1 storage-layout --pretty` produces something like:

```
| Name             | Type    | Slot | Offset | Bytes | Contract              |
|------------------|---------|------|--------|-------|-----------------------|
| _initialized     | uint8   | 0    | 0      | 1     | Initializable         |
| _initializing    | bool    | 0    | 1      | 1     | Initializable         |
| _status          | uint8   | 1    | 0      | 1     | ReentrancyGuardUpgradeable (if used) |
| _name            | string  | 2    | 0      | 32    | ERC20Upgradeable      |
| _symbol          | string  | 3    | 0      | 32    | ERC20Upgradeable      |
| _balances        | mapping | 4    | 0      | 32    | ERC20Upgradeable      |
| _allowances      | mapping | 5    | 0      | 32    | ERC20Upgradeable      |
| _totalSupply     | uint256 | 6    | 0      | 32    | ERC20Upgradeable      |
| _asset           | address | 7    | 0      | 20    | ERC4626Upgradeable    |
| _owner           | address | 8    | 0      | 20    | OwnableUpgradeable    |
| withdrawalFeeBps | uint256 | 9    | 0      | 32    | VaultV1               |
| __gap            | uint256 | 10   | 0      | 32*N  | VaultV1               |
```

The key insight: all inherited slots are fixed by the library (ERC4626Upgradeable, OwnableUpgradeable).
You can only safely append after your own contract's state variables, within your `__gap`.

### Swapping Inheritance Order Causes Corruption

```solidity
// V1 inheritance
contract VaultV1 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable

// V2 with swapped order — WRONG
contract VaultV2 is Initializable, OwnableUpgradeable, ERC4626Upgradeable, UUPSUpgradeable
```

With swapped order, OwnableUpgradeable's `_owner` now occupies the slot that ERC20Upgradeable's
`_name` used to occupy. Every user balance mapping, allowance, and total supply is now reading
from the wrong slot. The contract appears to work but all accounting is silently corrupted.

### Correct V2 with Appended Variables

```solidity
// V2 CORRECT: same inheritance order, new variables appended before __gap
contract VaultV2 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public withdrawalFeeBps;   // slot 9 — same as V1
    uint256 public performanceFee;     // slot 10 — NEW (was first __gap slot in V1)
    address public strategyAdapter;    // slot 11 — NEW (was second __gap slot in V1)

    // __gap shrinks by 2 because we used 2 gap slots
    uint256[N-2] private __gap;        // N = V1 gap size
}
```

After writing V2, always run:
```bash
forge inspect VaultV1 storage-layout --pretty > docs/upgrades/old-layout.txt
forge inspect VaultV2 storage-layout --pretty > docs/upgrades/new-layout.txt
diff docs/upgrades/old-layout.txt docs/upgrades/new-layout.txt
```

The diff should show only additions. Any line showing a change to an existing slot name, type,
or offset is a storage collision. Stop and fix before proceeding.
