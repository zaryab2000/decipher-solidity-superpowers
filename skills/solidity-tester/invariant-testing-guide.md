# Invariant Testing Guide

This file is loaded by `solidity-tester` on demand. Reference specific sections when building
invariant test suites for the contract type you are testing.

---

## Section 1: Full Handler Pattern with Actor Management

Extended handler with time manipulation, donation attack testing, and the `getActors()` helper.

```solidity
// test/invariant/handlers/VaultHandler.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultHandler is Test {
    Vault public vault;
    IERC20 public token;

    // Ghost variables
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalFeesPaid;
    uint256 public ghost_depositCallCount;
    uint256 public ghost_withdrawCallCount;
    uint256 public ghost_warpCallCount;
    uint256 public ghost_donateCallCount;
    uint256 public ghost_zeroSkipCount;

    address[] private _actors;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors[bound(actorIndexSeed, 0, _actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(Vault _vault, IERC20 _token) {
        vault = _vault;
        token = _token;

        _actors.push(makeAddr("actor1"));
        _actors.push(makeAddr("actor2"));
        _actors.push(makeAddr("actor3"));
        _actors.push(makeAddr("actor4"));
        _actors.push(makeAddr("actor5"));
    }

    // Required: getActors() allows invariant contract to iterate over all actors
    function getActors() external view returns (address[] memory) {
        return _actors;
    }

    function deposit(uint256 amount, uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        amount = bound(amount, 1, 1_000_000e18);

        deal(address(token), currentActor, amount);
        token.approve(address(vault), amount);

        vault.deposit(amount, currentActor);

        ghost_totalDeposited += amount;
        ghost_depositCallCount++;
    }

    function withdraw(uint256 amount, uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        uint256 maxWithdraw = vault.maxWithdraw(currentActor);
        if (maxWithdraw == 0) {
            ghost_zeroSkipCount++;
            return;
        }

        amount = bound(amount, 1, maxWithdraw);
        vault.withdraw(amount, currentActor, currentActor);

        ghost_totalWithdrawn += amount;
        ghost_withdrawCallCount++;
    }

    // Time warp handler — tests time-dependent invariants (lockups, reward accrual)
    function warp(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1, 365 days);
        vm.warp(block.timestamp + seconds_);
        ghost_warpCallCount++;
    }

    // Donation handler — tests that direct token transfers don't corrupt accounting
    // A donation is a transfer directly to the vault without going through deposit()
    // This tests the inflation attack vector and accounting integrity
    function donate(uint256 amount) external {
        amount = bound(amount, 1, 100_000e18);
        deal(address(token), address(this), amount);
        token.transfer(address(vault), amount);
        // Note: ghost_totalDeposited is NOT updated — donation is not a real deposit
        ghost_donateCallCount++;
    }

    function callSummary() external view {
        console2.log("=== Handler Call Summary ===");
        console2.log("Deposit calls:   ", ghost_depositCallCount);
        console2.log("Withdraw calls:  ", ghost_withdrawCallCount);
        console2.log("Warp calls:      ", ghost_warpCallCount);
        console2.log("Donate calls:    ", ghost_donateCallCount);
        console2.log("Skipped (empty): ", ghost_zeroSkipCount);
        console2.log("Total deposited: ", ghost_totalDeposited);
        console2.log("Total withdrawn: ", ghost_totalWithdrawn);
    }
}
```

---

## Section 2: Ghost Variable Patterns by Contract Type

Ghost variables mirror expected state tracked independently of the contract. They are the ground
truth against which actual contract state is compared in invariant assertions.

### ERC-4626 Vault

```
ghost_totalDeposited    ← sum of all deposit() assets (not donations)
ghost_totalWithdrawn    ← sum of all withdraw() and redeem() assets
ghost_totalFeesPaid     ← sum of fees collected (if fee mechanism exists)
ghost_depositCallCount  ← number of successful deposit calls
ghost_withdrawCallCount ← number of successful withdraw calls
```

Key invariant using these ghosts:
```solidity
assertEq(
    vault.totalAssets(),
    handler.ghost_totalDeposited() - handler.ghost_totalWithdrawn(),
    "totalAssets must equal deposited minus withdrawn"
);
```

### ERC-20 Token

```
ghost_totalMinted       ← sum of all mint() amounts
ghost_totalBurned       ← sum of all burn() amounts
ghost_transferCount     ← number of successful transfer calls
ghost_mintCallCount     ← number of mint calls (for access control invariants)
```

Key invariant:
```solidity
assertEq(
    token.totalSupply(),
    handler.ghost_totalMinted() - handler.ghost_totalBurned(),
    "totalSupply must equal minted minus burned"
);
```

### Lending Market

```
ghost_totalBorrowed     ← sum of all borrow() amounts
ghost_totalRepaid       ← sum of all repay() amounts
ghost_totalLiquidated   ← sum of all liquidation() collateral seized
ghost_totalDeposited    ← sum of all supply() amounts (liquidity providers)
ghost_totalWithdrawn    ← sum of all withdraw() amounts (liquidity providers)
```

Key invariants:
```solidity
// Utilization must be <= 100%
assertLe(
    market.totalBorrowed(),
    market.totalDeposited(),
    "Cannot borrow more than deposited"
);

// Conservation
assertEq(
    market.totalDeposited() - market.totalWithdrawn(),
    market.totalBorrowed() - market.totalRepaid() + market.totalLiquidity(),
    "Assets must be conserved"
);
```

### AMM (Constant Product)

```
ghost_reserve0Before    ← reserve0 before each swap
ghost_reserve1Before    ← reserve1 before each swap
ghost_swapCount         ← number of swaps executed
ghost_liquidityAdded    ← sum of all addLiquidity amounts
ghost_liquidityRemoved  ← sum of all removeLiquidity amounts
```

Key invariant:
```solidity
// Constant product must never decrease after a swap (only increases from fees)
assertGe(
    amm.reserve0() * amm.reserve1(),
    handler.ghost_reserve0Before() * handler.ghost_reserve1Before(),
    "k must not decrease after swap"
);
```

---

## Section 3: Common Invariant Formulas by Contract Type

### ERC-20 Token

```
totalSupply == ghost_totalMinted - ghost_totalBurned
sum(balances[address] for all addresses) == totalSupply
allowance[owner][spender] >= 0 always (trivially true, but tracks underflow)
```

### ERC-4626 Vault

```
totalAssets == ghost_totalDeposited - ghost_totalWithdrawn
token.balanceOf(vault) >= totalAssets                  ← solvency
totalSupply > 0 iff totalAssets > 0                    ← no free shares
previewWithdraw(previewDeposit(x)) <= x                ← round-trip cannot profit user
sum(balanceOf(actor) for all actors) == totalSupply    ← share accounting
```

### AMM (Constant Product x*y=k)

```
k = reserve0 * reserve1
k_after_swap >= k_before_swap (k increases from fees, never decreases)
reserve0 > 0 and reserve1 > 0 always (pool never fully drained)
totalSupply of LP tokens > 0 iff liquidity provided
```

### Lending Market

```
utilization = totalBorrowed / (totalBorrowed + totalLiquidity)
utilization <= 1 (cannot borrow more than supplied)
sum(collateral[user] for all users) == totalCollateral
totalDebt >= totalBorrowed (interest accrual can only increase debt)
```

### Staking Contract

```
totalStaked == sum(staked[user] for all users)
rewardDebt[user] <= accRewardPerShare * staked[user]  ← no over-claiming
pendingReward(user) >= 0 always (no negative rewards)
```

---

## Section 4: Debugging Failed Invariant Sequences

When an invariant fails, Foundry prints the call sequence that caused it:

```
[FAIL. Reason: INVARIANT VIOLATED: totalSupply != deposited - withdrawn]
Sequence:
  [0] VaultHandler.deposit(1000000000000000001, 2)
  [1] VaultHandler.donate(500000000000000000)
  [2] VaultHandler.withdraw(999999999999999999, 2)
  [3] VaultHandler.withdraw(1, 2)
```

### How to read the sequence

- Each line is a handler function call with its arguments
- The sequence is the minimal reproduction case after shrinking
- The last call before the invariant check is usually where the bug manifests
- Work backwards: what state was the contract in before the failing call?

### How to reproduce deterministically

Copy the sequence into a unit test with explicit state setup:

```solidity
function test_reproduce_invariantFailure() public {
    // Step 0: deposit
    deal(address(token), actors[2], 1000000000000000001);
    vm.prank(actors[2]);
    token.approve(address(vault), type(uint256).max);
    vm.prank(actors[2]);
    vault.deposit(1000000000000000001, actors[2]);

    // Step 1: donate directly (bypasses ghost tracking)
    deal(address(token), address(this), 500000000000000000);
    token.transfer(address(vault), 500000000000000000);

    // Step 2: first withdraw
    vm.prank(actors[2]);
    vault.withdraw(999999999999999999, actors[2], actors[2]);

    // Step 3: second withdraw (this should revert but doesn't?)
    vm.prank(actors[2]);
    vault.withdraw(1, actors[2], actors[2]);

    // Now manually check the invariant
    assertEq(vault.totalSupply(), ghost_totalDeposited - ghost_totalWithdrawn);
}
```

### Common root causes

| Symptom | Root Cause | Fix |
|---|---|---|
| Ghost value diverges immediately | Handler function missing ghost update | Add ghost increment/decrement to the handler function |
| Ghost value diverges on skip | Handler skips but updates ghost | Move ghost update after the early-return guard |
| Off-by-one in conservation check | Rounding in share math not accounted for | Use `assertApproxEqAbs` with tolerance for share math |
| Invariant passes when it shouldn't | Handler not calling the vulnerable function | Add the missing function to the handler |
| Sequence always reverts | Handler bounds too tight | Widen bounds or add guard to skip instead of revert |

---

## Section 5: Call Summary Analysis

The `invariant_callSummary` function logs call distribution after every sequence. Use it to verify
the handler is exercising all paths.

Enable in foundry.toml:
```toml
[invariant]
show_metrics = true
```

### Interpreting the output

```
=== Handler Call Summary ===
Deposit calls:    847
Withdraw calls:    89
Warp calls:        48
Donate calls:      16
Skipped (empty):  312
```

**Red flags in the distribution:**

- `deposit` is >90% of calls: the invariant run is mostly deposits with no withdrawals.
  The `withdraw` path is under-tested. Fix: add a `targetSelector` weight hint or ensure
  the handler doesn't skip withdraw calls too aggressively.

- `Skipped (empty)` is >50% of all calls: most withdraw attempts are skipped because actors
  have no balance. This means deposits and withdrawals are not alternating. Fix: add a
  two-function sequence handler that deposits then immediately withdraws.

- A function has 0 calls: the fuzzer never called it. Check that the function is public in
  the handler and that `targetContract` is set to the handler.

### Adding weight hints

Foundry does not support explicit call weights natively, but you can influence distribution by
splitting a handler into more functions that call the same underlying operation:

```solidity
// Effectively gives deposit 2x weight vs withdraw
function depositSmall(uint256 amount, uint256 actorSeed) external { ... }
function depositLarge(uint256 amount, uint256 actorSeed) external { ... }
function withdraw(uint256 amount, uint256 actorSeed) external { ... }
```

Or use the `targetSelector` cheatcode in the invariant test's `setUp`:

```solidity
bytes4[] memory selectors = new bytes4[](3);
selectors[0] = VaultHandler.deposit.selector;
selectors[1] = VaultHandler.deposit.selector; // duplicated = 2x weight
selectors[2] = VaultHandler.withdraw.selector;
targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
```
