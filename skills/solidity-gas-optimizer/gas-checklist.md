# Gas Optimization Checklist

Full reference with code examples, false positives, and cost tables for the `solidity-gas-optimizer` skill.

---

## Gas Cost Reference Table

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| SLOAD (cold) | 2,100 | First access to a storage slot in the transaction |
| SLOAD (warm) | 100 | Subsequent accesses to the same slot |
| SSTORE (new value, was zero) | 20,000 | Setting a slot from 0 to non-zero |
| SSTORE (update, was non-zero) | 5,000 | Changing an existing non-zero value |
| SSTORE (delete, set to zero) | 5,000 (net: -15,000 refund) | Zeroing a slot triggers a gas refund |
| MLOAD | 3 | Memory read |
| MSTORE | 3 | Memory write |
| LOG (base) | 375 | Event emission base cost |
| LOG (per byte of data) | 8 | Event data cost per byte |
| LOG (indexed topic) | 375 | Per indexed parameter |
| CALL | 2,600 | External call base cost (cold) |
| PUSH (immutable read) | 3 | Bytecode-stored immutable, treated as a push opcode |

---

## Category 1: Storage Layout

### 1.1 Struct Slot Packing

**Vulnerability:** Struct fields ordered without considering slot boundaries waste storage slots,
increasing both deployment gas and per-transaction SLOAD costs.

**Before (3 slots):**
```solidity
struct Position {
    uint128 amount;     // slot 0: bytes 0-15 (16 bytes, 16 bytes wasted in slot 0)
    address owner;      // slot 1: bytes 0-19 (20 bytes, 12 bytes wasted in slot 1)
    uint128 interest;   // slot 2: bytes 0-15 (16 bytes, 16 bytes wasted in slot 2)
}
// Total: 3 SLOADs to read all fields
```

**After (2 slots):**
```solidity
struct Position {
    uint128 amount;     // slot 0: bytes 0-15
    address owner;      // slot 0: bytes 16-35 (20 bytes; 0-15 used by amount, fits with 12 wasted)
    uint128 interest;   // slot 1: bytes 0-15
}
// Total: 2 SLOADs to read all fields (saves 100-2100 gas per full struct read)
```

**Best (1 slot — use smaller types where domain allows):**
```solidity
struct Position {
    uint96 amount;      // 12 bytes — sufficient for values up to ~79 billion in 18-decimal tokens
    address owner;      // 20 bytes
    // 12 + 20 = 32 bytes = 1 full slot
}
// Total: 1 SLOAD to read all fields
```

**Packing rule:**
- EVM slots are 32 bytes (256 bits)
- Fields are packed left-to-right in declaration order
- A field that doesn't fit in the remaining space of the current slot starts a new slot
- Order: group fields that are read together AND sum to ≤ 32 bytes

**False positives — when NOT to pack:**
- When fields in the same slot are written separately in different transactions: two SSTOREs
  on separate slots costs 2 × 5,000 = 10,000 gas; two SSTOREs on the same slot requires a
  read-modify-write: SLOAD + 2 × SSTORE overhead. Packing fields that are always written
  together saves gas; packing fields that are always written separately costs gas.
- When the smaller type causes precision loss that breaks the protocol invariants.

---

### 1.2 `constant` for Compile-Time Values

**Vulnerability:** Storage variables for values known at compile time incur an SLOAD (100–2100 gas)
on every read.

**Before:**
```solidity
uint256 public MAX_FEE = 1000;
bytes32 public OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
address public BURN_ADDRESS = address(0xdead);
```

**After:**
```solidity
uint256 public constant MAX_FEE = 1000;
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
address public constant BURN_ADDRESS = address(0xdead);
```

**Gas saved:** 100–2100 gas per read, depending on slot warmth.

**Applies to:**
- Fee caps and rate limits
- Role hashes (`keccak256("ROLE_NAME")`)
- Magic numbers used in calculations
- Addresses of immutable protocol contracts (if known at compile time)

**False positives — when NOT to use constant:**
- When the value must be configurable after deployment (use storage + setter + access control)
- When the value is set during construction from a constructor argument (use `immutable`)

---

### 1.3 `immutable` for Constructor-Set Values

**Vulnerability:** Constructor-initialized storage variables incur SLOAD costs on every read.
`immutable` stores values in bytecode after construction, making reads a 3-gas PUSH.

**Before:**
```solidity
address public asset;
address public oracle;
uint256 public maxDeposit;

constructor(address _asset, address _oracle, uint256 _maxDeposit) {
    asset = _asset;
    oracle = _oracle;
    maxDeposit = _maxDeposit;
}
```

**After:**
```solidity
address public immutable asset;
address public immutable oracle;
uint256 public immutable maxDeposit;

constructor(address _asset, address _oracle, uint256 _maxDeposit) {
    asset = _asset;
    oracle = _oracle;
    maxDeposit = _maxDeposit;
}
```

**Gas saved:** 97–2097 gas per read (3 gas instead of 100–2100).

**False positives — when NOT to use immutable:**
- Upgradeable contracts: no constructor runs, so `immutable` is not set. Initialize to storage
  in `initialize()` instead, and accept the SLOAD cost.
- When the value must change after deployment.

---

### 1.4 Boolean Packing into Bitmap

**Vulnerability:** Each `bool` state variable occupies an entire 32-byte storage slot. Five booleans
use 5 slots; reading them all costs 5 × 100–2100 = 500–10,500 gas.

**Before:**
```solidity
bool public isActive;
bool public isPaused;
bool public isDepositEnabled;
bool public isWithdrawEnabled;
bool public isEmergencyMode;
```

**After:**
```solidity
uint256 private _flags;
uint256 private constant FLAG_ACTIVE           = 1 << 0;
uint256 private constant FLAG_PAUSED           = 1 << 1;
uint256 private constant FLAG_DEPOSIT_ENABLED  = 1 << 2;
uint256 private constant FLAG_WITHDRAW_ENABLED = 1 << 3;
uint256 private constant FLAG_EMERGENCY        = 1 << 4;

function isActive() public view returns (bool) { return _flags & FLAG_ACTIVE != 0; }
function isPaused() public view returns (bool) { return _flags & FLAG_PAUSED != 0; }

function _setFlag(uint256 flag, bool value) private {
    if (value) { _flags |= flag; } else { _flags &= ~flag; }
}
```

**Gas saved:** 4 × 100–2100 gas per full flag set read (all flags read from 1 SLOAD instead of 5).

**Threshold:** Apply when you have 5 or more boolean state variables.

**False positives — when NOT to use bitmap:**
- When flags are set independently and you're more concerned about write cost than read cost.
  Each SSTORE that updates one flag in the bitmap still costs the same as updating a standalone bool.
  The benefit is in reads, not writes.

---

## Category 2: Function Visibility

### 2.1 `external` vs `public`

**Before:**
```solidity
function deposit(uint256 assets, address receiver) public returns (uint256 shares) { ... }
function batchMint(address[] memory to, uint256[] memory amounts) public { ... }
```

**After:**
```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares) { ... }
function batchMint(address[] calldata to, uint256[] calldata amounts) external { ... }
```

**Detection:** Search for `public` functions. For each: verify they are called internally (within
the same contract without `this.`). If not, convert to `external`.

**False positives — when NOT to change:**
- Functions called internally via `super.functionName()` or plain `functionName()` must remain `public`.
- Functions that implement an interface and are called by the contract itself must remain `public`.

### 2.2 Redundant Manual Getters

**Detection:** Search for `function get<VariableName>()` that returns a single state variable.
Cross-check: is `<variableName>` declared `public`? If yes, the getter is redundant.

**False positives:** None. Remove all redundant manual getters.

---

## Category 3: Calldata vs Memory

### 3.1 Array and Struct Parameters

**Detection:** Search all `external` functions for parameters declared as `memory` arrays or structs.

**Before:**
```solidity
function batchTransfer(
    address[] memory recipients,
    uint256[] memory amounts,
    bytes memory data
) external { ... }
```

**After:**
```solidity
function batchTransfer(
    address[] calldata recipients,
    uint256[] calldata amounts,
    bytes calldata data
) external { ... }
```

**Gas saved:** Proportional to array size. For 100-element arrays of `address`, saving is
roughly 100 × 96 gas (memory expansion overhead) = ~9,600 gas.

**False positives — when NOT to use calldata:**
- When the function modifies the array in place (calldata is read-only).
- When the function is `public` (use `memory` there; calldata is only for `external`).

---

## Category 4: Loop Optimization

### 4.1 Cache Array Length

**Detection:** Search for `for (uint256 i; i < <something>.length` where `<something>` is a
storage variable (not a local `memory` array — memory arrays have cheap length access).

### 4.2 Cache Storage Reads

**Detection:** Look for storage reads (`mapping[key]`, `storageArray[i]`, `storageVar`) inside
loop bodies. Any storage read in a loop that could be hoisted before the loop is a finding.

### 4.3 `++i` over `i++`

**Detection:** Search for `i++` in loop increment positions. Replace all.

### 4.4 Unchecked Loop Counter

**Full pattern:**
```solidity
uint256 len = array.length;
for (uint256 i; i < len; ) {
    // --- loop body ---
    _processItem(array[i]);
    // ------------------
    unchecked { ++i; } // Safe: i bounded by len which is bounded by block gas limit
}
```

**Combining all four loop optimizations:**
```solidity
// BAD: all four issues present
for (uint256 i = 0; i < storageArray.length; i++) {
    total += balances[storageArray[i]];
}

// GOOD: all four applied
uint256 len = storageArray.length; // [4.1] cache length
for (uint256 i; i < len; ) {      // [4.3] ++i, [4.4] unchecked below
    address user = storageArray[i]; // [4.2] cache storage in loop — but this is inside loop;
                                    // if balances[user] were the same user each time, hoist above
    unchecked {
        total += balances[user];    // still SLOAD per iteration here for different users
        ++i;                        // [4.3] + [4.4]
    }
}
```

---

## Category 5: Arithmetic — Unchecked Blocks

### When Unchecked Is Safe

```solidity
// Pattern 1: subtraction after explicit comparison
if (a < b) revert Underflow(a, b);
unchecked { return a - b; } // Safe: a >= b proven above

// Pattern 2: multiplication with proven bounded inputs
// amount <= maxDeposit (1e30), feeBps <= MAX_FEE (1000)
// 1e30 * 1000 = 1e33 << 1.15e77 (uint256.max)
unchecked { fee = amount * feeBps / 10_000; } // Safe: bounds proven above

// Pattern 3: loop counter
unchecked { ++i; } // Safe: i bounded by array length, bounded by block gas limit
```

### Precision Rule: Multiply Before Dividing

```solidity
// BAD: precision loss
// If principal = 1e6, totalSupply = 1e18, newRate = 1e15:
// (1e6 / 1e18) = 0 (truncated!) → result = 0
uint256 result = (principal / totalSupply) * newRate;

// GOOD: full precision preserved
// (1e6 * 1e15) / 1e18 = 1e21 / 1e18 = 1e3 = 1000
uint256 result = (principal * newRate) / totalSupply;
```

---

## Category 6: Custom Errors

### String Cost vs. Selector Cost

```
require(condition, "InsufficientBalance: amount exceeds balance")
= 1 PUSH of the string hash into memory
+ ~44 characters × 8 gas/byte = ~352 gas for the string in revert data
+ ABI encoding overhead
≈ 600–1600 gas total

error InsufficientBalance(uint256 requested, uint256 available);
if (!condition) revert InsufficientBalance(requested, available);
= 4-byte selector + ABI-encoded parameters
≈ 50–100 gas for selector + 32 gas per parameter
```

**Detection:** `grep -rn 'require(' src/` — every match is a finding unless it has no string argument.

**False positives:** None. All `require` with string messages should be custom errors.

---

## Category 7: Compiler Configuration

### foundry.toml Templates

**Template A: Contract deployed once, called infrequently (factory, registry, governance)**
```toml
[profile.default]
solc = "0.8.25"
optimizer = true
optimizer_runs = 200
```

**Template B: Contract called frequently by many users (AMM, vault, token)**
```toml
[profile.default]
solc = "0.8.25"
optimizer = true
optimizer_runs = 1000

[profile.production]
optimizer_runs = 10000
via_ir = true
```

**Template C: Complex contract with IR optimization**
```toml
[profile.production]
solc = "0.8.25"
optimizer = true
optimizer_runs = 10000
via_ir = true
# Note: via_ir significantly increases compile time. Only use after verifying savings.
```

### Comparing Profiles

```bash
# Run with default profile, capture snapshot
forge snapshot --snap .gas-snapshot-default

# Run with production profile, capture snapshot
FOUNDRY_PROFILE=production forge snapshot --snap .gas-snapshot-production

# Diff the two
diff .gas-snapshot-default .gas-snapshot-production
```

---

## Category 8: Events vs Storage

### Identifying Off-Chain-Only State Variables

Candidates for conversion to events:
1. State variables that are only read by `view` functions
2. Those `view` functions are never called from other contracts in tests (only in off-chain scripts)
3. The variable is never used in any computation that affects contract state

**Detection steps:**
1. List all storage variables
2. For each: find all read sites
3. If all reads are in external `view` functions and those `view` functions are never called
   internally, the variable is a candidate for event replacement

### Indexed Parameter Cost

```solidity
// Each indexed parameter adds 375 gas (stored as a Bloom filter topic)
event Transfer(
    address indexed from,   // +375 gas
    address indexed to,     // +375 gas
    uint256 indexed amount  // +375 gas — BAD: amounts are rarely filtered
);

// GOOD: only index what off-chain consumers filter by
event Transfer(
    address indexed from,  // +375 gas — good: filter by sender
    address indexed to,    // +375 gas — good: filter by recipient
    uint256 amount         // no extra cost — amounts in event data, not topic
);
```

**Rule:** Maximum 2 indexed parameters per event unless the third is a common filter target.
Never index `uint256` amounts unless your indexer explicitly filters by exact amount.

---

## Forge Command Reference

```bash
# Step 1: Storage layout analysis
forge inspect <ContractName> storage-layout --pretty

# Step 2: Capture baseline
forge snapshot

# Step 3: Apply optimizations, then compare
forge snapshot --diff

# Step 4: Gas report by function
forge test --gas-report

# Step 5: Contract size check (limit: 24,576 bytes)
forge build --sizes

# Step 6: Profile-specific measurement
FOUNDRY_PROFILE=production forge test --gas-report

# Step 7: Check optimizer impact
FOUNDRY_PROFILE=production forge snapshot --snap .gas-snapshot-prod
diff .gas-snapshot .gas-snapshot-prod
```
