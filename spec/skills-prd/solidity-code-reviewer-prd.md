# Skill PRD: `solidity-code-reviewer`

**Output file:** `skills/solidity-code-reviewer/SKILL.md`
**Supporting file:** `skills/solidity-code-reviewer/security-checklist.md`

**When:** After completing any contract implementation, before marking work as done. Also when
the user says "review this", "is this secure?", "check for vulnerabilities", "security review",
or "audit this contract." Dispatches the `reviewoor` agent.

---

## Why This Skill Exists

Developers cannot fully audit their own code. Familiarity creates blind spots. The patterns that
feel correct because you wrote them are exactly the ones that harbor subtle bugs.

More importantly: security review is a different cognitive mode than implementation. Implementation
thinks "does this do what I want?" Security review thinks "how can this be made to do what I
don't want?" A developer alternating between these modes catches far fewer issues than a dedicated
security review pass.

This skill forces a clean break: implementation is done, the tool goes to a specialist
(the reviewoor agent) for a structured security review. All Critical and High findings must be
resolved before the work is considered complete.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-code-reviewer
description: >
  Security review gate for completed Solidity contract implementations. Use after any contract
  implementation is complete and before marking work done, merging, or deploying. Triggers on:
  "review this contract", "security review", "is this secure?", "check for vulnerabilities",
  "audit this", "pen test this", or when any contract implementation is complete. Dispatches
  the reviewoor agent with full context: source code, interface, design doc, invariant list, and
  git diff if modifying an existing contract. All Critical and High severity findings must be
  resolved with regression tests before exiting this skill.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO CONTRACT IS COMPLETE WITHOUT A REVIEWOOR SECURITY REVIEW WITH ALL CRITICAL AND HIGH FINDINGS RESOLVED
```

---

## Hard Gate

This skill dispatches the `reviewoor` agent with the necessary context (see below). After the
review, all Critical and High findings must be:
1. Fixed in the code
2. Accompanied by a regression test that proves the fix
3. Re-reviewed by running the reviewoor agent again on the changed code

Medium findings must be documented in the audit prep findings log. Low/Informational must be
logged. Nothing is ignored.

---

## What to Provide to the Reviewoor Agent

The SKILL.md must include explicit dispatch instructions. When invoking the reviewoor agent,
provide ALL of these:

1. **Full source code** of every contract file in scope
2. **The interface file** (`src/interfaces/I<ContractName>.sol`) — deviations from interface spec are bugs
3. **The design document** from `docs/designs/` — deviations from design intent are bugs
4. **The invariant list** from the planner phase — if invariants aren't enforced, report them
5. **The git diff** if this is modifying an existing contract — new code introduces new risks to existing state
6. **Slither output** — run `slither . --filter-paths "test,script,lib"` and include the full output
7. **Test coverage** — which paths are untested? Untested paths are unreviewed behavior.

If any of these are missing, generate them before dispatching. A review without context is
a superficial scan, not a security review.

---

## Security Review Checklist (Summary)

The SKILL.md carries the summary checklist. The `security-checklist.md` supporting file has
the full version with code examples, proof of concept exploits, and mitigation patterns.

### Domain 1: Reentrancy (Most Common Critical Vulnerability)

```
[ ] All state changes occur BEFORE any external calls (CEI pattern)?
    → Check every function: state updates in EFFECTS, external calls in INTERACTIONS
[ ] ReentrancyGuard applied to functions that change state and make external calls?
    → As defense-in-depth even when CEI is followed
[ ] Cross-function reentrancy: can A call external contract which re-enters B?
    → Common pattern: withdraw() calls external; attacker's fallback calls deposit()
    → Fix: shared reentrancy lock across both A and B, OR separate their locked state
[ ] Cross-contract reentrancy: can A call B which re-enters A?
    → Less common but catastrophic. Audit every external call target
[ ] Read-only reentrancy: can a view function return stale data during reentrancy?
    → Price feeds and oracle views are most vulnerable
    → Fix: use transient storage or reentrancy locks on reads too (advanced)
```

### Domain 2: Access Control (Highest Loss Vulnerability Class)

```
[ ] Every privileged function has an explicit access modifier or early revert?
    → Access check must be FIRST in the function (fail fast, save gas)
[ ] Ownable2Step used, not Ownable?
    → Single-step ownership transfer: one typo or wrong address loses ownership forever
    → Ownable2Step requires the new owner to explicitly accept — prevents accidents
[ ] No tx.origin for authorization?
    → tx.origin is the original EOA, not the immediate caller
    → Contracts calling your contract appear as trusted users — phishable
[ ] Role renouncement is explicit and protected?
    → Renouncing the last admin role permanently bricks the contract
    → Add a check: cannot renounce if you're the last holder of a critical role
[ ] Timelock on sensitive privileged operations?
    → setFee(), setOracle(), upgradeTo() should have a delay for user reaction
[ ] Two-factor upgrade authorization for UUPS contracts?
    → _authorizeUpgrade must have non-trivial access control
    → Empty _authorizeUpgrade = anyone can upgrade = total compromise
```

### Domain 3: Integer Arithmetic

```
[ ] No precision loss from (a / b) * c pattern?
    → Division truncates. Always: (a * c) / b (multiply before dividing)
    → Example: (principal / totalShares) * newRate loses precision for small deposits
[ ] All unchecked blocks have a comment proving bounds?
    → "Safe: x was already checked < y above" must be present
    → Unchecked without proof is a bug waiting to trigger
[ ] Downcast safety verified?
    → uint256 → uint128: check the value fits before casting
    → Silent truncation: uint256(type(uint128).max + 1) == 0 after uint128 cast
    → Fix: use OpenZeppelin's SafeCast or explicit range checks
[ ] ERC-4626 rounding direction correct?
    → Deposits (previewDeposit, convertToShares): round DOWN (user gets fewer shares)
    → Withdrawals (previewWithdraw, convertToAssets): round UP (vault keeps more)
    → Wrong rounding direction enables dust theft over many transactions
[ ] No share price manipulation through donation?
    → First depositor attack: deposit 1 wei, donate large amount, inflate share price
    → Fix: use virtual shares (e.g., totalSupply + 1e18 offset) or minimum deposit
```

### Domain 4: External Calls

```
[ ] Return values of .call(), .delegatecall(), .staticcall() checked?
    → Low-level calls return (bool success, bytes memory data)
    → Ignoring success means failed calls are silently accepted
[ ] SafeERC20 used for all token transfers?
    → USDT transfer() returns void — raw transferFrom reverts on USDT
    → Non-standard tokens silently fail without SafeERC20
[ ] Non-standard ERC-20 behaviors handled?
    → Fee-on-transfer: measure balance delta, not the amount parameter
    → Rebasing: store shares, not amounts
    → Return false instead of revert: SafeERC20 handles this
[ ] User-supplied addresses treated as adversarial?
    → Any external contract can have malicious receive()/fallback()
    → Calls to user-provided addresses can re-enter or fail strategically
[ ] Pull payment pattern over push where possible?
    → Sending ETH in a loop: one recipient's failure blocks everyone else
    → Better: accumulators + claimable withdrawals (pull pattern)
```

### Domain 5: Oracle Security

```
[ ] No spot price from a single DEX source?
    → Uniswap spot price is manipulable within one block via flash loans
    → Use Uniswap TWAP (minimum 1 block, ideally 30+ minutes) or Chainlink
[ ] Chainlink staleness check present?
    → (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();
    → if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert StalePrice();
[ ] Chainlink negative/zero price check present?
    → if (price <= 0) revert InvalidPrice(price);
    → Negative prices indicate oracle circuit breaker activation
[ ] L2 sequencer uptime check present (for Arbitrum, Optimism, Base)?
    → On L2, the sequencer can go down; Chainlink still serves last-known price
    → Use sequencerUptimeFeed and add grace period after sequencer restart
[ ] Price decimal normalization correct?
    → Chainlink ETH/USD: 8 decimals. Most tokens: 18 decimals. Check each feed.
    → Decimal mismatch: price appears 10^10 times too large or too small
```

### Domain 6: Flash Loan and MEV Vectors

```
[ ] Atomically reversible operations analyzed for flash loan exploits?
    → If an operation can be: borrow → exploit → repay in one tx, it's vulnerable
    → Common targets: governance with current-block snapshot, price-sensitive logic
[ ] Significant privileged operations have a timelock?
    → Front-running oracle updates, governance proposals, fee changes
    → Timelock gives users time to react to adverse changes
[ ] Sandwich attack on price-sensitive operations mitigated?
    → Require minimum output (slippage tolerance) on any swap or price-sensitive tx
    → Or use a private RPC (Flashbots) to avoid the public mempool
```

### Domain 7: Upgrade Security (If Applicable)

```
[ ] Storage layout diff verified via forge inspect --pretty?
    → No existing slot changed position, removed, or retyped
[ ] _disableInitializers() in implementation constructor?
    → Without this, anyone can initialize the implementation contract directly
    → Initialized implementation can be used as a malicious upgrade target
[ ] Initializer() protected by initializer modifier and not re-runnable?
    → Can the initialize function be called twice? (Should revert on second call)
[ ] _authorizeUpgrade has correct access control?
    → Empty override = anyone can upgrade = total protocol compromise
[ ] upgradeToAndCall used (not upgradeTo + separate initialize)?
    → Separation creates a window between upgrade and initialization
```

### Domain 8: Denial of Service

```
[ ] No unbounded loops over user-controlled storage?
    → for (uint i; i < users.length; ++i) where users grows unboundedly = DoS
    → Fix: pagination, or accumulator patterns instead of enumeration
[ ] No operations that can be made to fail by a single bad actor?
    → Push pattern with external calls: one failing recipient blocks all others
    → Fix: pull payment pattern; wrap external calls in try/catch
[ ] No grieving via small/dust deposits?
    → Many small deposits can fill the contract's user list, making loops expensive
    → Fix: minimum deposit thresholds
[ ] Governance proposals cannot be bricked by spam?
    → Proposal spam with low threshold fills the proposal queue
    → Fix: proposal threshold, proposal cooldown per address
```

### Domain 9: Signature Replay and EIP-712

```
[ ] Nonces used for all signature-based authorization?
    → Without nonces, a signed message can be replayed indefinitely
[ ] Domain separator includes chainId?
    → Without chainId, signatures from testnet work on mainnet (replay across chains)
[ ] Deadline parameter on all signed messages?
    → Without deadline, signed permissions are valid forever
[ ] permit() signature validation correct?
    → Incorrect ECDSA recovery produces wrong signer address (no revert, just wrong auth)
```

---

## How to Act on Findings by Severity

| Severity | Definition | Action | Blocker? |
|---|---|---|---|
| **Critical** | Direct loss of funds, unauthorized access to privileged functions, permanent DoS | Fix immediately. Write regression test proving the fix. Run reviewoor again on the fix. | Yes — blocks everything |
| **High** | Indirect loss of funds, significant security degradation, breaks core invariant | Fix before any merge or deployment. Write regression test. | Yes — blocks merge and deploy |
| **Medium** | Partial loss, economically suboptimal, correct but dangerous pattern | Fix before deployment. Document in audit prep findings log with resolution. | Blocks deploy, not merge |
| **Low** | Informational, gas inefficiency, code quality, deviation from best practice | Log in audit prep findings doc. Address before external audit. | Not a blocker |
| **Informational** | Style, documentation, unclear naming | Log. Fix if time permits. | Not a blocker |

---

## Supporting File: security-checklist.md

This file lives at `skills/solidity-code-reviewer/security-checklist.md`.

### Required Content

The file must contain, for each domain:

1. **The vulnerability** — what it is and why it matters
2. **Proof of concept** — a minimal Solidity example showing the exploit pattern
3. **Detection** — how to find it in code review (what to grep for, what patterns to look for)
4. **Mitigation** — the fix with code example
5. **Test** — the test that verifies the fix

Domains required in the file:
- Reentrancy (single, cross-function, cross-contract, read-only)
- Access control (all patterns)
- Integer arithmetic (precision, casting, rounding)
- External calls (return values, non-standard tokens, push vs pull)
- Oracle manipulation (all oracle types)
- Flash loan attacks (governance, price manipulation)
- MEV (sandwich, frontrunning, backrunning)
- Upgrade security (all proxy patterns)
- Signature security (replay, nonce, domain separator)
- DoS (loops, griefing, gas limits)
- ERC-4626 specific (first depositor, rounding direction, donation)

---

## Output Artifacts

The reviewoor agent produces a security review report (format defined in `agents/reviewoor.md`).

Minimum report requirements:
- Findings table with: ID, title, severity, file:line, description, recommended fix
- For each Critical/High: proof of concept attack scenario
- For each Critical/High: regression test that the fix must pass
- Overall risk rating
- Coverage of the 9 security domains

The report is saved to `docs/reviews/YYYY-MM-DD-<ContractName>-security.md`.

Critical and High findings must be resolved and regression tests written before exiting this skill.

---

## Terminal State

After all Critical and High findings are resolved:
- Exit to `solidity-gas-optimizer` (if gas review pending)
- Exit to `solidity-deployer` (if ready to deploy)
- Exit to `solidity-audit-prep` (if preparing for external audit)

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The code is obviously correct" | The reviewoor finds things that "obviously correct" code misses. That's the point. |
| "I already reviewed it myself" | Self-review and agent review are not the same thing. One is implementation thinking; the other is security thinking. Both are required. |
| "The tests pass, so it's secure" | Tests verify known behavior. The reviewoor checks for unknown attack vectors. Passing tests and being secure are independent properties. |
| "It's a small contract" | Small contracts have small but critical attack surfaces. The Parity multisig was small. The Re-entrancy bug in The DAO was in a small function. |
| "We'll do a real audit later" | Internal review finds the obvious issues. External audit finds the subtle ones. Neither replaces the other, and both require this skill to pass. |
