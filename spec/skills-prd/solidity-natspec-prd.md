# Skill PRD: `solidity-natspec`

**Output file:** `skills/solidity-natspec/SKILL.md`
**Supporting file:** `skills/solidity-natspec/natspec-templates.md`

**When:** After GREEN phase in TDD (function logic is correct), before committing any function.
Also whenever the user mentions "add docs", "document this", "add natspec", "add comments", or
asks what a function does in a way that implies the code lacks explanation.

---

## Why This Skill Exists

NatSpec is not documentation for documentation's sake. It is:
1. **The auditor's first read.** Well-written NatSpec means auditors understand intent faster and
   can spot deviations from intent (i.e., bugs) more easily. Bad NatSpec wastes auditor time
   and increases audit cost.
2. **The compiler's input for ABI documentation.** Tools like Etherscan, Hardhat, and Foundry
   consume NatSpec to generate human-readable interfaces.
3. **The developer's regression test.** If the code changes and the NatSpec doesn't, one is
   wrong. NatSpec written alongside code documents the intent at the time of writing.
4. **The frontend developer's guide.** `@param` and `@return` fields describe units, constraints,
   and expected behavior so frontends can validate inputs and handle errors correctly.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-natspec
description: >
  NatSpec documentation gate for Solidity contracts. Use when committing any function, error,
  event, state variable, or contract definition. Triggers on: "add docs", "document this function",
  "add natspec", "add comments", "what does this function do?", or any time a function is
  committed without documentation. Enforces: @notice, @dev, @param, @return on all public and
  external functions; @notice and @dev on all custom errors; @notice on all events; @notice on
  public state variables. Covers: quality rules for each field, cross-referencing patterns,
  security annotation requirements, and templates for every Solidity element type.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO COMMIT WITHOUT NATSPEC ON EVERY PUBLIC AND EXTERNAL FUNCTION, CUSTOM ERROR, AND EVENT
```

Internal and private functions with non-obvious security implications also require `@dev` docs.
"Non-obvious" means: contains unchecked arithmetic, makes external calls, has unusual access
patterns, or implements a security-critical check.

---

## Hard Gate

If a function, error, or event is committed without NatSpec, the next skill invocation must
flag and fix it. The skill runs before every commit — not as an afterthought.

---

## Required NatSpec Fields by Element Type

### Functions (public / external)

All four fields are required. "I'll add it later" is not allowed.

```solidity
/// @notice One-sentence description of what this function does in plain English.
///         Must be understandable by someone who has not read the implementation.
///         Written from the user's perspective: "Deposits assets into the vault and returns shares."
/// @dev    Technical implementation details for developers and auditors.
///         Must include:
///         - Security pattern used: "Follows CEI: checks, effects, interactions."
///         - Reentrancy guard: "Protected by nonReentrant modifier."
///         - Access control: "Callable only by addresses with OPERATOR_ROLE."
///         - External call targets: "Calls token.safeTransferFrom() in INTERACTIONS phase."
///         - Rounding behavior: "Rounds down: caller receives fewer shares to protect vault."
///         - Known edge cases or deviations from the interface spec.
/// @param  <paramName> What this parameter represents. Include:
///                     - Units: "in wei (18-decimal token)" or "in basis points (100 = 1%)"
///                     - Constraints: "must be > 0 and <= maxDeposit(receiver)"
///                     - Special values: "0 means no fee is charged"
/// @return <returnName> What the return value represents. Include units and meaning.
///                      If the return is a struct or tuple, describe each field.
```

**Example — good NatSpec:**
```solidity
/// @notice Deposits ERC-20 assets into the vault and mints shares to the receiver.
/// @dev    Follows CEI pattern strictly. Calls token.safeTransferFrom in INTERACTIONS phase.
///         Protected by nonReentrant and whenNotPaused modifiers.
///         Rounding: previewDeposit rounds down (caller receives ≤ expected shares).
///         Emits {Deposit} event on success.
///         See {withdraw} for the inverse operation.
/// @param  assets   The amount of underlying token to deposit, in token decimals.
///                  Must be > 0 and <= maxDeposit(receiver). Reverts with {ZeroAmount} if 0.
/// @param  receiver The address that will receive the minted shares.
///                  Cannot be address(0). Reverts with {InvalidReceiver} if zero address.
/// @return shares   The number of vault shares minted to the receiver.
///                  Calculated by previewDeposit(assets). Will be > 0 when assets > 0.
function deposit(uint256 assets, address receiver)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares)
```

**Example — bad NatSpec (must be rejected):**
```solidity
/// @notice Deposits assets.
/// @param assets The amount.
/// @return shares The shares.
function deposit(uint256 assets, address receiver) ...
```

### Custom Errors

```solidity
/// @notice Thrown when the caller attempts an operation they are not authorized to perform.
/// @dev    Emitted by the access control modifier before any state changes occur.
///         The caller field identifies who attempted the unauthorized action.
///         The required field identifies what role was required.
/// @param  caller   The address that made the unauthorized call
/// @param  required The role or address that was required for this operation
error Unauthorized(address caller, bytes32 required);
```

Every custom error parameter must be described. Parameters without descriptions are useless
for developers debugging reverts on-chain.

### Events

```solidity
/// @notice Emitted when a user deposits assets into the vault and receives shares.
/// @dev    Indexed fields: depositor (for per-user filtering), asset (for per-token filtering).
///         Data fields: assets, shares (for accounting; rarely filtered by value).
///         Consumers: subgraph, frontend balance tracking, protocol analytics.
/// @param  depositor The address that called deposit() (may differ from receiver)
/// @param  receiver  The address that received the minted shares
/// @param  assets    The amount of underlying token deposited (in token decimals)
/// @param  shares    The number of shares minted to the receiver
event Deposited(
    address indexed depositor,
    address indexed receiver,
    uint256 assets,
    uint256 shares
);
```

### State Variables (public)

```solidity
/// @notice The fee charged on withdrawals, in basis points (100 = 1%).
/// @dev    Set by the owner via setWithdrawalFee(). Maximum value: MAX_WITHDRAWAL_FEE (1000 = 10%).
///         A value of 0 disables withdrawal fees entirely.
///         Fee is calculated as: fee = assets * withdrawalFeeBps / 10_000
uint256 public withdrawalFeeBps;
```

### Contract and Interface Definitions

```solidity
/// @title  Vault — ERC-4626 Yield-Bearing Vault
/// @author Zaryab
/// @notice Accepts deposits of ASSET token, deploys capital to STRATEGY, distributes yield as
///         shares. Implements ERC-4626 standard with pause, fee, and upgrade mechanisms.
/// @dev    Inherits: ERC4626Upgradeable, OwnableUpgradeable, PausableUpgradeable,
///                   ReentrancyGuardUpgradeable, UUPSUpgradeable.
///         Storage layout: see proxy-pattern-guide.md. Gap reserved for 49 future slots.
///         Security model:
///           - Owner: multisig with 24h timelock on all privileged operations
///           - Users: any EOA or contract that can receive ERC-20 tokens
///         Invariants:
///           - token.balanceOf(vault) >= totalAssets() at all times (solvency)
///           - totalSupply() == sum of all user share balances (accounting)
contract Vault is ERC4626Upgradeable, OwnableUpgradeable, PausableUpgradeable,
                  ReentrancyGuardUpgradeable, UUPSUpgradeable {
```

---

## NatSpec Quality Rules

### Rule 1: `@notice` must be user-readable

The `@notice` field is shown to users in wallet UIs, block explorers, and documentation sites.
Write it for someone who has never seen the code:

```
BAD:  "Calls _internalWithdraw with the provided params and checks CEI"
GOOD: "Withdraws assets from the vault, burns the corresponding shares, and transfers assets to receiver"
```

### Rule 2: `@dev` must include all security-relevant facts

The `@dev` field is for developers and auditors. It must answer:
- What security pattern is in use? (CEI, mutex, access control modifier)
- What external contracts are called, and where in the function?
- What rounding behavior applies, and which direction? (ERC-4626 requires careful rounding)
- Are there any deviation from the standard or interface specification?
- Are there any known edge cases or surprising behaviors?

### Rule 3: `@param` must include constraints and units

"The amount" is not a `@param` description. The complete description includes:
- **What:** what the parameter represents
- **Units:** what unit it's in (wei, basis points, shares, bytes, block numbers)
- **Constraints:** valid range, zero semantics, special values
- **Revert:** what happens when the constraint is violated

```
BAD:  @param amount The amount to deposit
GOOD: @param amount The amount of underlying token to deposit, in token decimals (18 for USDC).
                    Must be > 0 and <= maxDeposit(receiver). Reverts with {ZeroAmount} if 0,
                    {ExceedsMaxDeposit} if amount > maxDeposit(receiver).
```

### Rule 4: `@return` must describe meaning, not just name

```
BAD:  @return shares The shares
GOOD: @return shares The number of vault shares minted to the receiver. Calculated using
                     previewDeposit(assets) rounding. Always > 0 when assets > 0.
                     Can be 0 if the vault uses minimum deposit thresholds.
```

### Rule 5: Cross-reference related functions

Include cross-references using `{FunctionName}` syntax:
```solidity
/// @dev See {withdraw} for the inverse operation.
///      See {previewDeposit} to calculate shares before calling.
///      Emits {Deposited} event on success.
```

### Rule 6: Document security-critical internal functions

Security-critical `internal` and `private` functions require `@dev` documentation even though
they are not user-facing. Security-critical means:

- Performs access control checks
- Contains unchecked arithmetic
- Makes external calls
- Contains the core invariant-maintaining logic
- Implements the upgrade authorization logic

```solidity
/// @dev Authorizes contract upgrades. Called by UUPSUpgradeable._upgradeTo().
///      Access control: restricted to addresses with UPGRADER_ROLE.
///      If this function body is empty or improperly guarded, anyone can upgrade the contract.
///      CRITICAL: This is the entire security model of the UUPS upgrade pattern.
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
```

---

## Supporting File: natspec-templates.md

This file lives at `skills/solidity-natspec/natspec-templates.md`.

### Required Content

The file must contain copy-paste ready templates for every Solidity element type, pre-filled
with placeholder text that guides the writer:

**Template 1: Standard value-transferring function**
```solidity
/// @notice [WHAT IT DOES FOR THE USER — one sentence, plain English]
/// @dev    [SECURITY PATTERN: CEI/nonReentrant/access control]
///         [EXTERNAL CALLS: what is called and in which phase]
///         [ROUNDING: direction and why]
///         [EMITS: {EventName}]
///         [SEE: {relatedFunction} for context]
/// @param  [PARAM_NAME] [WHAT IT IS] in [UNITS]. Must be [CONSTRAINT]. Reverts with
///                      {ErrorName} if [VIOLATION].
/// @return [RETURN_NAME] [WHAT IT IS] in [UNITS]. [RANGE/BEHAVIOR].
```

**Template 2: Admin/privileged function**
```solidity
/// @notice [WHAT CONFIGURATION IS CHANGED — one sentence]
/// @dev    Access: restricted to [ROLE/MODIFIER]. Applied immediately, no delay.
///         [OR: Applied after [TIMELOCK_DURATION] timelock delay.]
///         Previous value is [LOST/RETURNED/EMITTED].
///         Emits {[EventName]}.
/// @param  [PARAM_NAME] New value for [SETTING]. Must be in range [MIN, MAX].
///                      Units: [UNITS]. Special values: [SPECIAL_MEANING].
```

**Template 3: View/pure function**
```solidity
/// @notice Returns [WHAT IS RETURNED] for [SUBJECT].
/// @dev    [COMPUTATION: how the return value is calculated, what assumptions it makes]
///         [PRECISION: rounding direction, precision loss]
///         [STALENESS: whether the returned value could be stale]
/// @param  [PARAM] [DESCRIPTION]
/// @return [VALUE] [DESCRIPTION, UNITS, RANGE]
```

**Template 4: Constructor / initializer**
```solidity
/// @notice Initializes the [CONTRACT_NAME] contract.
/// @dev    [For upgradeable: Called once via proxy. Replaces constructor.]
///         Sets [LIST_OF_THINGS_INITIALIZED].
///         Grants [ROLE] to [initialOwner/msg.sender].
///         After initialization: [STATE_DESCRIPTION].
/// @param  [PARAM] [DESCRIPTION, CONSTRAINTS]
```

**Template 5: Custom error with parameters**
```solidity
/// @notice Thrown when [CONDITION IN USER-FACING LANGUAGE].
/// @dev    [WHEN IT IS THROWN: which function, which check]
///         [HOW TO RESOLVE: what the caller should do]
/// @param  [PARAM] [WHAT THIS TELLS THE CALLER — value at time of revert]
```

**Template 6: Event**
```solidity
/// @notice Emitted when [CONDITION].
/// @dev    [WHO EMITS IT: which function(s)]
///         [INDEXED FIELDS: which fields are indexed and why]
///         [CONSUMERS: subgraph, frontend, monitoring]
/// @param  [PARAM] [WHAT IT REPRESENTS]
```

---

## Output Artifacts

NatSpec is inline in the source files. No separate artifact is produced.

Before any commit, the coding agent must verify:
- [ ] Every `public` and `external` function has `@notice`, `@dev`, `@param` (for each param), `@return` (for each return)
- [ ] Every `error` has `@notice`, `@dev`, and `@param` for each parameter
- [ ] Every `event` has `@notice` and `@param` for each parameter
- [ ] Every `public` state variable has `@notice`
- [ ] Every contract and interface definition has `@title`, `@notice`, `@dev`
- [ ] Security-critical `internal` functions have `@dev`

---

## Terminal State

NatSpec runs continuously. It does not block transitions between other skills — but functions
without NatSpec cannot be committed. The skill applies on every commit, not just at "the docs phase."

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The function name is self-explanatory" | `transfer(address to, uint256 amount)` means nothing without "@param amount in wei, must be > 0, reverts with InsufficientBalance." The name doesn't explain constraints. |
| "I'll add docs at the end" | Functions change during development. NatSpec written at the end describes the final implementation, not the intent. Intent is what auditors need. |
| "It's an internal function" | Internal functions with non-obvious security properties (`_authorizeUpgrade`, `_beforeTokenTransfer`, unchecked arithmetic) need `@dev`. Security-critical code is security-critical regardless of visibility. |
| "NatSpec is boilerplate" | NatSpec is the auditor's roadmap. Good NatSpec reduces audit time — and therefore cost. Bad NatSpec means auditors spend time understanding obvious things and miss subtle bugs. |
| "The code is readable enough" | You are not the audience. The audience is: a developer unfamiliar with your code, an auditor on a tight deadline, a frontend engineer integrating your contract, and a user who got an error on Etherscan. Write for them. |
