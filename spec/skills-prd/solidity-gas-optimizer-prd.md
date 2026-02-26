# Skill PRD: `solidity-gas-optimizer`

**Output file:** `skills/solidity-gas-optimizer/SKILL.md`
**Supporting file:** `skills/solidity-gas-optimizer/gas-checklist.md`

**When:** After all tests pass for a contract. Before security review or deployment. Also when
the user asks about gas efficiency, "can we reduce costs?", or after any significant implementation
change that might affect gas consumption.

---

## Why This Skill Exists

Gas optimization is not premature optimization. Storage layout decisions made during build become
permanent architecture. A badly packed struct cannot be refactored after deployment without a
migration. A state variable that should have been an `immutable` cannot be changed to one in an
upgradeable contract without a storage layout change.

This skill separates architectural gas decisions (must be caught early) from micro-optimizations
(can be caught anytime). Both matter: DeFi contracts interact with thousands of users over years.
A 1,000-gas saving per call at 100,000 calls/year is $400/year at 20 gwei and ETH at $2,000.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-gas-optimizer
description: >
  Gas optimization gate for Solidity contracts before deployment. Dispatches the optimizoor agent
  to run a full 8-category gas audit. Use when: tests pass and contract is ready for gas review,
  user asks "is this gas efficient?", "can we reduce gas costs?", "optimize gas", "check gas
  usage", or after any implementation change to a value-handling function. Covers: storage layout
  and slot packing, function visibility, calldata vs memory, loop optimization, arithmetic
  (unchecked), custom errors, compiler configuration, and event vs storage decisions. Produces a
  gas audit report with forge snapshot diff before deployment.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO DEPLOYMENT WITHOUT A GAS AUDIT REPORT IN docs/audits/
```

---

## Hard Gate

This skill dispatches the `optimizoor` agent to run the full 8-category checklist.
No deployment proceeds without:
1. The gas audit report at `docs/audits/YYYY-MM-DD-<contract>-gas.md`
2. `forge snapshot --diff` output showing before/after gas changes
3. Contract size verified under 24,576 bytes

---

## How to Dispatch Optimizoor

The SKILL.md must include explicit instructions for dispatching the `optimizoor` agent:

```
When this skill is invoked:
1. Run `forge snapshot` to capture the pre-optimization baseline
2. Run `forge inspect <ContractName> storage-layout --pretty` for all contracts
3. Dispatch the `optimizoor` agent with:
   - Full source code of all in-scope contracts
   - Output of `forge inspect storage-layout` for each contract
   - Output of `forge build --sizes`
   - The `.gas-snapshot` baseline
4. Wait for the optimizoor report
5. For each finding: apply the fix, run `forge test` (must pass), run `forge snapshot --diff`
6. Write the final gas audit report
```

---

## Full Checklist (8 Categories)

The SKILL.md must reproduce this checklist. The `gas-checklist.md` supporting file contains the
full version with code examples; the SKILL.md contains the reference summary.

### Category 1: Storage Layout (Highest Impact — Architectural)

These decisions are permanent. Fix them before any other optimization.

**1.1 Struct slot packing**

The EVM reads and writes storage in 32-byte (256-bit) slots. Multiple smaller types fit in one
slot if ordered correctly.

```
// BAD: 3 slots used
struct Position {
    uint128 amount;     // slot 0 (16 bytes, 16 bytes wasted)
    address owner;      // slot 1 (20 bytes, 12 bytes wasted)
    uint128 interest;   // slot 2 (16 bytes, 16 bytes wasted)
}

// GOOD: 2 slots used (amount + owner share slot 0; interest uses slot 1)
struct Position {
    uint128 amount;     // slot 0: bytes 0-15
    address owner;      // slot 0: bytes 16-35 (fits in same slot as amount)
    uint128 interest;   // slot 1: bytes 0-15
}

// BEST: 1 slot used (if interest fits in uint96 or uint64)
struct Position {
    uint96 amount;      // 12 bytes
    address owner;      // 20 bytes
    // total = 32 bytes = 1 slot
}
```

Rule: order struct fields from largest to smallest type within each slot group. Group fields
that are read together in the same slot.

**1.2 `constant` for compile-time values**

Constants are inlined at compile time — zero storage cost, zero SLOAD:
```solidity
// BAD: reads from storage on every call (SLOAD = 100-2100 gas)
uint256 public MAX_FEE = 1000;

// GOOD: inlined at compile time (zero gas to read)
uint256 public constant MAX_FEE = 1000;
```

Applies to: fee caps, role constants (bytes32 role hashes), magic numbers, addresses of
immutable protocol contracts.

**1.3 `immutable` for constructor-set values**

Immutables are stored in bytecode, not storage. Reading costs 3 gas (PUSH) vs 100-2100 gas (SLOAD):
```solidity
// BAD: SLOAD on every read (100-2100 gas depending on warm/cold)
address public asset;
constructor(address _asset) { asset = _asset; }

// GOOD: stored in bytecode, costs 3 gas to read
address public immutable asset;
constructor(address _asset) { asset = _asset; }
```

Applies to: token addresses, oracle addresses, factory addresses, any address or value set once
in constructor and never changed.

Note: `immutable` cannot be used with upgradeable contracts (no constructor). Use
`constant` where possible; for upgradeable, initialize to storage once in `initialize()`.

**1.4 Boolean packing into bitmap**

5+ boolean state variables should be packed into a single `uint256` bitmap:
```solidity
// BAD: 5 storage slots
bool public isActive;
bool public isPaused;
bool public isDepositEnabled;
bool public isWithdrawEnabled;
bool public isEmergencyMode;

// GOOD: 1 storage slot, 2 gas to toggle (vs 5,000+ for SSTORE)
uint256 private _flags;
uint256 private constant FLAG_ACTIVE           = 1 << 0;
uint256 private constant FLAG_PAUSED           = 1 << 1;
uint256 private constant FLAG_DEPOSIT_ENABLED  = 1 << 2;
uint256 private constant FLAG_WITHDRAW_ENABLED = 1 << 3;
uint256 private constant FLAG_EMERGENCY        = 1 << 4;

function isActive() public view returns (bool) { return _flags & FLAG_ACTIVE != 0; }
```

### Category 2: Function Visibility

**2.1 `external` vs `public` for non-internally-called functions**

`public` functions copy calldata parameters to memory. `external` reads them directly from
calldata. For functions with array or struct parameters, this is significant:
```solidity
// BAD: copies calldata to memory (extra gas for array/struct params)
function processOrders(Order[] memory orders) public { ... }

// GOOD: reads directly from calldata
function processOrders(Order[] calldata orders) external { ... }
```

Rule: if a function is never called internally (via `this.func()` or within the contract without
explicit `this`), make it `external`.

**2.2 Remove explicit getters for public state variables**

Solidity auto-generates getters for all public state variables. Writing manual getters wastes
deployment gas:
```solidity
// BAD: manual getter duplicates auto-generated one
uint256 public fee;
function getFee() external view returns (uint256) { return fee; } // DELETE THIS

// GOOD: public generates getFee() automatically
uint256 public fee;
```

### Category 3: Calldata vs Memory

**3.1 External function array/struct parameters: `calldata` over `memory`**

```solidity
// BAD: memory copies the array
function batchTransfer(address[] memory recipients, uint256[] memory amounts) external { ... }

// GOOD: calldata avoids the copy
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external { ... }
```

Savings scale with array size. For large arrays (100+ elements), this can save thousands of gas.

**3.2 Small types in function parameters for pure computation**

The EVM operates on 256-bit words. Small types in parameters require masking:
```solidity
// BAD: uint8 in computation-only param causes masking overhead
function compute(uint8 multiplier) external pure returns (uint256) { ... }

// GOOD: uint256 for computation-only, small types only for storage
function compute(uint256 multiplier) external pure returns (uint256) { ... }
```

Exception: small types are correct for storage struct fields — packing is more important there.

### Category 4: Loop Optimization

**4.1 Cache array length before loop**

```solidity
// BAD: .length is an SLOAD on every iteration if array is in storage
for (uint256 i; i < recipients.length; ++i) { ... }

// GOOD: cache length in memory variable (free MLOAD after first)
uint256 len = recipients.length;
for (uint256 i; i < len; ++i) { ... }
```

**4.2 Cache storage reads inside loops**

```solidity
// BAD: SLOAD on every iteration (100-2100 gas each)
for (uint256 i; i < len; ++i) {
    total += balances[user]; // SLOAD per iteration
}

// GOOD: cache once, read from memory (3 gas per access)
uint256 userBalance = balances[user]; // 1 SLOAD
for (uint256 i; i < len; ++i) {
    total += userBalance; // MLOAD
}
```

**4.3 `++i` over `i++`**

`i++` creates a temporary copy. `++i` modifies in place. ~5 gas saved per iteration.

**4.4 `unchecked` loop counters**

Loop counters bounded by array length (bounded by gas limit) cannot overflow:
```solidity
// BAD: Solidity 0.8 overflow check on every increment (~30 gas wasted per iteration)
for (uint256 i; i < len; ++i) { ... }

// GOOD: unchecked counter saves ~30 gas per iteration
for (uint256 i; i < len; ) {
    // loop body
    unchecked { ++i; } // overflow impossible: i bounded by len, len bounded by gas limit
}
```

### Category 5: Arithmetic — Unchecked Blocks

`unchecked` blocks skip Solidity 0.8's overflow/underflow checks. Use only when overflow is
provably impossible. The comment proving it is mandatory for auditors.

```solidity
// GOOD: unchecked subtraction after comparison
function safeDecrement(uint256 balance, uint256 amount) internal pure returns (uint256) {
    if (balance < amount) revert InsufficientBalance(balance, amount);
    // Safe: comparison above proves balance >= amount, so underflow impossible
    unchecked { return balance - amount; }
}

// GOOD: unchecked multiplication where inputs are bounded
function calculateFee(uint256 amount, uint256 bps) internal pure returns (uint256) {
    // Safe: amount bounded by vault's maxDeposit (1e30), bps bounded by MAX_FEE (1000)
    // 1e30 * 1000 = 1e33, well within uint256.max (~1.15e77)
    unchecked { return amount * bps / 10_000; }
}

// BAD: no proof, no comment
unchecked {
    return a - b; // Could underflow if caller doesn't check
}
```

**Precision rule:** Never divide before multiplying.
```solidity
// BAD: (a / b) * c — division truncates, multiplying after loses precision
uint256 result = (principal / totalSupply) * newRate;

// GOOD: (a * c) / b — multiply first, then divide
uint256 result = (principal * newRate) / totalSupply;
```

### Category 6: Custom Errors (Final Reminder)

String reverts cost ~50 gas per character stored. Custom errors use 4-byte selectors:
```
require(condition, "InsufficientBalance: amount exceeds balance")
// Costs: ~1600 gas just for the string storage

error InsufficientBalance(uint256 requested, uint256 available);
if (!condition) revert InsufficientBalance(requested, available);
// Costs: ~50 gas for the 4-byte selector
```

The optimizoor agent should flag every `require(condition, "string")` it finds. There should be zero.

### Category 7: Compiler Configuration

**7.1 `optimizer_runs` tuning**

Higher `optimizer_runs` = larger bytecode (more deployment gas) but cheaper call gas:
```toml
# foundry.toml

# Deployed once, called rarely (factories, one-time setup contracts)
[profile.default]
optimizer = true
optimizer_runs = 200

# Called frequently (AMM, vault, token) — optimized for cheap calls over cheap deploy
[profile.production]
optimizer = true
optimizer_runs = 10000
```

**7.2 `via_ir` for complex contracts**

The IR compilation pipeline produces better optimization for contracts with complex control flow,
especially those with many nested calls or intricate storage patterns:
```toml
via_ir = true
```

Warning: `via_ir` increases compile time significantly (~3x on large contracts). Use when:
- Contract has complex internal function calls
- Optimizer output from normal pipeline is worse than expected
- Testing shows gas savings with `--diff` after enabling

Always compare snapshots before/after enabling `via_ir`.

**7.3 Solidity version**

Pin to the latest stable version for optimizer improvements and bug fixes:
```solidity
pragma solidity 0.8.25; // pin exact version, never floating (^0.8.x)
```

Solidity 0.8.22+ includes loop overflow checks that the compiler can sometimes eliminate automatically.

### Category 8: Events vs Storage

**8.1 Off-chain-only data → events**

State variables that are only ever read by off-chain systems (subgraphs, indexers, analytics)
waste gas. Use events:
```solidity
// BAD: 20,000+ gas SSTORE for data only an indexer reads
mapping(address => uint256) public depositTimestamps;
depositTimestamps[msg.sender] = block.timestamp;

// GOOD: ~375 gas LOG for data only an indexer reads
event DepositTimestamp(address indexed user, uint256 timestamp);
emit DepositTimestamp(msg.sender, block.timestamp);
```

To identify candidates: look for state variables read only by `view` functions that are never
called on-chain or in tests (only in off-chain scripts).

**8.2 Indexed parameters: only for filtered fields**

Each indexed parameter costs 375 extra gas. Index only fields that off-chain systems will filter by:
```solidity
// BAD: amounts are rarely filtered — wasting 375 gas indexing them
event Transfer(address indexed from, address indexed to, uint256 indexed amount);

// GOOD: only index filterable fields (who sent/received)
event Transfer(address indexed from, address indexed to, uint256 amount);
```

---

## Forge Commands for Gas Analysis

The SKILL.md must include these commands as a ready-to-run reference:

```bash
# Inspect storage layout — do this FIRST
forge inspect <ContractName> storage-layout --pretty

# Create gas baseline
forge snapshot

# Compare after optimizations
forge snapshot --diff

# Detailed gas per function per test
forge test --gas-report

# Check contract bytecode size (max: 24,576 bytes = 24KB)
forge build --sizes

# Measure gas with specific foundry profile
FOUNDRY_PROFILE=production forge test --gas-report
```

---

## Supporting File: gas-checklist.md

This file lives at `skills/solidity-gas-optimizer/gas-checklist.md`.

It must contain:
- Full 8-category checklist with one Solidity code example (before/after) for each item
- Gas cost reference table (SLOAD cold: 2100, SLOAD warm: 100, SSTORE new: 20000, SSTORE update: 5000, LOG base: 375, LOG per byte: 8)
- foundry.toml configuration templates for different contract profiles (deployed-once vs high-frequency)
- Common false positives (when NOT to apply each optimization)

---

## Output Artifacts

Gas audit report at `docs/audits/YYYY-MM-DD-<contract>-gas.md`:

```markdown
# Gas Audit Report: <ContractName>
**Date:** YYYY-MM-DD
**Auditor:** optimizoor agent
**Baseline snapshot:** <attach forge snapshot output>

## Findings Summary
| ID | Category | Severity | Gas Saved | File:Line |
|----|----------|----------|-----------|-----------|
| G-01 | Storage Layout | HIGH | ~15,000/tx | src/Vault.sol:47 |
| G-02 | Loop | MEDIUM | ~30/iteration | src/Vault.sol:112 |

## Finding Detail

### G-01: Struct fields not packed — 3 slots used instead of 2
**File:** src/Vault.sol, lines 45-52
**Current code:**
```solidity
struct Position {
    uint128 amount;
    address owner;  // breaks packing
    uint128 interest;
}
```
**Recommended fix:**
```solidity
struct Position {
    uint128 amount;
    address owner;  // now shares slot 0 with amount
    uint128 interest; // slot 1
}
```
**Estimated savings:** 1 SLOAD per read = 100-2100 gas per read
**Risk:** None — pure reordering, no behavioral change

## forge snapshot diff
<attach output of forge snapshot --diff>

## Contract sizes
<attach output of forge build --sizes>
```

---

## Terminal State

Exit to `solidity-code-reviewer` (security review) or `solidity-deployer` (if review is done).

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "Gas optimization is premature" | Storage layout and `immutable`/`constant` decisions are architectural. They cannot be changed after deployment without a migration. Premature optimization is micro-optimizing; architecture is mandatory. |
| "The optimizer handles it" | The Solidity optimizer doesn't reorder your struct fields, choose between `constant` and storage variables, or decide between events and storage writes. You do. |
| "This is a testnet deploy" | Testnet deploys become mainnet patterns. If the struct is packed wrong on testnet, it will be packed wrong on mainnet. Fix it now. |
| "The savings are too small to matter" | 1,000 gas × 100,000 calls/year × 20 gwei × $2,000/ETH = $4,000/year in user fees. It matters. |
| "The contract is simple" | Simple contracts often have the easiest wins: a single `immutable` conversion, a struct reorder, one loop fix. Low-hanging fruit with no risk. |
