# Skill PRD: `solidity-builder`

**Output file:** `skills/solidity-builder/SKILL.md`
**Supporting file:** `skills/solidity-builder/foundry-test-patterns.md`

**When:** After the plan is approved, the design doc is committed, and interfaces are committed.
Before any implementation code is written. This is the TDD implementation gate.

---

## Why This Skill Exists

Tests written after code are biased by the implementation. The writer already knows how the code
behaves — so they test what it does, not what it should do. Tests written first force a
specification: "what must happen here?" The answer is the test. The code is just the cheapest
thing that makes it true.

For Solidity specifically, this matters more than in most languages. A function that works
correctly under normal inputs and silently fails on boundary inputs is a exploit waiting for a
searcher to find the boundary.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-builder
description: >
  TDD implementation gate for Solidity smart contracts. Use after an approved design doc and
  committed interface exist. Triggers on: "implement this", "write the contract", "fill in the
  logic", "implement the interface", "code this up", or any intent to write Solidity
  implementation code. Enforces strict Red-Green-Refactor: no production code without a failing
  Forge test first. Covers: CEI pattern, custom errors, access control, SafeERC20, ReentrancyGuard,
  gas snapshots, and all implementation standards for Solidity ^0.8.20 with Foundry.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO PRODUCTION SOLIDITY WITHOUT A FAILING FORGE TEST FIRST
```

This means:
- Write the test file first
- Run `forge test --match-test <test_name> -vv` and watch it FAIL
- Only then write the implementation
- If the test passes immediately — the test is wrong. Fix it.

Writing code "to get started" and then writing tests to verify it is not TDD. It is testing
after the fact with implementation bias. Delete the code. Start with the test.

---

## Hard Gate

No implementation `.sol` file may be created without a corresponding test file containing
at least one failing test for the function being implemented.

The test file must exist at `test/unit/<ContractName>.t.sol` before `src/<ContractName>.sol`
is touched.

---

## The Foundry RED-GREEN-REFACTOR Cycle

### RED Phase: Write the Failing Test

Start with the revert path, not the happy path. Revert paths are security-critical.
Testing the failure first confirms the guard exists.

```solidity
// test/unit/Vault.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {Vault} from "src/Vault.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 token;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address owner = makeAddr("owner");

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        vm.prank(owner);
        vault = new Vault(address(token));
    }

    // RED: write this BEFORE implementing deposit()
    function test_deposit_revertsWhenPaused() public {
        vm.prank(owner);
        vault.pause();

        deal(address(token), alice, 1000e18);
        vm.startPrank(alice);
        token.approve(address(vault), 1000e18);

        vm.expectRevert(Vault.ContractPaused.selector);
        vault.deposit(1000e18, alice);
        vm.stopPrank();
    }
}
```

Run: `forge test --match-test test_deposit_revertsWhenPaused -vv`

Expected output: FAIL (function not yet implemented, or reverts with wrong error).

**Verify RED — mandatory, never skip:**
- Confirm the test fails, not errors (compilation failure means the test itself has a bug)
- Confirm the failure message is the expected one (wrong revert selector = wrong test)
- Confirm it fails because the feature is missing, not because of a typo

### GREEN Phase: Minimal Implementation

Write the simplest Solidity that makes the test pass. No events yet. No extra validation beyond
what the test requires. No gas optimizations. Just the minimum viable implementation.

```solidity
// src/Vault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Vault is ERC4626, Pausable, Ownable2Step {
    error ContractPaused();

    constructor(address asset_) ERC4626(IERC20(asset_)) ERC20("Vault Share", "vSHARE") Ownable(msg.sender) {}

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }
}
```

Run: `forge test --match-test test_deposit_revertsWhenPaused -vv` → PASS

**Verify GREEN — mandatory:**
- The target test passes
- All previously passing tests still pass (`forge test`)
- No compilation warnings

### REFACTOR Phase: Add Quality

After GREEN, add events, complete NatSpec, cleanup naming. Do not change behavior.
Run `forge test` after every change. Stay green.

---

## Mandatory Checklist

### Test Naming Convention (Strictly Enforced)

All test names must follow this convention — the coding agent must enforce it:

```
Unit tests:       test_<functionName>_<scenario>
Fuzz tests:       testFuzz_<functionName>_<property>
Invariant tests:  invariant_<propertyName>
Fork tests:       test_fork_<scenario>
```

Good names:
- `test_deposit_revertsWhenPaused`
- `test_withdraw_revertsWhenInsufficientBalance`
- `test_deposit_updatesShareBalanceCorrectly`
- `test_setFee_revertsWhenCallerNotOwner`
- `test_setFee_emitsEvent`
- `testFuzz_deposit_sharesNeverExceedAssets`
- `invariant_totalSupplyEqualsSumOfBalances`

Bad names (must be rejected):
- `testDeposit` (no scenario)
- `test1` (meaningless)
- `testPauseAndDepositAndWithdraw` (multiple behaviors — split it)

### Cheatcode Reference (for the SKILL.md)

The SKILL.md must include this reference table:

| Cheatcode | Usage Rule |
|---|---|
| `vm.expectRevert(CustomError.selector)` | Test exact error selectors. For errors with params: `abi.encodeWithSelector(CustomError.selector, param1, param2)`. Never just `vm.expectRevert()` (catches any revert — tests nothing). |
| `vm.expectRevert(abi.encodeWithSelector(Error.selector, param))` | When the custom error includes parameters. Verify the parameters too, not just the selector. |
| `vm.prank(address)` | Single-call context switch. Always test WRONG caller first (should revert), then RIGHT caller (should succeed). |
| `vm.startPrank(address)` / `vm.stopPrank()` | For sequences of calls from the same address. Always pair — unpaired startPrank leaves state dirty. |
| `vm.deal(address, amount)` | Set ETH balances. Use in setUp or test body; never use magic constructor values. |
| `deal(address token, address to, uint256 amount)` | Set ERC-20 balances via storage slot manipulation. The preferred way to set up token state in tests. |
| `vm.warp(uint256 timestamp)` | Time travel. Always test: exactly at threshold, 1 second before, 1 second after. |
| `vm.roll(uint256 blockNumber)` | Block number manipulation. Same boundary principle as warp. |
| `vm.expectEmit(bool, bool, bool, bool)` | Event verification. The four booleans: topic1, topic2, topic3, data. Emit the expected event after calling expectEmit, then call the function. |
| `makeAddr("label")` | Creates deterministic labeled addresses. Use descriptive labels: "alice", "attacker", "admin", "treasury". |
| `vm.label(address, "name")` | Labels addresses for readable forge traces in `-vvvv` output. Always label test actors. |
| `vm.snapshot()` / `vm.revertTo(id)` | State snapshots for complex test branching. Use when the same setUp is expensive and you need multiple scenarios. |
| `vm.mockCall(addr, data, returnData)` | Mock specific calls without full mock contracts. Prefer mock contracts; use mockCall for protocol contracts you can't mock easily. |
| `vm.recordLogs()` / `vm.getRecordedLogs()` | Capture all emitted events. Use when you need to verify events not at the top level of the call. |

### Implementation Order for Each Function (Mandatory)

For every function being implemented, follow this exact order:

1. Write test for unauthorized caller (wrong role/address) → RED → implement access check → GREEN
2. Write test for invalid input (zero, overflow, wrong type) → RED → implement input validation → GREEN
3. Write test for invalid state (paused, wrong phase, precondition false) → RED → implement state check → GREEN
4. Write test for the happy path (correct inputs, correct state, correct caller) → RED → implement logic → GREEN
5. Write test for edge cases (address(0), type(uint256).max, empty array) → RED → implement edge case handling → GREEN
6. Write test for event emission → RED → add emit → GREEN
7. REFACTOR: add complete NatSpec, run `forge snapshot`

**Why revert tests first:** Access control checks must be the FIRST thing in a function body
(fail fast, save gas). Testing them first forces this order.

### Gas Snapshot Protocol

Every time a function implementation is complete:
```bash
forge snapshot
```

Commit `.gas-snapshot` alongside the code. It is a first-class artifact.

When a change is made to implementation:
```bash
forge snapshot --diff
```

If the diff shows unexpected gas increases (>5% on a hot path), investigate before committing.

---

## Implementation Standards

### Standard 1: Checks-Effects-Interactions (Mandatory on Every External-Facing Function)

Every function that makes external calls must follow CEI. No exceptions.

```solidity
function withdraw(uint256 assets, address receiver, address owner)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares)
{
    // ── CHECKS ────────────────────────────────────────────────────────────────
    if (assets == 0) revert ZeroAmount();
    shares = previewWithdraw(assets);
    if (balanceOf(owner) < shares) {
        revert InsufficientShares(owner, shares, balanceOf(owner));
    }
    if (msg.sender != owner) {
        uint256 allowed = allowance(owner, msg.sender);
        if (allowed != type(uint256).max) {
            if (allowed < shares) revert InsufficientAllowance(owner, msg.sender, shares, allowed);
            _approve(owner, msg.sender, allowed - shares, false);
        }
    }

    // ── EFFECTS ───────────────────────────────────────────────────────────────
    _burn(owner, shares);
    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    // ── INTERACTIONS ──────────────────────────────────────────────────────────
    IERC20(asset()).safeTransfer(receiver, assets);
}
```

The comment markers `// ── CHECKS`, `// ── EFFECTS`, `// ── INTERACTIONS` are mandatory in
every function with external calls. They are documentation for auditors.

### Standard 2: Custom Errors — No String Reverts

```solidity
// BAD — never write this
require(amount > 0, "Amount must be greater than zero");
require(msg.sender == owner, "Not authorized");

// GOOD — always write this
error ZeroAmount();
error Unauthorized(address caller, address expected);
error InsufficientBalance(address account, uint256 requested, uint256 available);

// Custom errors with context parameters help auditors and frontend developers
if (amount == 0) revert ZeroAmount();
if (msg.sender != owner) revert Unauthorized(msg.sender, owner);
if (balances[msg.sender] < amount) {
    revert InsufficientBalance(msg.sender, amount, balances[msg.sender]);
}
```

The rule: every `require` statement in any `.sol` file is a bug. Replace it.

### Standard 3: Access Control Patterns

```solidity
// Pattern A: Single admin (most common) — Ownable2Step mandatory
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MyContract is Ownable2Step {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function setFee(uint256 fee) external onlyOwner {
        // access check is onlyOwner modifier — implicitly first
    }
}

// Pattern B: Multi-role (when 2+ distinct roles exist) — AccessControl
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MyContract is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // Access check is ALWAYS the first thing in the function body
    function sensitiveOperation() external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized(msg.sender);
        // logic...
    }
}

// NEVER use tx.origin for authorization — phishable via malicious intermediary contract
// NEVER use msg.sender == owner without inheritance — always use OpenZeppelin patterns
```

### Standard 4: SafeERC20 for All Token Interactions

```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MyContract {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    // Correct: safeTransferFrom + balance delta measurement for fee-on-transfer tokens
    function deposit(uint256 amount) external {
        uint256 before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 actual = token.balanceOf(address(this)) - before;
        // Use `actual`, not `amount` — handles fee-on-transfer tokens
        _mint(msg.sender, actual);
    }
}

// NEVER use: token.transfer(), token.transferFrom() — don't check return values on non-standard tokens
// ALWAYS use: token.safeTransfer(), token.safeTransferFrom()
```

### Standard 5: ReentrancyGuard as Defense-in-Depth

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Even with strict CEI, add nonReentrant to functions that:
// - Make external calls (transfers, external contract calls)
// - Change state and then call external contracts
// - Could be called recursively through complex call chains

contract Vault is ERC4626, ReentrancyGuard {
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant      // defense-in-depth even though CEI is enforced
        whenNotPaused
        returns (uint256 shares)
    {
        // ...
    }
}
```

For upgradeable contracts use `ReentrancyGuardUpgradeable` from OZ's contracts-upgradeable:
```solidity
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
```

### Standard 6: Upgradeable Contract Patterns

When building upgradeable contracts (UUPS pattern):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VaultV1 is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // Storage variables
    uint256 public withdrawalFeeBps;

    // REQUIRED: gap for future storage slots (size = 50 - number of state variables above)
    uint256[49] private __gap;

    // REQUIRED: disables initialization of the implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // initialize() replaces constructor for upgradeable contracts
    function initialize(address asset_, address initialOwner) external initializer {
        __ERC4626_init(IERC20(asset_));
        __ERC20_init("Vault Share", "vSHARE");
        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    // REQUIRED: access control for upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

**UUPS security rules the coding agent must enforce:**
1. `_disableInitializers()` in every implementation constructor — mandatory, no exceptions
2. `_authorizeUpgrade` must have explicit access control — an empty override is the #1 UUPS exploit
3. `__gap` must be present in every upgradeable contract's storage
4. Gap size = 50 minus the number of state variable slots used in the current version

### Standard 7: Constructor vs. Initializer

```solidity
// Immutable contracts: use constructor
contract Token is ERC20, Ownable2Step {
    uint256 public constant MAX_SUPPLY = 1_000_000e18;

    constructor(address initialOwner)
        ERC20("My Token", "MTK")
        Ownable(initialOwner)
    {
        _mint(initialOwner, MAX_SUPPLY);
    }
}

// Upgradeable contracts: use initializer
contract TokenV1 is ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant MAX_SUPPLY = 1_000_000e18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address initialOwner) external initializer {
        __ERC20_init("My Token", "MTK");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _mint(initialOwner, MAX_SUPPLY);
    }
}
```

### Standard 8: Event Emission

Every state-changing function must emit an event. Events are the audit trail.

```solidity
// Define at contract level with indexed parameters for filterable fields
event FeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
event Paused(address indexed caller);

// Emit in EFFECTS phase (after state update, before interactions)
function setFee(uint256 newFee) external onlyOwner {
    if (newFee > MAX_FEE) revert FeeExceedsMax(newFee, MAX_FEE);
    uint256 oldFee = withdrawalFeeBps;
    withdrawalFeeBps = newFee;
    emit FeeUpdated(oldFee, newFee);  // emit in EFFECTS, not after INTERACTIONS
}
```

Indexed parameter rules:
- Index parameters that will be filtered on by off-chain systems (e.g., user address, token address)
- Do not index parameters that are only for logging (e.g., amounts, descriptions)
- Maximum 3 indexed parameters per event (EVM limit)

---

## Supporting File: foundry-test-patterns.md

This file lives at `skills/solidity-builder/foundry-test-patterns.md` and is loaded on demand.

### Required Content

**Pattern 1: Access Control Test Template**
```solidity
// Tests access control for any privileged function
// Always test WRONG caller first, then RIGHT caller

function test_<functionName>_revertsWhenCallerNotOwner() public {
    address attacker = makeAddr("attacker");
    vm.prank(attacker);
    vm.expectRevert(abi.encodeWithSelector(
        OwnableUnauthorizedAccount.selector,
        attacker
    ));
    contract.<functionName>(<args>);
}

function test_<functionName>_succeedsWhenCallerIsOwner() public {
    vm.prank(owner);
    // setup expected state
    contract.<functionName>(<args>);
    // assert state changed correctly
}
```

**Pattern 2: ERC-20 Balance Setup**
```solidity
// Use deal() for ERC-20 balance setup — manipulates storage directly
// Preferred over minting because it works for any ERC-20 including ones without mint()
deal(address(token), alice, 1000e18);

// For tokens that need both balance and approval:
deal(address(token), alice, 1000e18);
vm.prank(alice);
token.approve(address(contract), type(uint256).max);
```

**Pattern 3: Event Verification**
```solidity
// vm.expectEmit parameters: (checkTopic1, checkTopic2, checkTopic3, checkData)
// true means "verify this field", false means "don't care"
vm.expectEmit(true, false, false, true); // check topic1 (indexed) and data
emit ExpectedEvent(indexedParam, unindexedParam); // emit expected event
contract.functionThatShouldEmit(); // then call the function
```

**Pattern 4: Reentrancy Attack Test**
```solidity
// Tests that a function is protected against reentrancy
contract ReentrancyAttacker {
    IVault vault;
    uint256 attackCount;
    uint256 constant MAX_ATTACKS = 5;

    constructor(IVault _vault) { vault = _vault; }

    function attack(uint256 amount) external {
        vault.withdraw(amount, address(this), address(this));
    }

    receive() external payable {
        if (attackCount < MAX_ATTACKS) {
            attackCount++;
            vault.withdraw(1 ether, address(this), address(this)); // re-enters
        }
    }
}

function test_withdraw_revertsOnReentrancy() public {
    ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
    deal(address(token), address(attacker), 10 ether);
    vm.prank(address(attacker));
    token.approve(address(vault), 10 ether);
    vm.prank(address(attacker));
    vault.deposit(10 ether, address(attacker));

    vm.expectRevert(ReentrancyGuardReentrantCall.selector);
    vm.prank(address(attacker));
    attacker.attack(1 ether);
}
```

**Pattern 5: Time-Dependent Tests (Boundary Conditions)**
```solidity
// Always test three points for time-dependent logic:
// 1. Exactly at threshold (should trigger)
// 2. 1 second before threshold (should not trigger)
// 3. 1 second after threshold (should trigger, provides margin confidence)

function test_claim_revertsBeforeLockupExpires() public {
    uint256 lockupDuration = vault.lockupPeriod();

    vm.warp(block.timestamp + lockupDuration - 1); // 1 second before
    vm.expectRevert(Vault.LockupNotExpired.selector);
    vm.prank(alice);
    vault.claim();
}

function test_claim_succeedsExactlyAtLockupExpiry() public {
    uint256 lockupDuration = vault.lockupPeriod();

    vm.warp(block.timestamp + lockupDuration); // exactly at threshold
    vm.prank(alice);
    vault.claim(); // should succeed
}
```

**Pattern 6: Signature / Permit Tests**
```solidity
// Testing EIP-2612 permit signatures
function test_permit_allowsGaslessApproval() public {
    uint256 alicePrivKey = 0xa11ce; // private key for test only
    address aliceDerived = vm.addr(alicePrivKey);
    deal(address(token), aliceDerived, 1000e18);

    uint256 deadline = block.timestamp + 1 hours;
    bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
        alicePrivKey,
        keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                aliceDerived,
                address(vault),
                1000e18,
                token.nonces(aliceDerived),
                deadline
            ))
        ))
    );

    token.permit(aliceDerived, address(vault), 1000e18, deadline, v, r, s);
    assertEq(token.allowance(aliceDerived, address(vault)), 1000e18);
}
```

---

## Output Artifacts

- `src/<ContractName>.sol` — implementation file
- `test/unit/<ContractName>.t.sol` — unit test file
- `test/mocks/<MockContracts>.sol` — mock contracts for testing
- `.gas-snapshot` — gas baseline committed alongside code

---

## Terminal State

Exit options from `solidity-builder`:
1. All unit tests pass → invoke `solidity-tester` (for fuzz/invariant tests)
2. All unit tests pass AND fuzz tests exist → invoke `solidity-natspec` (for documentation)
3. Implementation complete AND reviewed → invoke `solidity-gas-optimizer` (before deploy)

The builder skill is NOT complete when tests pass. It is complete when the implementation
is ready for the next gate.

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "I'll write tests after the logic is working" | Tests written after code verify what the code does — not what it should do. They pass immediately on behavior the code already has, proving nothing. |
| "The function is too simple to test" | Simple functions have boundary bugs at `uint256` limits, `address(0)`, and zero values. Write the test. It takes 2 minutes. |
| "Fuzz tests are slow" | Write them. Run them in CI with 256 runs. They are still required. Slowness is not an override. |
| "I'll test reverts later" | Revert paths are security-critical. They go first, not last. Testing them first forces correct CEI order. |
| "The interface already defines the behavior" | Interfaces define signatures, not edge cases. Tests define behavior. |
| "This is a quick prototype, no tests needed" | Prototypes become production code when timelines slip. Start with tests now. |
| "I've written this pattern before, I know it's right" | Familiarity is when you make mistakes. The test is cheap. The bug is not. |
