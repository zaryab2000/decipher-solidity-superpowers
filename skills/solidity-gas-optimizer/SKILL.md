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

## When

After all tests pass for a contract. Before security review or deployment. Also when the user
asks about gas efficiency, "can we reduce costs?", or after any significant implementation
change that might affect gas consumption.

## The strict rule

```
NO DEPLOYMENT WITHOUT A GAS AUDIT REPORT IN docs/audits/
```

## Hard Gate

This skill dispatches the `optimizoor` agent to run the full 8-category checklist.
No deployment proceeds without:
1. The gas audit report at `docs/audits/YYYY-MM-DD-<contract>-gas.md`
2. `forge snapshot --diff` output showing before/after gas changes
3. Contract size verified under 24,576 bytes

## Mandatory Checklist

### Step 1: Capture baseline

```bash
forge snapshot
forge inspect <ContractName> storage-layout --pretty
forge build --sizes
```

### Step 2: Dispatch optimizoor

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

### Step 3: Apply findings

For every finding the optimizoor returns:
- [ ] Apply the fix to the source file
- [ ] Run `forge test` — all tests must pass after the fix
- [ ] Run `forge snapshot --diff` — record the delta
- [ ] Note the gas saved in the audit report

### Step 4: Write the gas audit report

Save to `docs/audits/YYYY-MM-DD-<contract>-gas.md` using the format in the Output Artifacts
section below.

## Gas Optimization Checklist (8 Categories)

See `gas-checklist.md` for full code examples, false-positive warnings, and the gas cost
reference table.

### Category 1: Storage Layout — Highest Impact (Architectural, Permanent)

**1.1 Struct slot packing** — Order fields so smaller types share slots.

```solidity
// BAD: 3 slots
struct Position { uint128 amount; address owner; uint128 interest; }

// GOOD: 2 slots (amount + owner in slot 0)
struct Position { uint128 amount; address owner; uint128 interest; }
// amount (16B) + owner (20B) = 36B → doesn't fit. Reorder:
struct Position { address owner; uint128 amount; uint128 interest; }
// owner (20B) + amount (12B from uint96) → use uint96:
struct Position { address owner; uint96 amount; uint64 interest; } // 1 slot
```

Rule: order struct fields from largest to smallest type within each slot group. Group fields
that are read together in the same slot.

**1.2 `constant` for compile-time values** — Zero storage cost, zero SLOAD.

```solidity
// BAD: SLOAD on every read (100–2100 gas)
uint256 public MAX_FEE = 1000;

// GOOD: inlined at compile time (0 gas to read)
uint256 public constant MAX_FEE = 1000;
```

Applies to: fee caps, role constants (bytes32 hashes), magic numbers, immutable protocol addresses.

**1.3 `immutable` for constructor-set values** — Stored in bytecode, costs 3 gas to read.

```solidity
// BAD: SLOAD per read (100–2100 gas)
address public asset;
constructor(address _asset) { asset = _asset; }

// GOOD: bytecode storage, 3 gas to read
address public immutable asset;
constructor(address _asset) { asset = _asset; }
```

Note: `immutable` cannot be used with upgradeable contracts (no constructor). Use `constant`
where possible; for upgradeable, initialize to storage once in `initialize()`.

**1.4 Boolean packing into bitmap** — 5+ booleans should use a single `uint256` bitmap.

```solidity
// BAD: 5 storage slots
bool public isActive;
bool public isPaused;
bool public isDepositEnabled;
bool public isWithdrawEnabled;
bool public isEmergencyMode;

// GOOD: 1 storage slot
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

`public` copies calldata to memory. `external` reads directly from calldata.

```solidity
// BAD: copies calldata to memory
function processOrders(Order[] memory orders) public { ... }

// GOOD: reads directly from calldata
function processOrders(Order[] calldata orders) external { ... }
```

Rule: if a function is never called internally, make it `external`.

**2.2 Remove explicit getters for public state variables**

Solidity auto-generates getters for all `public` state variables.

```solidity
// BAD: manual getter duplicates auto-generated one (wastes deployment gas)
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

// GOOD: calldata avoids the copy (scales with array size)
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external { ... }
```

**3.2 Use `uint256` for computation-only parameters**

```solidity
// BAD: uint8 in computation-only param causes masking overhead
function compute(uint8 multiplier) external pure returns (uint256) { ... }

// GOOD: uint256 for computation; small types only for storage
function compute(uint256 multiplier) external pure returns (uint256) { ... }
```

Exception: small types are correct for storage struct fields — packing is more important there.

### Category 4: Loop Optimization

**4.1 Cache array length before loop**

```solidity
// BAD: .length is SLOAD on every iteration for storage arrays
for (uint256 i; i < recipients.length; ++i) { ... }

// GOOD: cache in memory (free MLOAD after first read)
uint256 len = recipients.length;
for (uint256 i; i < len; ++i) { ... }
```

**4.2 Cache storage reads inside loops**

```solidity
// BAD: SLOAD on every iteration (100–2100 gas each)
for (uint256 i; i < len; ++i) { total += balances[user]; }

// GOOD: 1 SLOAD, then MLOAD (3 gas) per iteration
uint256 userBalance = balances[user];
for (uint256 i; i < len; ++i) { total += userBalance; }
```

**4.3 `++i` over `i++`** — `i++` creates a temporary copy. `++i` modifies in place. ~5 gas/iteration.

**4.4 `unchecked` loop counters** — Counters bounded by array length cannot overflow.

```solidity
// BAD: Solidity 0.8 overflow check on every increment (~30 gas wasted)
for (uint256 i; i < len; ++i) { ... }

// GOOD: unchecked counter saves ~30 gas/iteration
for (uint256 i; i < len; ) {
    // loop body
    unchecked { ++i; } // overflow impossible: i bounded by len, len bounded by gas limit
}
```

### Category 5: Arithmetic — Unchecked Blocks

Use `unchecked` only when overflow is provably impossible. The proving comment is mandatory.

```solidity
// GOOD: unchecked subtraction after comparison
function safeDecrement(uint256 balance, uint256 amount) internal pure returns (uint256) {
    if (balance < amount) revert InsufficientBalance(balance, amount);
    // Safe: comparison above proves balance >= amount, so underflow impossible
    unchecked { return balance - amount; }
}

// BAD: no proof, no comment — do not write this
unchecked { return a - b; }
```

**Precision rule: never divide before multiplying.**

```solidity
// BAD: (a / b) * c — division truncates first, loses precision
uint256 result = (principal / totalSupply) * newRate;

// GOOD: (a * c) / b — multiply first, then divide
uint256 result = (principal * newRate) / totalSupply;
```

### Category 6: Custom Errors

String reverts cost ~50 gas per character. Custom errors use 4-byte selectors.

```solidity
// BAD: ~1600 gas for the string storage
require(condition, "InsufficientBalance: amount exceeds balance");

// GOOD: ~50 gas for the 4-byte selector
error InsufficientBalance(uint256 requested, uint256 available);
if (!condition) revert InsufficientBalance(requested, available);
```

The optimizoor agent must flag every `require(condition, "string")`. There should be zero.

### Category 7: Compiler Configuration

**7.1 `optimizer_runs` tuning**

```toml
# foundry.toml

# Deployed once, called rarely (factories, one-time setup)
[profile.default]
optimizer = true
optimizer_runs = 200

# Called frequently (AMM, vault, token) — optimize for cheap calls over cheap deploy
[profile.production]
optimizer = true
optimizer_runs = 10000
```

**7.2 `via_ir` for complex contracts**

```toml
via_ir = true
```

Warning: `via_ir` increases compile time ~3x. Use when the contract has complex control flow
or optimizer output from the normal pipeline is worse than expected. Always compare snapshots
before and after enabling.

**7.3 Solidity version — pin to latest stable**

```solidity
pragma solidity 0.8.25; // pin exact version, never floating (^0.8.x)
```

Solidity 0.8.22+ includes loop overflow checks the compiler can sometimes eliminate automatically.

### Category 8: Events vs Storage

**8.1 Off-chain-only data → events**

```solidity
// BAD: 20,000+ gas SSTORE for data only an indexer reads
mapping(address => uint256) public depositTimestamps;
depositTimestamps[msg.sender] = block.timestamp;

// GOOD: ~375 gas LOG for off-chain data
event DepositTimestamp(address indexed user, uint256 timestamp);
emit DepositTimestamp(msg.sender, block.timestamp);
```

**8.2 Indexed parameters: only for filtered fields**

Each indexed parameter costs 375 extra gas. Index only fields off-chain systems filter by.

```solidity
// BAD: amounts rarely filtered — wastes 375 gas indexing them
event Transfer(address indexed from, address indexed to, uint256 indexed amount);

// GOOD: index only filterable fields
event Transfer(address indexed from, address indexed to, uint256 amount);
```

## Forge Commands

```bash
# Inspect storage layout — do this FIRST
forge inspect <ContractName> storage-layout --pretty

# Create gas baseline
forge snapshot

# Compare after optimizations
forge snapshot --diff

# Detailed gas per function per test
forge test --gas-report

# Check contract bytecode size (max: 24,576 bytes)
forge build --sizes

# Measure gas with a specific Foundry profile
FOUNDRY_PROFILE=production forge test --gas-report
```

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
struct Position { uint128 amount; address owner; uint128 interest; }
**Recommended fix:**
struct Position { address owner; uint128 amount; uint128 interest; }
**Estimated savings:** 1 SLOAD per read = 100-2100 gas per read
**Risk:** None — pure reordering, no behavioral change

## forge snapshot diff
<attach output of forge snapshot --diff>

## Contract sizes
<attach output of forge build --sizes>
```

## Terminal State

Exit to `solidity-code-reviewer` (security review) or `solidity-deployer` (if review is done).

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "Gas optimization is premature" | Storage layout and `immutable`/`constant` decisions are architectural. They cannot be changed after deployment without a migration. Premature optimization is micro-optimizing; architecture is mandatory. |
| "The optimizer handles it" | The Solidity optimizer doesn't reorder struct fields, choose between `constant` and storage variables, or decide between events and storage writes. You do. |
| "This is a testnet deploy" | Testnet deploys become mainnet patterns. If the struct is packed wrong on testnet, it will be packed wrong on mainnet. Fix it now. |
| "The savings are too small to matter" | 1,000 gas × 100,000 calls/year × 20 gwei × $2,000/ETH = $4,000/year in user fees. It matters. |
| "The contract is simple" | Simple contracts often have the easiest wins: a single `immutable` conversion, a struct reorder, one loop fix. Low-hanging fruit with no risk. |
