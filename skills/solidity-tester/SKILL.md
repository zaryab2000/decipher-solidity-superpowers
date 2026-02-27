---
name: solidity-tester
description: >
  Fuzz and invariant testing gate for Solidity contracts that handle value. Use for any contract
  involving deposits, withdrawals, minting, burning, swapping, lending, staking, or share
  accounting. Triggers on: "add fuzz tests", "write invariant tests", "property-based tests",
  "fork tests", "test this more thoroughly", "invariant suite", or when a contract handles ETH
  or ERC-20 tokens. Enforces: handler pattern, ghost variables, bound() usage, configured
  invariant runs, and fork tests pinned to block numbers. Covers ERC-4626 vaults, AMMs, lending
  markets, staking contracts, and any system where accounting conservation must hold.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge)
metadata:
  author: Zaryab
  version: "1.0"
---

## When

During or after the build phase, when the contract handles value (ETH, tokens, shares, debt
positions) and needs testing beyond unit tests. Also when adding property-based tests or fork
tests to existing contracts.

## The strict rule

```
EVERY CONTRACT THAT HANDLES VALUE MUST HAVE FUZZ TESTS AND INVARIANT TESTS BEFORE DEPLOYMENT
```

Value-handling = any contract with functions that: deposit, withdraw, mint, burn, swap, lend,
borrow, stake, unstake, liquidate, or transfer tokens.

## Hard Gate

No value-handling contract exits this phase without:
1. At least one fuzz test per public/external function that handles amounts
2. At least 3 invariant tests (covering accounting, conservation, access control)
3. Fork tests for any external protocol integrations

## Mandatory Checklist

### Test File Structure

Create tests in this exact directory layout:

```
test/
├── unit/
│   └── ContractName.t.sol          ← from solidity-builder phase
├── fuzz/
│   └── ContractName.fuzz.t.sol     ← fuzz tests (this skill)
├── invariant/
│   ├── ContractName.inv.t.sol      ← invariant test contract (this skill)
│   └── handlers/
│       └── ContractNameHandler.sol ← handler contract (this skill, mandatory)
└── fork/
    └── ContractName.fork.t.sol     ← fork tests (if external deps exist, this skill)
```

### Fuzz Tests

Fuzz tests verify that a property holds across the full randomized input space. Foundry generates
random inputs automatically when a test function has parameters.

**Rule 1: Always use `bound()` to constrain inputs**

Unbounded fuzz inputs produce many wasted runs that always revert on invalid values.

```solidity
// BAD: most runs will trigger overflow or zero-amount revert
function testFuzz_deposit_updatesBalance(uint256 amount) public {
    vault.deposit(amount, alice); // reverts on amount=0, overflows on huge values
}

// GOOD: bounded to meaningful range
function testFuzz_deposit_updatesBalance(uint256 amount) public {
    amount = bound(amount, 1, type(uint128).max);

    deal(address(token), alice, amount);
    vm.startPrank(alice);
    token.approve(address(vault), amount);
    uint256 shares = vault.deposit(amount, alice);
    vm.stopPrank();

    assertGt(shares, 0, "Shares must be positive after deposit");
    assertEq(vault.totalAssets(), amount, "Total assets must equal deposit");
}
```

**Rule 2: Test properties, not specific values**

```solidity
// GOOD: tests a property (share math is monotonic)
function testFuzz_deposit_moreAssetsProduceMoreShares(uint256 a, uint256 b) public {
    a = bound(a, 1, type(uint64).max);
    b = bound(b, a + 1, type(uint64).max); // b > a always

    uint256 sharesForA = vault.previewDeposit(a);
    uint256 sharesForB = vault.previewDeposit(b);

    assertGe(sharesForB, sharesForA, "More assets must produce >= shares");
}

// GOOD: conservation property
function testFuzz_withdrawAll_leavesNoAssets(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1e6, type(uint128).max);

    deal(address(token), alice, depositAmount);
    vm.startPrank(alice);
    token.approve(address(vault), depositAmount);
    vault.deposit(depositAmount, alice);

    uint256 maxWithdrawable = vault.maxWithdraw(alice);
    vault.withdraw(maxWithdrawable, alice, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), 0, "Shares must be 0 after full withdrawal");
}

// BAD: hardcoded expected value — this is a unit test with random input, not a fuzz test
function testFuzz_deposit_returnsExactShares(uint256 amount) public {
    assertEq(vault.previewDeposit(amount), amount); // Wrong — ratio changes over time
}
```

**Rule 3: Configure fuzz runs in foundry.toml**

```toml
[fuzz]
runs = 1000              # development minimum; increase to 10000 before audit
max_test_rejects = 65536
seed = '0x1'             # deterministic seed for CI reproducibility
dictionary_weight = 40
include_storage = true   # use contract storage values as fuzz inputs
include_push_bytes = true
```

**Rule 4: Multiple address fuzz to catch per-user accounting bugs**

```solidity
function testFuzz_deposit_twoUsersAreIsolated(
    uint256 aliceAmount,
    uint256 bobAmount
) public {
    aliceAmount = bound(aliceAmount, 1, type(uint64).max);
    bobAmount = bound(bobAmount, 1, type(uint64).max);

    deal(address(token), alice, aliceAmount);
    deal(address(token), bob, bobAmount);

    vm.prank(alice);
    token.approve(address(vault), aliceAmount);
    vm.prank(alice);
    uint256 aliceShares = vault.deposit(aliceAmount, alice);

    vm.prank(bob);
    token.approve(address(vault), bobAmount);
    vm.prank(bob);
    vault.deposit(bobAmount, bob);

    assertEq(vault.balanceOf(alice), aliceShares, "Alice shares must not change after Bob deposits");
}
```

### Invariant Tests

Invariant tests verify that a property holds after ANY arbitrary sequence of valid function calls.
Foundry generates random call sequences and checks invariants after each call.

**The Handler Pattern (Mandatory)**

A Handler contract is the interface between the fuzzer and the system under test. It:
1. Restricts the fuzzer to valid inputs (preventing wasted runs on always-reverting calls)
2. Tracks "ghost variables" — expected state computed alongside the actual contract
3. Manages a pool of actors to simulate real-world multi-user interactions

```solidity
// test/invariant/handlers/VaultHandler.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultHandler is Test {
    // ── System under test ────────────────────────────────────────────────────
    Vault public vault;
    IERC20 public token;

    // ── Ghost variables ───────────────────────────────────────────────────────
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    mapping(address => uint256) public ghost_depositorBalance;
    uint256 public ghost_depositCallCount;
    uint256 public ghost_withdrawCallCount;
    uint256 public ghost_zeroDepositCount;

    // ── Actor management ──────────────────────────────────────────────────────
    address[] public actors;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(Vault _vault, IERC20 _token) {
        vault = _vault;
        token = _token;

        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
        actors.push(makeAddr("actor4"));
        actors.push(makeAddr("actor5"));
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }

    function deposit(uint256 amount, uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        amount = bound(amount, 1, 1_000_000e18);

        deal(address(token), currentActor, amount);
        token.approve(address(vault), amount);

        uint256 sharesBefore = vault.balanceOf(currentActor);
        vault.deposit(amount, currentActor);
        uint256 sharesAfter = vault.balanceOf(currentActor);

        ghost_totalDeposited += amount;
        ghost_depositorBalance[currentActor] += (sharesAfter - sharesBefore);
        ghost_depositCallCount++;
    }

    function withdraw(uint256 amount, uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        uint256 maxWithdraw = vault.maxWithdraw(currentActor);
        if (maxWithdraw == 0) {
            ghost_zeroDepositCount++;
            return;
        }

        amount = bound(amount, 1, maxWithdraw);

        uint256 sharesBefore = vault.balanceOf(currentActor);
        vault.withdraw(amount, currentActor, currentActor);
        uint256 sharesAfter = vault.balanceOf(currentActor);

        ghost_totalWithdrawn += amount;
        ghost_depositorBalance[currentActor] -= (sharesBefore - sharesAfter);
        ghost_withdrawCallCount++;
    }

    function approve(uint256 amount, uint256 actorIndexSeed, uint256 spenderIndexSeed)
        external
        useActor(actorIndexSeed)
    {
        address spender = actors[bound(spenderIndexSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, type(uint256).max);
        vault.approve(spender, amount);
    }

    function callSummary() external view {
        console2.log("Deposit calls:   ", ghost_depositCallCount);
        console2.log("Withdraw calls:  ", ghost_withdrawCallCount);
        console2.log("Skipped (empty): ", ghost_zeroDepositCount);
        console2.log("Total deposited: ", ghost_totalDeposited);
        console2.log("Total withdrawn: ", ghost_totalWithdrawn);
    }
}
```

**Invariant Test Contract Template:**

```solidity
// test/invariant/Vault.inv.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {VaultHandler} from "./handlers/VaultHandler.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultInvariantTest is Test {
    Vault vault;
    MockERC20 token;
    VaultHandler handler;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        vault = new Vault(address(token));
        handler = new VaultHandler(vault, token);

        // CRITICAL: target ONLY the handler, not the vault directly
        // Direct vault calls bypass the handler's ghost variable tracking
        targetContract(address(handler));

        excludeSender(address(vault));
        excludeSender(address(token));
    }

    /// @notice Vault's token balance must always be >= totalAssets
    function invariant_solvency() public view {
        assertGe(
            token.balanceOf(address(vault)),
            vault.totalAssets(),
            "INVARIANT VIOLATED: vault token balance < totalAssets (insolvent)"
        );
    }

    /// @notice totalSupply must equal total deposited minus total withdrawn
    function invariant_shareAccountingMatchesGhost() public view {
        assertEq(
            vault.totalSupply(),
            handler.ghost_totalDeposited() - handler.ghost_totalWithdrawn(),
            "INVARIANT VIOLATED: totalSupply != deposited - withdrawn"
        );
    }

    /// @notice Sum of all user shares must equal totalSupply
    function invariant_noUserSharesExceedTotalSupply() public view {
        address[] memory actorList = handler.getActors();
        uint256 sumOfShares;
        for (uint256 i; i < actorList.length; ++i) {
            sumOfShares += vault.balanceOf(actorList[i]);
        }
        assertEq(
            sumOfShares,
            vault.totalSupply(),
            "INVARIANT VIOLATED: sum of user shares != totalSupply"
        );
    }

    /// @notice totalAssets must never underflow
    function invariant_totalAssetsNonNegative() public view {
        assertGe(
            vault.totalAssets(),
            0,
            "INVARIANT VIOLATED: totalAssets underflow"
        );
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
```

**Configure invariant runs in foundry.toml:**

```toml
[invariant]
runs = 256               # number of call sequences (increase to 1000+ before audit)
depth = 100              # function calls per sequence
fail_on_revert = false   # reverts in handler are expected (handler manages skips)
shrink_run_limit = 5000  # how many times to shrink a failing sequence
show_metrics = true      # shows call distribution
```

### Invariant Categories — Required for Every Value-Handling Contract

**Accounting Invariants (Most Critical)**
```
// ERC-20 token
totalSupply() == sum(balances[address] for all addresses)

// ERC-4626 vault
totalAssets() == sum of all deposited assets minus withdrawn assets
token.balanceOf(vault) >= totalAssets()    ← solvency invariant
totalSupply() > 0 iff totalAssets() > 0   ← no shares without assets
```

**Conservation Invariants**
```
// Assets flowing in and out must balance
totalDeposited == totalWithdrawn + totalAssets()

// For lending
totalBorrowed + totalLiquidity == totalDeposited (excluding accrued interest)
```

**Monotonicity Invariants**
```
nonce(user) is strictly increasing (never decreases)
totalDeposited is non-decreasing (assuming no burns)
```

**Access Control Invariants**
```
paused == true → deposit() reverts
paused == true → withdraw() reverts
owner() == initialOwner after setup (no unauthorized ownership transfer)
```

**Safety Invariants**
```
withdrawalFeeBps <= MAX_FEE always
shares > 0 iff msg.value > 0 was deposited (no free shares)
previewWithdraw(previewDeposit(x)) <= x  ← round-trip cannot profit on user
```

### Fork Tests

Fork tests are mandatory for any contract that calls external protocols.

```solidity
// test/fork/VaultFork.fork.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    Vault vault;

    function setUp() public {
        // CRITICAL: pin to specific block number for determinism and RPC caching
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19_500_000);
        vault = new Vault(USDC);
    }

    function test_fork_deposit_worksWithRealUSDC() public {
        address whale = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
        uint256 depositAmount = 10_000e6;

        vm.prank(whale);
        IERC20(USDC).approve(address(vault), depositAmount);
        vm.prank(whale);
        uint256 shares = vault.deposit(depositAmount, whale);

        assertGt(shares, 0, "Fork: deposit should return shares with real USDC");
    }
}
```

**Fork test rules:**
1. Always pin to a specific block number. Floating fork means tests change as the chain advances.
2. Configure RPC endpoints in `foundry.toml`, not test files:
   ```toml
   [rpc_endpoints]
   mainnet  = "${ETH_RPC_URL}"
   sepolia  = "${SEPOLIA_RPC_URL}"
   arbitrum = "${ARBITRUM_RPC_URL}"
   ```
3. Do not fuzz over forked state. Fuzz inputs inside fork tests trigger repeated RPC calls.
4. Test with real whale balances. Etherscan → search the token → top holders → use one.

For extended handler patterns, ghost variable reference, and debugging failed sequences, read
`invariant-testing-guide.md`.

## Forge Commands

```bash
# Run fuzz tests only
forge test --match-path "test/fuzz/*" -vv

# Run invariant tests only
forge test --match-path "test/invariant/*" -vv

# Run fork tests (requires RPC URL env var)
forge test --match-path "test/fork/*" -vv --fork-url $ETH_RPC_URL

# Run with higher fuzz runs for pre-audit
forge test --fuzz-runs 10000

# Show call metrics (invariant tests)
forge test --match-path "test/invariant/*" -vv
```

## Output Artifacts

- `test/fuzz/<ContractName>.fuzz.t.sol`
- `test/invariant/<ContractName>.inv.t.sol`
- `test/invariant/handlers/<ContractName>Handler.sol`
- `test/fork/<ContractName>.fork.t.sol` (if external protocol dependencies exist)

## Terminal State

After all tests pass and coverage is acceptable:
- Exit to `solidity-gas-optimizer` (for gas review before deploy)
- Exit to `solidity-natspec` (for documentation completion)
- Exit to `solidity-code-reviewer` (for security review)

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "Invariant tests are too complex" | Use the handler template. It is copy-paste. The complexity is in the bugs they find, not in writing them. |
| "I'll add fork tests later" | Integration assumptions are wrong until proven on real mainnet state. "Later" is after the exploit. |
| "Unit tests are enough" | Unit tests verify isolation. Invariants verify system behavior under arbitrary interaction sequences. They find different bugs. |
| "Fuzz runs are too slow for CI" | Configure 256 runs in CI, 10000+ locally before audit. The CI run is fast. |
| "The handler is too much setup" | The handler is ~50 lines. The alternative is a manual audit of every possible call sequence. |
| "I know the invariants hold" | Write them down. If you know they hold, writing them takes 10 minutes and gives you regression tests forever. |
