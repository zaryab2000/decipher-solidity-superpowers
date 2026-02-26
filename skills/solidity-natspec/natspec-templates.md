# NatSpec Templates

Copy-paste templates for every Solidity element type. Replace all `[PLACEHOLDER]` markers with
actual content. Every field is mandatory — do not delete any line, only fill it in.

---

## Template 1: Standard Value-Transferring Function

Use for: deposit, withdraw, transfer, mint, burn, swap — any function that moves tokens or
updates user balances.

```solidity
/// @notice [WHAT IT DOES FOR THE USER — one sentence, plain English, written from user's perspective]
/// @dev    [SECURITY PATTERN: "Follows CEI: checks preconditions, updates state, then calls external contracts."]
///         [REENTRANCY: "Protected by nonReentrant modifier as defense-in-depth."]
///         [ACCESS CONTROL: "Callable by any address." OR "Restricted to OPERATOR_ROLE."]
///         [EXTERNAL CALLS: "Calls token.safeTransferFrom(msg.sender, address(this), assets) in INTERACTIONS phase."]
///         [ROUNDING: "Rounds down in favor of the vault: caller receives <= previewDeposit(assets) shares."]
///         [EMITS: "Emits {EventName} on success."]
///         [SEE: "See {inverseFunction} for the reverse operation."]
/// @param  [PARAM_NAME] [WHAT IT REPRESENTS] in [UNITS: wei / basis points / shares / block numbers].
///                      Must be [CONSTRAINT: > 0 / <= maxValue / non-zero address].
///                      Reverts with {ErrorName} if [VIOLATION CONDITION].
/// @param  [PARAM_NAME_2] [DESCRIPTION]. [CONSTRAINTS]. Reverts with {ErrorName} if [VIOLATION].
/// @return [RETURN_NAME] [WHAT IT REPRESENTS] in [UNITS]. [RANGE OR BEHAVIOR: always > 0 / can be 0 if...].
```

**Filled example:**
```solidity
/// @notice Deposits ERC-20 assets into the vault and mints shares to the receiver.
/// @dev    Follows CEI pattern strictly. Calls token.safeTransferFrom in INTERACTIONS phase.
///         Protected by nonReentrant and whenNotPaused modifiers.
///         Rounding: previewDeposit rounds down (caller receives <= expected shares).
///         Emits {Deposit} event on success.
///         See {withdraw} for the inverse operation.
/// @param  assets   The amount of underlying token to deposit, in token decimals (18 for USDC).
///                  Must be > 0 and <= maxDeposit(receiver). Reverts with {ZeroAmount} if 0.
///                  Reverts with {ExceedsMaxDeposit} if assets > maxDeposit(receiver).
/// @param  receiver The address that will receive the minted shares.
///                  Cannot be address(0). Reverts with {InvalidReceiver} if zero address.
/// @return shares   The number of vault shares minted to the receiver.
///                  Calculated by previewDeposit(assets). Always > 0 when assets > 0.
function deposit(uint256 assets, address receiver)
    external
    nonReentrant
    whenNotPaused
    returns (uint256 shares)
{
```

---

## Template 2: Admin / Privileged Function

Use for: setFee, pause, unpause, grantRole, setOracle, upgradeTo — any function restricted to
a role or owner.

```solidity
/// @notice [WHAT CONFIGURATION IS CHANGED — one sentence describing the user-visible effect]
/// @dev    Access: restricted to [ROLE/MODIFIER: onlyOwner / onlyRole(ADMIN_ROLE)].
///         [TIMING: "Applied immediately, no delay." OR "Queued for TIMELOCK_DURATION; caller
///          must call execute() after the delay to apply."]
///         [PREVIOUS VALUE: "Previous value is overwritten and not retrievable on-chain."]
///         [BOUNDS: "Value is validated against [MIN, MAX] before assignment."]
///         Emits {[EventName]} with old and new value.
/// @param  [PARAM_NAME] New value for [SETTING NAME].
///                      Must be in range [[MIN], [MAX]].
///                      Units: [UNITS]. Special values: [SPECIAL_MEANING or "none"].
```

**Filled example:**
```solidity
/// @notice Sets the withdrawal fee charged on all subsequent withdrawals.
/// @dev    Access: restricted to onlyOwner (owner is 3-of-5 Gnosis Safe multisig).
///         Applied immediately, no timelock delay for fee changes <= MAX_FEE.
///         Previous fee value is overwritten; emitted in {WithdrawalFeeUpdated}.
///         Validates: newFeeBps <= MAX_WITHDRAWAL_FEE (1000 = 10%) to prevent exploitative fees.
///         Emits {WithdrawalFeeUpdated} with previous and new fee values.
/// @param  newFeeBps New withdrawal fee in basis points (100 = 1%, 1000 = 10%).
///                   Must be in range [0, 1000]. 0 disables withdrawal fees entirely.
///                   Reverts with {ExceedsMaxFee} if newFeeBps > MAX_WITHDRAWAL_FEE.
function setWithdrawalFee(uint256 newFeeBps) external onlyOwner {
```

---

## Template 3: View / Pure Function

Use for: previewDeposit, convertToShares, totalAssets, balanceOf, getPrice — any read-only
function that returns computed or stored data.

```solidity
/// @notice Returns [WHAT IS RETURNED] for [SUBJECT / CONTEXT].
/// @dev    [COMPUTATION: "Calculates shares = assets * totalSupply / totalAssets, rounded down."]
///         [PRECISION: "Precision loss: result truncated to uint256; at most 1 wei lost per call."]
///         [STALENESS: "May return stale data if called during a reentrancy window (use with care)."]
///         [DEVIATION: "Returns 1:1 ratio when vault is empty (totalAssets == 0)."]
/// @param  [PARAM] [DESCRIPTION, UNITS, CONSTRAINTS]
/// @return [VALUE] [DESCRIPTION, UNITS, RANGE: always >= 0 / can be 0 when... / bounded by...]
```

**Filled example:**
```solidity
/// @notice Returns the number of shares that would be minted for a given asset deposit amount.
/// @dev    Calculation: shares = assets * (totalSupply + 1) / (totalAssets + 1).
///         The +1 offset prevents first-depositor share inflation attacks.
///         Rounds down in favor of the vault (caller receives fewer shares than the exact ratio).
///         Returns 0 if assets is 0. Does not revert on zero input.
/// @param  assets The hypothetical deposit amount in token decimals (18 for USDC).
///                Does not need to satisfy maxDeposit — this is a preview, not a transaction.
/// @return shares The number of shares that would be minted. Rounds down. Can be 0 for dust inputs.
function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
```

---

## Template 4: Constructor / Initializer

Use for: `constructor(...)` in non-upgradeable contracts, `initialize(...)` in upgradeable contracts.

```solidity
/// @notice Initializes the [CONTRACT_NAME] contract with the given parameters.
/// @dev    [For upgradeable contracts: "Called once via proxy deploy. Replaces the constructor.
///          Protected by the initializer modifier — reverts on second call."]
///         [For non-upgradeable: "Constructor. Sets immutable values that cannot change after deploy."]
///         Sets [LIST THE THINGS INITIALIZED: owner, asset, oracle, max deposit, etc.].
///         Grants [ROLE] to [WHO: initialOwner / msg.sender].
///         Post-initialization state: [DESCRIBE WHAT IS TRUE AFTER THIS RUNS].
/// @param  [PARAM] [DESCRIPTION, CONSTRAINTS, WHAT HAPPENS IF INVALID]
```

**Filled example — upgradeable:**
```solidity
/// @notice Initializes the Vault with the given asset, oracle, and owner.
/// @dev    Called once via the proxy during deployment. Protected by initializer — reverts on
///         any subsequent call. Replaces the constructor for upgradeable contracts.
///         Sets: asset (immutable), oracle address, max deposit limit.
///         Calls: __ERC4626_init(asset), __Ownable_init(initialOwner), __ReentrancyGuard_init().
///         Grants OWNER_ROLE to initialOwner; no other roles are granted at initialization.
///         Post-init: paused = false, withdrawalFeeBps = 0, vault accepts deposits immediately.
/// @param  asset        The ERC-20 token accepted as the vault's underlying asset.
///                      Cannot be address(0). Must implement IERC20Metadata.
/// @param  oracle       The Chainlink price feed for asset/USD pricing.
///                      Cannot be address(0). Must implement AggregatorV3Interface.
/// @param  initialOwner The address granted the OWNER_ROLE and Ownable ownership.
///                      Cannot be address(0). Should be a multisig, not an EOA.
function initialize(address asset, address oracle, address initialOwner)
    external
    initializer
{
```

---

## Template 5: Custom Error with Parameters

```solidity
/// @notice Thrown when [CONDITION IN USER-FACING LANGUAGE — describe the failure, not the code].
/// @dev    [WHEN: "Thrown by [functionName()] at the [CHECKS / EFFECTS / INTERACTIONS] phase."]
///         [HOW TO RESOLVE: "Caller should call [previewFunction()] first to verify inputs."]
/// @param  [PARAM] [WHAT THIS VALUE TELLS THE CALLER — the value at the time of revert]
/// @param  [PARAM_2] [WHAT THIS VALUE TELLS THE CALLER]
```

**Filled example:**
```solidity
/// @notice Thrown when a deposit amount would result in receiving zero shares.
/// @dev    Thrown by deposit() and mint() during the CHECKS phase, before any state changes.
///         Occurs when assets is so small relative to totalAssets that rounding produces 0 shares.
///         Resolution: increase deposit amount or call previewDeposit(assets) first to check.
/// @param  assets     The deposit amount that produced zero shares (in token decimals)
/// @param  minShares  The minimum shares required (always 1 for standard deposits)
error ZeroSharesMinted(uint256 assets, uint256 minShares);
```

---

## Template 6: Event

```solidity
/// @notice Emitted when [CONDITION — describe the protocol event in user-facing language].
/// @dev    [WHO EMITS: "Emitted by [functionName()]."]
///         [INDEXED RATIONALE: "Indexed: [fieldName] for per-user filtering. [field2] for per-token filtering."]
///         [CONSUMERS: "Consumed by: subgraph indexer, frontend balance tracker, protocol analytics."]
/// @param  [PARAM] [WHAT THIS FIELD REPRESENTS — include units and whether it may differ from obvious]
```

**Filled example:**
```solidity
/// @notice Emitted when a user successfully deposits assets into the vault and receives shares.
/// @dev    Emitted by deposit() and mint() after all state changes, in the INTERACTIONS phase.
///         Indexed: depositor for per-user deposit history. receiver for per-recipient share tracking.
///         Note: depositor and receiver may differ when using deposit-on-behalf patterns.
///         Consumers: subgraph (balance tracking), frontend (deposit confirmation), analytics.
/// @param  depositor The address that called deposit() and provided the assets (msg.sender)
/// @param  receiver  The address that received the newly minted shares (may differ from depositor)
/// @param  assets    The amount of underlying token deposited, in token decimals
/// @param  shares    The number of vault shares minted and sent to receiver
event Deposited(
    address indexed depositor,
    address indexed receiver,
    uint256 assets,
    uint256 shares
);
```

---

## Template 7: Security-Critical Internal Function

Use for: `_authorizeUpgrade`, `_beforeTokenTransfer`, `_internalWithdraw`, functions containing
unchecked arithmetic or external calls.

```solidity
/// @dev    [WHAT THIS FUNCTION DOES — one sentence, written for a developer/auditor]
///         [CALLER: "Called by [public function or OpenZeppelin hook name]."]
///         [ACCESS CONTROL: "Restricted by [modifier or inline check]. Reverts with {Error} if violated."]
///         [SECURITY NOTE: highlight any security-critical behavior or assumptions]
///         [UNCHECKED: if present: "unchecked block at line X: safe because [PROOF OF BOUNDS]"]
///         [EXTERNAL CALLS: "Calls [contract.function()] — external call target is [trusted/untrusted]."]
```

**Filled example:**
```solidity
/// @dev    Authorizes contract upgrades. Called by UUPSUpgradeable._upgradeTo() before applying upgrade.
///         Caller: only called internally by the UUPS upgrade mechanism when upgradeTo() is invoked.
///         Access control: restricted to onlyRole(UPGRADER_ROLE).
///         CRITICAL: If this function is empty or improperly guarded, any address can upgrade
///         the contract to a malicious implementation. This is the entire upgrade security model.
///         No logic other than the access control modifier is needed or should be added.
function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
{}
```

---

## NatSpec Verification Commands

```bash
# Generate full NatSpec documentation site
forge doc

# Output NatSpec to a specific directory
forge doc --out docs/natspec/

# Build — compiler emits warnings for undocumented public functions when strict NatSpec is enabled
forge build

# Check which public/external functions lack NatSpec (requires forge doc output)
forge doc 2>&1 | grep "missing"
```

---

## Common NatSpec Mistakes to Avoid

| Mistake | Correct Pattern |
|---------|-----------------|
| `@param amount The amount` | `@param amount The deposit amount in token decimals (18 for USDC). Must be > 0.` |
| `@return The result` | `@return shares Number of vault shares minted. Always > 0 when assets > 0.` |
| `@notice Calls _internalWithdraw` | `@notice Withdraws assets from the vault and transfers them to the receiver.` |
| Missing `@dev` on external function | Every external function needs `@dev` with CEI, access control, external calls, rounding. |
| Missing `@param` for one param | Every parameter in the function signature gets its own `@param` line. |
| `@dev See the code` | `@dev` must contain the information an auditor needs without reading the implementation. |
| No `@notice` on public state var | `@notice` on state variables describes what the value means, units, and who can change it. |
| Missing `@title` on contract | Every contract and interface file needs `@title`, `@author`, `@notice`, `@dev`. |
