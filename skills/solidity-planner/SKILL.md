---
name: solidity-planner
description: >
  Gate-enforced design phase for Solidity smart contract development. Use this skill before
  writing ANY .sol file — contracts, interfaces, libraries, or upgradeable implementations.
  Triggers on: "write a contract", "design a vault", "build a staking system", "create a token",
  "plan this protocol", "what should the architecture be", "I want to build X on-chain", or any
  similar intent to create new Solidity code. Enforces: design doc → interface → approval before
  a single line of implementation code. The plan gate cannot be skipped, even for "simple"
  contracts.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20)
metadata:
  author: Zaryab
  version: "1.0"
---

## When

Before writing ANY contract, interface, library, or significant function. This is the mandatory
entry point for all new Solidity work — whether the user wants a token, a vault, a governance
contract, an AMM, or a single utility function.

## The strict rule

```
NO CONTRACT CODE BEFORE AN APPROVED DESIGN DOCUMENT AND COMMITTED INTERFACE
```

## Hard Gate

No `.sol` files, no scaffolding, no function signatures may be created or written until:
1. The design document exists at `docs/designs/YYYY-MM-DD-<contract-name>-design.md`
2. The interface file exists at `src/interfaces/I<ContractName>.sol`
3. The user has explicitly approved the design (not assumed consent, not silence)

If the PreToolUse hook fires and blocks a `.sol` write, explain the gate and offer to run through
the planning checklist at speed — not skip it.

## Mandatory Checklist

### Phase 1: Identify and Classify the Contract

Before asking any questions, classify the contract. The category determines which vulnerability
patterns, OpenZeppelin bases, and known attack surfaces apply.

| Category | Common OZ Bases | Known Attack Patterns to Check |
|---|---|---|
| **ERC-20 token** | `ERC20`, `ERC20Permit`, `ERC20Burnable`, `ERC20Votes` | Approval frontrunning, infinite approval risks, permit replay |
| **ERC-721 NFT** | `ERC721`, `ERC721Enumerable`, `ERC721URIStorage` | Reentrancy on `safeTransferFrom`, royalty bypass |
| **ERC-1155 multi-token** | `ERC1155`, `ERC1155Supply` | Batch transfer reentrancy, operator approval abuse |
| **ERC-4626 vault** | `ERC4626`, `ERC20` | First-depositor inflation attack, rounding direction (share math), donation attack |
| **Staking / rewards** | `Ownable2Step`, `ReentrancyGuard`, `Pausable` | Reward manipulation, flash-stake, incorrect accounting |
| **Governance** | `Governor`, `GovernorTimelockControl`, `GovernorVotes` | Proposal manipulation, quorum manipulation, timelock bypass |
| **Lending / borrow** | `AccessControl`, `ReentrancyGuard` | Price oracle manipulation, liquidation griefing, bad debt socialization |
| **AMM / DEX** | Custom (Uniswap V2/V3 patterns) | Sandwich attacks, price manipulation, donation attacks |
| **Oracle consumer** | None (integration only) | Stale prices, zero/negative price, L2 sequencer downtime |
| **Proxy / upgradeable** | `UUPSUpgradeable`, `Initializable` | Storage collision, uninitialized implementation, `_authorizeUpgrade` missing |
| **Bridge / cross-chain** | Custom | Message replay, double-spend on re-org, incorrect domain separator |
| **Registry / factory** | `Ownable2Step`, `AccessControl` | Frontrunning of registration, unauthorized factory deploys |

Infer the category from the user's description — do not ask "what category is this?". Say "This
looks like an ERC-4626 vault — does that sound right?" then confirm.

The classification step is not optional. Running the wrong checklist on the wrong contract type
produces false confidence.

If the contract falls into a recognized category, read the relevant section of
`brainstorming-questions.md` before proceeding to Phase 2.

### Phase 2: Mandatory Design Questions

Ask these questions conversationally, grouped by concern area. Do not dump all questions at
once. Every item must be resolved before the design doc is written.

#### 2.1 Contract Purpose and Scope

- What is the single sentence that describes what this contract does?
- What does it NOT do? (Explicit out-of-scope prevents feature creep and security mistakes)
- What is the deployment target network(s)? (L1 Ethereum, Arbitrum, Base, Polygon, etc.)
- Will this contract be deployed to multiple chains? (Same address via CREATE2? Different configs?)
- What is the expected lifetime? (Temporary/testnet vs production vs long-running)

#### 2.2 Token Interactions

- What tokens does this contract accept or transfer?
- Are any of them fee-on-transfer tokens (received amount ≠ sent amount)?
  - If yes: use `safeTransfer` and measure balance delta, not the `amount` param
- Are any of them rebasing tokens (balances change without transfer events)?
  - If yes: never store balances internally, store shares instead
- Are any of them tokens with blocklists (USDC, USDT)?
  - If yes: users can be bricked; document as known limitation; consider recovery functions
- Are any of them tokens with non-standard return values (USDT returns void on transfer)?
  - If yes: mandatory `SafeERC20` usage everywhere
- Are any of them ERC-777 tokens (have `tokensReceived` hooks that allow reentrancy)?
  - If yes: non-reentrancy guard mandatory; consider blocking ERC-777 explicitly

#### 2.3 Actors and Permissions

Enumerate every role:
- **Owner/Admin:** what can they do? (set fees, pause, upgrade, configure)
- **Operators/Keepers:** what can they do? (liquidate, rebalance, harvest)
- **Users:** what can they do? (deposit, withdraw, vote, stake)
- **Guardian/Emergency:** who can pause? (should require fewer signers than unpause)
- **Protocol fee recipient:** separate address for fee collection?

For each role, specify:
- Is it a single address, a multisig, or a governance contract?
- Does it have a timelock? (All privileged functions that can drain or brick the contract should)
- Can the role be transferred? How? (`Ownable2Step` two-step is mandatory for admin roles)
- Can the role be renounced? What happens if it is?

**Access control pattern selection:**
- Single admin: use `Ownable2Step` (never `Ownable` — single-step transfer = one typo loses admin)
- Two or more distinct roles: use `AccessControl` with explicit bytes32 role constants
- Governance-controlled: use `TimelockController` as the admin, not an EOA

#### 2.4 State Transitions

For every piece of mutable state:
- What initial value does it have?
- What function(s) can change it?
- Who is authorized to change it?
- What are the preconditions (validations before the change)?
- What events does the change emit?
- Can the change be reversed? If yes, how?

If the contract has a lifecycle with distinct phases (e.g., Funding → Active → Closed → Distributing),
draw the state machine:
```
[State A] --triggerFunction()--> [State B] --anotherFunction()--> [State C]
```
Every valid transition must be explicit. Every invalid transition is a bug.

#### 2.5 External Dependencies

For every external contract call (protocol integrations, token interactions, oracles):

| Dependency | Address source | Audited? | What if it reverts? | What if it returns garbage? |
|---|---|---|---|---|
| Chainlink price feed | Configurable | Yes | No price, should revert | Negative/zero check required |
| USDC token | Hardcoded | Yes | Transaction reverts normally | N/A (audited standard) |
| Uniswap V3 pool | Configurable | Yes | Route failed, needs fallback | Slippage check required |

Red flags that must be explicitly resolved:
- Configurable external addresses: who can change them? With what delay?
- Non-audited integrations: are they required or optional? Can they be disabled?
- Oracles: staleness threshold, fallback behavior, circuit breaker

#### 2.6 Invariants

Invariants are statements that MUST always be true, regardless of any sequence of transactions.
Write them as Solidity-style assertions — they will be copied directly into invariant test files:

```
// invariant: vault.totalAssets() <= token.balanceOf(address(vault))
// invariant: totalSupply() == ghost_totalDeposited - ghost_totalWithdrawn
```

Prompt the user with these categories:

**Accounting invariants** (asset conservation):
- Example: `totalSupply() == sum of all balances[address]`
- Example: `token.balanceOf(vault) >= totalAssets()`

**Authorization invariants** (access control):
- Example: `only ADMIN_ROLE can call setFee()`
- Example: `paused == true → no deposit or withdraw succeeds`

**Monotonicity invariants** (one-way counters):
- Example: `totalDeposited is non-decreasing`
- Example: `nonces[user] is strictly increasing`

**Safety invariants** (value bounds):
- Example: `fee <= MAX_FEE (1000 bps) at all times`
- Example: `shares > 0 iff user deposited > 0`

At least 3 invariants must be documented before the design doc is written.

#### 2.7 Upgrade Requirements

- Does this contract need to be upgradeable?
  - If NO: mark it explicitly and explain why immutability is the right choice here
  - If YES: answer the following:
    - Who can trigger an upgrade? (Must have access control + timelock)
    - What proxy pattern? (UUPS default; Transparent for strict admin/user separation; Beacon for factory)
    - What is the upgrade delay? (Even 24 hours prevents flash-upgrade attacks)

**UUPS pattern (default choice):**
- `import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";`
- Override `_authorizeUpgrade` with access control (this function is the entire security of UUPS)
- `_disableInitializers()` in the implementation constructor (prevents direct initialization of impl)
- `initialize()` replaces `constructor()`, has `initializer` modifier
- `__gap` storage reservation required in every upgradeable base contract

**Transparent pattern (when UUPS is wrong):**
- Use when the admin must never accidentally call user functions
- ProxyAdmin contract is the admin; cannot interact with the implementation

**Beacon pattern (when many proxies need the same upgrade):**
- Factory pattern: many identical contracts sharing one implementation
- Single point of failure: a bad upgrade breaks all proxies at once

#### 2.8 Economic Attack Surfaces

Explicitly think through these attack vectors before finalizing the design:

**Front-running:**
- Can a watcher see a pending transaction and submit one before it to profit?
- Mitigations: commit-reveal, deadline parameter, slippage tolerance, private mempool

**Sandwich attacks:**
- Can an attacker wrap a user transaction with a buy-before/sell-after?
- Mitigations: minimum output parameter, TWAP prices, price impact limits

**Flash loan attacks:**
- Can any operation be atomically reversed in one transaction using borrowed funds?
- Mitigations: snapshot block delays, multi-block TWAP, reentrancy guards, per-block limits

**Oracle manipulation:**
- Can the price source be moved within a single block to trigger liquidations or inflate positions?
- Mitigations: Chainlink TWAP/circuit breakers, price deviation limits, multi-oracle consensus

**MEV / value extraction:**
- Does transaction ordering create value extraction opportunities for validators/searchers?

#### 2.9 Propose 2-3 Architectural Approaches

After gathering all the above, propose 2 to 3 distinct architectural approaches:

```
Approach A: [name]
- Description: [1-2 sentences]
- Gas profile: [high/medium/low]
- Complexity: [simple/moderate/complex]
- Upgrade flexibility: [locked-in/partially-flexible/fully-upgradeable]
- Composability: [easy to integrate / requires adapter / monolithic]
- Key risk: [the one thing that could go wrong with this approach]

Approach B: [name]
...
```

Recommend one approach and explain why.

### Phase 3: User Approval (Mandatory)

Present the chosen design. Wait for EXPLICIT approval. Do not interpret silence as consent.
Do not infer approval from enthusiasm ("that sounds great!"). The user must say yes, approve,
looks good, proceed, or equivalent.

If the user says "just start writing code" or "skip the plan", invoke the blocked rationalization:
the plan gate exists because design failures are the most expensive bugs in Solidity. Offer to
make the planning fast — not to skip it.

## Solidity-Specific Guidelines

### Interface File Standard

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title I<ContractName> — <one-line description>
/// @notice <What this contract does in plain English>
/// @dev <Implementation notes: which patterns it uses, what inherits it>
interface I<ContractName> {

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when <event description>
    /// @param <param> <description, units, indexed reason>
    event <EventName>(<indexed params>);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice Thrown when <condition>
    /// @param <param> <what it tells the caller>
    error <ErrorName>(<typed params>);

    // =========================================================================
    // External functions
    // =========================================================================

    /// @notice <What this does>
    /// @dev <CEI note, access control, state changes>
    /// @param <param> <description, constraints, units>
    /// @return <return> <description>
    function <functionName>(<params>) external returns (<return>);
}
```

The interface is the specification. Every function the implementation will expose must appear here
with full NatSpec. Implementation without a committed interface is guessing.

### Design Document Required Sections

File path: `docs/designs/YYYY-MM-DD-<contract-name>-design.md`

All sections must be present:
1. **Contract name and category** — one-liner description and classification
2. **Actors and roles** — full role table with permissions and address types
3. **State machine** — diagram or table of states and valid transitions
4. **Invariants** — numbered list, minimum 3, written as Solidity-style assertions
5. **Trust assumptions** — what is trusted vs adversarial
6. **External dependencies** — full dependency table
7. **Chosen architecture** — selected approach with rationale
8. **Deferred decisions** — anything explicitly out of scope for V1

## Output Artifacts

- `docs/designs/YYYY-MM-DD-<contract-name>-design.md`
- `src/interfaces/I<ContractName>.sol`

After writing both artifacts, commit before any implementation:
```bash
git add docs/designs/ src/interfaces/
git commit -m "design: add <ContractName> design doc and interface"
```

## Terminal State

The only valid exit from `solidity-planner` is:
1. Design doc written and committed
2. Interface written and committed
3. User has explicitly approved the design
4. Next skill: `solidity-builder`

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The contract is simple, I don't need to design it" | The Parity multisig was "simple." The Re-entrancy bug in The DAO was "simple." Design finds the gaps that seem obvious afterward. |
| "I'll define interfaces later" | Interfaces are the specification. Implementation without them is guessing at behavior, not implementing it. |
| "I know what I'm building" | Write it down. If you know it, it takes 10 minutes. If it takes longer, you found something you didn't know. |
| "Access control is obvious" | Access control is the #1 vulnerability class in DeFi by dollar value. It's architecture, not a detail. |
| "The user said just write the code" | Explain the plan gate and offer to make planning fast — not to skip it. A 15-minute design session is cheaper than a $5M exploit. |
| "We're iterating fast, we'll add design docs later" | 'Later' means never. The design doc is the cheapest artifact in the entire project. Write it first. |
| "It's a clone of an existing protocol" | Clones inherit vulnerabilities and add new ones from customization. Still needs design. |
