# Skill PRD: `solidity-upgrader`

**Output file:** `skills/solidity-upgrader/SKILL.md`
**Supporting file:** `skills/solidity-upgrader/proxy-pattern-guide.md`

**When:** Before implementing any proxy upgrade — writing the new implementation, preparing
the upgrade transaction, or executing the upgrade call. Also when the user mentions "add V2",
"upgrade the contract", "change the implementation", "I need to add a new feature to the
deployed contract", or asks about proxy patterns or storage layout.

---

## Why This Skill Exists

Proxy upgrades are the highest-risk operation in the Solidity lifecycle. A storage layout collision
silently corrupts all existing user data. An unprotected `_authorizeUpgrade` allows anyone to
replace the contract with arbitrary code. An unversioned initializer allows re-initialization of
the new implementation with attacker-controlled parameters.

The common thread: upgrade mistakes don't produce an error. They silently corrupt or take over.
You only find out when an exploit happens. This skill prevents that by making storage layout
verification and fork testing mandatory before any upgrade transaction is submitted.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-upgrader
description: >
  Upgrade gate for proxy-based upgradeable Solidity contracts. Use before implementing or
  executing any proxy upgrade — adding V2 logic, preparing upgrade transactions, or changing
  implementations. Triggers on: "upgrade the contract", "add V2", "change implementation",
  "implement a new version", "proxy upgrade", "UUPSUpgradeable", "TransparentUpgradeableProxy",
  "storage layout collision", or any intent to modify a deployed upgradeable contract. Enforces:
  storage layout diff verification (forge inspect), no slot shifting or removal, __gap management,
  versioned initializers, fork test before mainnet upgrade, and multisig upgrade execution.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge, cast)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO UPGRADE WITHOUT STORAGE LAYOUT DIFF VERIFICATION AND FORK TEST CONFIRMATION
```

---

## Hard Gate

No upgrade transaction is submitted until:
1. Storage layout of old and new implementation are exported and diffed
2. Diff confirms: no existing slot is shifted, renamed, or removed
3. New variables only appear at the end of storage (or fill `__gap` slots)
4. Inheritance order is identical between old and new implementation
5. Fork test confirms the upgrade succeeds and all post-upgrade functionality works
6. All existing tests pass with the new implementation

---

## Storage Layout Rules

### Rule 1: Append-Only State Variables

The cardinal rule of upgradeable contracts: never change the position of an existing storage
variable. Adding variables is safe only at the end.

```solidity
// ─── V1 Implementation ───────────────────────────────────────────────────────
contract VaultV1 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public withdrawalFeeBps;     // slot 0 (inherited slots come first)
    address public feeRecipient;         // slot 1
    bool public depositsPaused;          // slot 2 (packed in same slot as feeRecipient if ordered correctly)

    // Gap: reserve future slots in one declaration
    // Size = 50 minus the number of storage slots used above
    // Counts INHERITED slots too — run forge inspect to know the true count
    uint256[47] private __gap;           // slots 3-49
}

// ─── V2 Implementation — CORRECT ─────────────────────────────────────────────
contract VaultV2 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public withdrawalFeeBps;     // slot 0 — UNCHANGED
    address public feeRecipient;         // slot 1 — UNCHANGED
    bool public depositsPaused;          // slot 2 — UNCHANGED
    uint256 public performanceFee;       // slot 3 — NEW variable fills first gap slot
    address public strategyAdapter;      // slot 4 — NEW variable fills second gap slot

    uint256[45] private __gap;           // slots 5-49 — gap SHRINKS by 2 (was 47, now 45)
}

// ─── V2 Implementation — WRONG (storage collision) ───────────────────────────
contract VaultV2Bad is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public performanceFee;       // WRONG — now at slot 0, was withdrawalFeeBps
    uint256 public withdrawalFeeBps;     // WRONG — now at slot 1, was slot 0
    address public feeRecipient;         // WRONG — now at slot 2, was slot 1
    bool public depositsPaused;          // WRONG — shifted out of alignment
    address public strategyAdapter;      // ...all data in storage is now corrupted
}
```

### Rule 2: Inheritance Order Must Not Change

The order of parent contracts determines storage slot assignment for inherited state variables:

```solidity
// V1: ERC4626Upgradeable storage comes first, then OwnableUpgradeable
contract VaultV1 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable { }

// V2 CORRECT: same inheritance order
contract VaultV2 is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable { }

// V2 WRONG: swapped OwnableUpgradeable and ERC4626Upgradeable — all inherited slots shift
contract VaultV2Bad is Initializable, OwnableUpgradeable, ERC4626Upgradeable, UUPSUpgradeable { }
```

### Rule 3: `__gap` Management

The `__gap` size must equal: `(reserved slots) - (new variables added this version)`.

Classic rule of thumb: reserve 50 slots total in the gap, minus inherited contract slots.
Use `forge inspect` to see the actual inherited layout:

```bash
forge inspect VaultV1 storage-layout --pretty
```

Count slots used, calculate remaining gap:
```
Total reserved = 50
Inherited slots (from ERC4626Upgradeable, OwnableUpgradeable) = let's say 3
V1 own state variables = 3 (withdrawalFeeBps, feeRecipient, depositsPaused)
V1 gap size = 50 - 3 - 3 = 44

V2 adds 2 new variables
V2 gap size = 44 - 2 = 42
```

An off-by-one in the gap size is storage corruption. The coding agent must run `forge inspect`
on both V1 and V2 and verify the numbers match exactly.

---

## Pre-Upgrade Checklist (Mandatory — All Items Must Pass)

| # | Check | Command | Expected Result |
|---|---|---|---|
| 1 | Export V1 (old) storage layout | `forge inspect OldImpl storage-layout --pretty > old-layout.txt` | File created |
| 2 | Export V2 (new) storage layout | `forge inspect NewImpl storage-layout --pretty > new-layout.txt` | File created |
| 3 | Diff the layouts | `diff old-layout.txt new-layout.txt` | Only additions at end; no changes to existing slots |
| 4 | Verify inheritance order unchanged | Manual review | All parent contracts in same order |
| 5 | `__gap` size decremented correctly | Manual count | gap size = old_gap - new_variables_added |
| 6 | New initializer is versioned | Manual review | New logic uses `initializeV2()` with `reinitializer(2)` |
| 7 | `_disableInitializers()` in new constructor | Manual review | `constructor() { _disableInitializers(); }` present |
| 8 | `_authorizeUpgrade` has correct access control | Manual review | Not empty, has `onlyOwner` or role check |
| 9 | All existing tests pass | `forge test` | 0 failures |
| 10 | New tests for new functionality pass | `forge test --match-contract V2Test` | 0 failures |
| 11 | Fork test of upgrade succeeds | `forge test --match-contract UpgradeFork` | 0 failures |

---

## Versioned Initializers

Each new implementation version that adds state must have a versioned initializer:

```solidity
// V1: standard initializer
function initialize(address asset_, address initialOwner) external initializer {
    __ERC4626_init(IERC20(asset_));
    __Ownable_init(initialOwner);
    __UUPSUpgradeable_init();
}

// V2: CANNOT re-run initialize(). New logic goes in initializeV2()
// The reinitializer(2) modifier ensures this can only run once, and only on V2+
function initializeV2(address strategyAdapter_) external reinitializer(2) {
    // Initialize new state variables only
    strategyAdapter = strategyAdapter_;
    performanceFee = 0;
    // Do NOT call __ERC4626_init etc. — those already ran in V1's initialize()
}
```

**Upgrade execution sequence in script:**

```solidity
// script/UpgradeVaultV2.s.sol
contract UpgradeVaultV2 is Script {
    function run() public {
        string memory config = vm.readFile("script/config/mainnet.json");
        address proxy        = vm.parseJsonAddress(config, ".proxy");
        address multisig     = vm.parseJsonAddress(config, ".multisig");
        address strategy     = vm.parseJsonAddress(config, ".strategyAdapter");

        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));

        // 1. Deploy new implementation
        VaultV2 newImpl = new VaultV2();
        console2.log("New implementation:", address(newImpl));

        // 2. Upgrade proxy and call initializeV2 atomically
        // upgradeToAndCall prevents a window where the upgrade is live but uninitialized
        bytes memory initData = abi.encodeCall(VaultV2.initializeV2, (strategy));
        UUPSUpgradeable(proxy).upgradeToAndCall(address(newImpl), initData);

        vm.stopBroadcast();

        // 3. Verify new implementation is active
        address activeImpl = address(uint160(uint256(
            vm.load(proxy, 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
        )));
        require(activeImpl == address(newImpl), "Upgrade failed: wrong implementation");
        console2.log("Upgrade verified. New impl:", activeImpl);
    }
}
```

---

## Fork Test for Upgrade

A fork test is mandatory to prove the upgrade works on real mainnet state:

```solidity
// test/fork/VaultUpgrade.fork.t.sol
contract VaultUpgradeForkTest is Test {
    address constant PROXY = 0x1234...;   // deployed V1 proxy address
    address constant MULTISIG = 0xabcd...; // current owner

    IVault vault;
    VaultV2 newImpl;

    function setUp() public {
        // Pin to block where V1 is deployed
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19_500_000);
        vault = IVault(PROXY);
    }

    function test_fork_upgrade_preservesExistingState() public {
        // Capture pre-upgrade state
        uint256 preTotalAssets = vault.totalAssets();
        uint256 preTotalSupply = vault.totalSupply();
        address preOwner       = OwnableUpgradeable(address(vault)).owner();

        // Deploy and apply upgrade as multisig
        newImpl = new VaultV2();
        vm.prank(MULTISIG);
        UUPSUpgradeable(address(vault)).upgradeToAndCall(
            address(newImpl),
            abi.encodeCall(VaultV2.initializeV2, (STRATEGY_ADAPTER))
        );

        // Verify storage is intact after upgrade
        assertEq(vault.totalAssets(), preTotalAssets, "Fork: totalAssets corrupted by upgrade");
        assertEq(vault.totalSupply(), preTotalSupply, "Fork: totalSupply corrupted by upgrade");
        assertEq(OwnableUpgradeable(address(vault)).owner(), preOwner, "Fork: owner changed by upgrade");

        // Verify new functionality works
        VaultV2 vaultV2 = VaultV2(address(vault));
        assertNotEq(vaultV2.strategyAdapter(), address(0), "Fork: strategyAdapter not initialized");
    }

    function test_fork_upgrade_newFunctionalityWorks() public {
        // ... test new V2 features
    }
}
```

---

## Supporting File: proxy-pattern-guide.md

This file lives at `skills/solidity-upgrader/proxy-pattern-guide.md`.

### Required Content

**Section 1: Pattern Comparison Table**

| Pattern | When to Use | Upgrade Location | Key Risk | OZ Contract |
|---|---|---|---|---|
| **UUPS** | Default for new projects. Cheaper proxy. Can become non-upgradeable. | Implementation (`_authorizeUpgrade`) | Empty `_authorizeUpgrade` = anyone can upgrade | `UUPSUpgradeable` |
| **Transparent** | When admin must never call user functions accidentally. | Proxy (`ProxyAdmin`) | More expensive. ProxyAdmin adds complexity. | `TransparentUpgradeableProxy` |
| **Beacon** | Factory: many identical proxies sharing one impl. | Beacon contract | Single point of failure: bad upgrade breaks all. | `BeaconProxy`, `UpgradeableBeacon` |
| **Diamond (EIP-2535)** | Truly modular multiple-facet contracts. Rarely the right choice. | Multiple facets | Extreme complexity. Storage collision risk across facets. | N/A |

**Section 2: UUPS Security Checklist**

```
[ ] _authorizeUpgrade has access control (not empty)
[ ] _disableInitializers() in implementation constructor
[ ] initializer modifier on initialize() (not just onlyOwner)
[ ] reinitializer(N) for each subsequent version
[ ] upgradeToAndCall() used (not upgradeTo + initialize separately)
[ ] __gap declared and sized correctly
```

**Section 3: Storage Slot References**

```
EIP-1967 implementation slot:
0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

EIP-1967 admin slot (Transparent only):
0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

EIP-1967 beacon slot:
0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
```

**Section 4: Inheritance Layout Examples for Common Patterns**

Show the exact inheritance order for each OZ pattern with the corresponding storage layout output,
so developers can see the correlation between inheritance and storage slots.

---

## Output Artifacts

- `old-layout.txt` — V1 storage layout snapshot (committed to docs/upgrades/)
- `new-layout.txt` — V2 storage layout snapshot (committed to docs/upgrades/)
- `script/UpgradeVaultV2.s.sol` — upgrade script
- Updated deployment manifest in `deployments/<network>/<contract>.json` with new implementation address

---

## Terminal State

After storage layout verified and fork test passes:
- Exit to `solidity-deployer` (to execute the upgrade deployment)
- Exit to `solidity-code-reviewer` (to review the new implementation changes)

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The storage layout is obviously the same" | Run `forge inspect` and diff the outputs. "Obvious" is exactly how storage collisions happen. They look obvious until they're not. |
| "We'll test on mainnet" | Never. Test order: local fork → testnet fork → testnet deployment → mainnet. The fork test is what proves it works on real state. |
| "The upgrade is small — just one new variable" | Small changes to inheritance order cause full storage corruption. The size of the change does not indicate safety. |
| "The `__gap` is still there" | Verify the gap shrunk by exactly the number of new variables added. One wrong slot here corrupts all existing user data. |
| "We can initialize V2 in a separate transaction" | Never. `upgradeToAndCall` atomically upgrades and initializes. A separate initialize call creates a window where the contract is upgraded but uninitialized. |
