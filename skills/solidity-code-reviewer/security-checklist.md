# Security Checklist

Full reference for the `solidity-code-reviewer` skill. Each domain includes: vulnerability
description, proof of concept, detection guidance, mitigation with code, and the test pattern.

---

## Domain 1: Reentrancy

### 1a. Single-Function Reentrancy

**Vulnerability:** A function makes an external call before updating state. An attacker's contract
re-enters the same function in the external call's receive/fallback, reading stale state.

**Proof of concept:**
```solidity
// Vulnerable contract
contract Vault {
    mapping(address => uint256) public balances;

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient");
        // EXTERNAL CALL BEFORE STATE UPDATE — vulnerable
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");
        balances[msg.sender] -= amount; // state update too late
    }
}

// Attacker contract
contract Attacker {
    Vault vault;
    uint256 public stolen;

    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdraw(1 ether); // re-enters before balance was updated
        }
        stolen += msg.value;
    }
}
```

**Detection:** In every `external`, `public` function: find external calls (`.call`, `.transfer`,
`.send`, interface calls, SafeERC20 calls). For each: verify state updates happen BEFORE the
external call. Any external call before a state update is a reentrancy candidate.

**Mitigation:**
```solidity
function withdraw(uint256 amount) external nonReentrant {
    // CHECKS
    if (balances[msg.sender] < amount) revert InsufficientBalance(balances[msg.sender], amount);
    // EFFECTS — state updates first
    balances[msg.sender] -= amount;
    // INTERACTIONS — external call last
    (bool ok,) = msg.sender.call{value: amount}("");
    if (!ok) revert TransferFailed(msg.sender, amount);
}
```

**Test:**
```solidity
function test_withdraw_nonReentrant() public {
    ReentrantAttacker attacker = new ReentrantAttacker(address(vault));
    vm.deal(address(attacker), 1 ether);
    attacker.attack{value: 1 ether}();
    // Attacker should only have withdrawn their own deposit, not more
    assertEq(address(attacker).balance, 1 ether);
    assertEq(vault.totalAssets(), 0);
}
```

---

### 1b. Cross-Function Reentrancy

**Vulnerability:** Function A makes an external call. Attacker re-enters function B (not A) which
reads state that A has not yet updated.

**Proof of concept:**
```solidity
// A updates balances after the call; B reads balances
function withdraw() external {
    uint256 bal = balances[msg.sender];
    (bool ok,) = msg.sender.call{value: bal}(""); // re-enters via receive()
    balances[msg.sender] = 0; // too late
}

function flashLoan(uint256 amount) external {
    require(balances[msg.sender] >= amount); // reads stale balance during re-entry
    // attacker now has double credit
}
```

**Detection:** List all functions that read shared state. For each external call site: identify
which other functions read the state variables that haven't been updated yet.

**Mitigation:** Shared `nonReentrant` lock across all interacting functions, OR update all shared
state before any external call.

---

### 1c. Read-Only Reentrancy

**Vulnerability:** A view function (no reentrancy guard) is called by an external protocol
during a reentrancy window. The view returns stale data, which the external protocol uses for
pricing.

**Detection:** Identify `view` functions that return values used by other protocols (price, balance,
share ratio). If any of these are called during an active transaction, they may return mid-update state.

**Mitigation (advanced):** Use transient storage (`TSTORE`/`TLOAD`, Solidity 0.8.24+) as a
reentrancy flag that also gates view functions, OR document the risk and require integrators
to use TWAP or delayed reads.

---

## Domain 2: Access Control

### 2a. Missing Access Modifier

**Vulnerability:** A function intended to be privileged is deployed without an access modifier.

**Proof of concept:**
```solidity
// Missing onlyOwner — anyone can call
function setFee(uint256 newFee) external {
    fee = newFee; // any address can change the protocol fee
}
```

**Detection:** List all state-mutating functions. For each: verify there is an explicit access
modifier (`onlyOwner`, `onlyRole`, `whenNotPaused`) or an explicit early-revert access check.
Functions with no access control must be intentionally permissionless (deposit, transfer, etc.).

**Mitigation:**
```solidity
function setFee(uint256 newFee) external onlyOwner {
    if (newFee > MAX_FEE) revert ExceedsMaxFee(newFee, MAX_FEE);
    emit FeeUpdated(fee, newFee);
    fee = newFee;
}
```

---

### 2b. Single-Step Ownership Transfer (Ownable vs Ownable2Step)

**Vulnerability:** `transferOwnership(newOwner)` in OpenZeppelin's `Ownable` takes effect
immediately. A typo in `newOwner` permanently loses ownership.

**Detection:** Search for `Ownable` inheritance. If not `Ownable2Step`, flag it.

**Mitigation:**
```solidity
// BAD
import "@openzeppelin/contracts/access/Ownable.sol";
contract Vault is Ownable { ... }

// GOOD
import "@openzeppelin/contracts/access/Ownable2Step.sol";
contract Vault is Ownable2Step { ... }
// New owner must call acceptOwnership() — prevents one-step accidents
```

**Test:**
```solidity
function test_transferOwnership_requiresAcceptance() public {
    vm.prank(owner);
    vault.transferOwnership(newOwner);
    // Ownership not yet transferred
    assertEq(vault.owner(), owner);
    vm.prank(newOwner);
    vault.acceptOwnership();
    assertEq(vault.owner(), newOwner);
}
```

---

### 2c. tx.origin Authorization

**Vulnerability:** `tx.origin` is the original EOA that initiated the transaction chain. If a
contract calls your contract, `tx.origin` is still the EOA — not the intermediate contract.
Phishing contracts can exploit this.

**Detection:** Search for `tx.origin` in access control checks: `require(tx.origin == owner)`.

**Mitigation:** Never use `tx.origin` for authorization. Use `msg.sender` exclusively.

---

## Domain 3: Integer Arithmetic

### 3a. Precision Loss — Division Before Multiplication

**Vulnerability:** Integer division truncates. When you divide before multiplying, you lose
precision that cannot be recovered.

**Proof of concept:**
```solidity
// principal = 1_000_000 (1 USDC in 6 decimals)
// totalShares = 1e18
// newRate = 1.05e18 (5% APY expressed as 1e18-based rate)
uint256 result = (principal / totalShares) * newRate;
// (1_000_000 / 1e18) = 0 (integer division truncates to 0)
// 0 * 1.05e18 = 0 — user receives NOTHING instead of their proportional share
```

**Mitigation:**
```solidity
// Always multiply first, then divide
uint256 result = (principal * newRate) / totalShares;
// (1_000_000 * 1.05e18) / 1e18 = 1_050_000 — correct
```

---

### 3b. Unsafe Downcast

**Vulnerability:** Casting a larger type to a smaller type silently truncates if the value
exceeds the target range.

**Proof of concept:**
```solidity
uint256 large = type(uint128).max + 1; // 2^128
uint128 truncated = uint128(large);     // truncated = 0 (silent data loss)
```

**Mitigation:**
```solidity
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Reverts if value > type(uint128).max
uint128 safe = SafeCast.toUint128(large);
```

---

### 3c. ERC-4626 Rounding Direction

**Vulnerability:** EIP-4626 specifies rounding direction. Wrong rounding allows incremental
theft through many small transactions.

**Rule table:**
| Function | Rounds | Direction | Reason |
|----------|--------|-----------|--------|
| `convertToShares` | Down | Fewer shares for depositor | Protects vault |
| `previewDeposit` | Down | Fewer shares for depositor | Protects vault |
| `convertToAssets` | Down | Fewer assets for withdrawer | Protects vault |
| `previewMint` | Up | More assets required | Protects vault |
| `previewWithdraw` | Up | More assets required | Protects vault |
| `previewRedeem` | Down | Fewer assets for redeemer | Protects vault |

**Detection:** Check every division in share/asset conversion math. Verify the rounding
direction matches the table above. Any deviation is a finding.

---

### 3d. First-Depositor Share Inflation

**Vulnerability:** Attacker deposits 1 wei, then donates a large amount directly to the vault
(not via deposit), inflating the share price. Next depositor receives 0 shares for amounts
below the inflated price.

**Proof of concept:**
```solidity
vault.deposit(1); // mint 1 share for 1 wei
token.transfer(address(vault), 1_000_000 ether); // donate 1M tokens directly
// Share price is now 1M tokens per share
victim.deposit(999_999 ether); // victim gets 0 shares (rounds to 0)
```

**Mitigation:**
```solidity
// Virtual shares: add offset to totalSupply and totalAssets to dilute inflation
function _convertToShares(uint256 assets, Math.Rounding rounding)
    internal view override returns (uint256)
{
    return assets.mulDiv(
        totalSupply() + 10 ** decimalsOffset(),
        totalAssets() + 1,
        rounding
    );
}
```

---

## Domain 4: External Calls

### 4a. Unchecked Low-Level Call Return Value

**Vulnerability:** `.call()` returns `(bool success, bytes memory data)`. Ignoring `success`
means the call failed silently.

**Detection:** Search for `.call{` without a subsequent check on the bool return.

**Mitigation:**
```solidity
(bool ok, bytes memory data) = target.call{value: amount}(payload);
if (!ok) revert ExternalCallFailed(target, data);
```

---

### 4b. Raw ERC-20 Transfer Without SafeERC20

**Vulnerability:** Some ERC-20 tokens (USDT, BNB, others) do not return a bool from `transfer`
and `transferFrom`. The Solidity ABI decoder rejects the call or silently succeeds.

**Detection:** Search for `token.transfer(`, `token.transferFrom(` without `SafeERC20`.

**Mitigation:**
```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;
// ...
token.safeTransfer(to, amount);
token.safeTransferFrom(from, to, amount);
```

---

### 4c. Fee-on-Transfer Token Accounting

**Vulnerability:** Some ERC-20 tokens deduct a fee on transfer. The `amount` received is less
than the `amount` sent. If the contract tracks balances by `amount` parameter rather than delta,
its accounting is inflated.

**Mitigation:**
```solidity
uint256 before = token.balanceOf(address(this));
token.safeTransferFrom(msg.sender, address(this), amount);
uint256 actual = token.balanceOf(address(this)) - before;
// Use `actual`, not `amount`
```

---

## Domain 5: Oracle Security

### 5a. Chainlink Staleness Check

**Vulnerability:** Chainlink oracles can go offline. Without a staleness check, the contract
continues using the last price indefinitely, enabling incorrect liquidations or mispriced swaps.

**Mitigation:**
```solidity
uint256 private constant STALENESS_THRESHOLD = 1 hours;

function _getPrice() internal view returns (uint256) {
    (, int256 price, , uint256 updatedAt,) = priceFeed.latestRoundData();
    if (price <= 0) revert InvalidPrice(price);
    if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert StalePrice(updatedAt);
    return uint256(price);
}
```

**Test:**
```solidity
function test_getPrice_revertsWhenStale() public {
    vm.warp(block.timestamp + 2 hours);
    vm.expectRevert(abi.encodeWithSelector(Vault.StalePrice.selector, initialTimestamp));
    vault.getPrice();
}
```

---

### 5b. L2 Sequencer Uptime Check

**Vulnerability:** On L2s (Arbitrum, Optimism, Base), the sequencer can go offline. Chainlink
serves the last known price during downtime. Contracts should reject reads during sequencer
outage and for a grace period after it restarts.

**Mitigation:**
```solidity
AggregatorV2V3Interface internal sequencerUptimeFeed;
uint256 private constant GRACE_PERIOD = 1 hours;

function _checkSequencer() internal view {
    (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
    if (answer != 0) revert SequencerDown();
    if (block.timestamp - startedAt < GRACE_PERIOD) revert GracePeriodNotOver(startedAt);
}
```

---

## Domain 6: Flash Loan and MEV Vectors

### 6a. Flash Loan Governance Attack

**Vulnerability:** If governance voting power is determined by token balance at the current block,
an attacker can borrow tokens, vote, and repay in one transaction.

**Detection:** Any governance or voting contract that uses `balanceOf(voter)` at current block
without a snapshot mechanism.

**Mitigation:** Use OpenZeppelin's `ERC20Votes` with `getPastVotes(account, block.number - 1)` —
past block snapshots are immune to flash loan manipulation.

---

### 6b. Sandwich Attack

**Vulnerability:** A transaction that swaps or provides liquidity at a spot price can be
front-run (buy before) and back-run (sell after) by a searcher, extracting value from the user.

**Mitigation:** Require caller to specify a minimum output amount:
```solidity
function swap(uint256 amountIn, uint256 minAmountOut) external {
    uint256 amountOut = _calculateSwap(amountIn);
    if (amountOut < minAmountOut) revert InsufficientOutput(amountOut, minAmountOut);
    // proceed
}
```

---

## Domain 7: Upgrade Security

### 7a. Unprotected `_authorizeUpgrade`

**Vulnerability:** UUPS upgrades require overriding `_authorizeUpgrade`. An empty override or
one with insufficient access control allows anyone to upgrade the contract.

**Detection:** Search for `_authorizeUpgrade`. If empty or missing access control, it's Critical.

**Mitigation:**
```solidity
// BAD: empty override = anyone can upgrade
function _authorizeUpgrade(address) internal override {}

// GOOD: explicit access control
function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
{}
```

---

### 7b. Unprotected Initializer

**Vulnerability:** If `_disableInitializers()` is not called in the implementation constructor,
anyone can initialize the implementation contract directly and use it as an attack surface.

**Mitigation:**
```solidity
/// @custom:oz-upgrades-unsafe-allow constructor
constructor() {
    _disableInitializers();
}
```

---

### 7c. Storage Layout Collision

**Vulnerability:** Upgrading a contract and adding/reordering state variables shifts existing
storage slots, corrupting all stored data.

**Detection:**
```bash
forge inspect OldContract storage-layout --pretty > old-layout.txt
forge inspect NewContract storage-layout --pretty > new-layout.txt
diff old-layout.txt new-layout.txt
```

Any reordering, removal, or type change of existing slots is a Critical finding.

**Mitigation:** Only append new state variables. Use the `__gap` pattern:
```solidity
uint256[49] private __gap; // reserve 49 slots for future upgrades
```

---

## Domain 8: Denial of Service

### 8a. Unbounded Loop Over User-Controlled Array

**Vulnerability:** A function iterates over an array that users can grow without limit. As the
array grows, the function eventually exceeds the block gas limit and reverts on every call.

**Proof of concept:**
```solidity
address[] public depositors;

function distributeYield() external {
    for (uint256 i; i < depositors.length; ++i) { // grows as users deposit
        token.safeTransfer(depositors[i], yield / depositors.length);
    }
}
// After 10,000 depositors: gas cost exceeds block limit → permanent DoS
```

**Mitigation:** Replace enumeration with accumulator pattern:
```solidity
mapping(address => uint256) public accruedYield;

function claimYield() external {
    uint256 owed = accruedYield[msg.sender];
    accruedYield[msg.sender] = 0;
    token.safeTransfer(msg.sender, owed);
}
```

---

### 8b. Push Payment Failure

**Vulnerability:** Sending ETH in a loop. If one recipient's `receive()` reverts (e.g., a
contract with no fallback), the entire distribution fails.

**Mitigation:** Pull pattern — let recipients claim their own funds:
```solidity
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0; // CEI: effects before interactions
    (bool ok,) = msg.sender.call{value: amount}("");
    if (!ok) revert WithdrawFailed(msg.sender, amount);
}
```

---

## Domain 9: Signature Replay and EIP-712

### 9a. Missing Nonce — Replay Attack

**Vulnerability:** A signed message without a nonce can be replayed by anyone who observes it
on-chain.

**Mitigation:**
```solidity
mapping(address => uint256) public nonces;

function execute(bytes calldata payload, bytes calldata sig) external {
    bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
        EXECUTE_TYPEHASH,
        keccak256(payload),
        nonces[msg.sender]++  // increment nonce: each signature valid once
    )));
    address signer = ECDSA.recover(digest, sig);
    if (signer != msg.sender) revert InvalidSignature(signer, msg.sender);
}
```

---

### 9b. Missing Chain ID in Domain Separator — Cross-Chain Replay

**Vulnerability:** A signature valid on a testnet is also valid on mainnet if the domain
separator does not include `chainId`.

**Mitigation:** Use `EIP712` from OpenZeppelin. It includes `chainId` in the domain separator
by default:
```solidity
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MyContract is EIP712 {
    constructor() EIP712("MyContract", "1") {}
    // _domainSeparatorV4() includes chainId automatically
}
```

---

### 9c. Missing Deadline — Signature Valid Forever

**Vulnerability:** Without an expiry, a signed permission is valid indefinitely. If a user
later wants to revoke, they cannot (nonce increment won't help if the signature is never used).

**Mitigation:** Always include a `deadline` parameter in signed messages:
```solidity
struct PermitData {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline; // required
}

// Verify deadline in execution
if (block.timestamp > deadline) revert PermitExpired(deadline);
```

---

## Domain 10 (ERC-4626 Specific): Protocol-Level Attacks

### 10a. First-Depositor Attack

See Domain 3d above.

### 10b. Donation Attack (inflate totalAssets without minting shares)

**Vulnerability:** An attacker transfers tokens directly to the vault address (not via deposit).
This inflates `totalAssets()` without minting shares, increasing the share price and diluting
existing depositors' redemption value.

**Detection:** Check if `totalAssets()` uses `token.balanceOf(address(this))` directly.

**Mitigation:** Virtual offset as in Domain 3d, or track `totalDeposited` as internal accounting
separate from raw balance. Any balance above `totalDeposited` is yield, handled separately.

### 10c. Rounding Direction Violations

**Detection:** Run this test suite against all ERC-4626 functions:
```solidity
// Property: deposit then redeem should never profit the user
function testFuzz_depositRedeem_noProfit(uint256 assets) public {
    assets = bound(assets, 1, maxDeposit);
    uint256 shares = vault.deposit(assets, user);
    uint256 redeemed = vault.redeem(shares, user, user);
    assertLe(redeemed, assets); // user must not profit from rounding
}

// Property: mint then withdraw should never cost the vault more than minted
function testFuzz_mintWithdraw_noVaultLoss(uint256 shares) public {
    shares = bound(shares, 1, maxMint);
    uint256 assets = vault.mint(shares, user);
    uint256 withdrawn = vault.withdraw(assets, user, user);
    assertGe(withdrawn, shares); // vault burns at most `withdrawn` shares
}
```
