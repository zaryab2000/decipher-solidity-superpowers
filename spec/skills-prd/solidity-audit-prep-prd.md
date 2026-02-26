# Skill PRD: `solidity-audit-prep`

**Output file:** `skills/solidity-audit-prep/SKILL.md`
**Supporting file:** `skills/solidity-audit-prep/audit-scope-template.md`

**When:** Code is feature-complete, all internal review findings are resolved, and the team is
preparing to engage external auditors. Also when the user says "prepare for audit", "audit
package", "scope document", "I'm getting the code audited", or "what do I need for an audit."

---

## Why This Skill Exists

External security audits are expensive ($30K–$500K+ depending on scope and firm). Auditors
bill by the day. Every hour an auditor spends understanding what the code is supposed to do
is an hour not spent finding what it's doing wrong.

Well-prepared audit packages cut scope definition time, eliminate confusion about trust
assumptions, and give auditors the context they need to find subtle economic attack vectors —
which are the most dangerous bugs and the hardest to find without domain knowledge.

Unprepared audit packages result in: auditors finding obvious issues that internal review
should have caught, time spent reading scattered code without documentation, missed attack
vectors because the threat model was never written, and re-audits because the scope wasn't clear.

This skill ensures the audit package gives auditors exactly what they need to do their best work.

---

## SKILL.md Frontmatter (Required)

```yaml
---
name: solidity-audit-prep
description: >
  Audit preparation gate for Solidity contracts before external security review. Use when
  preparing for external audit engagement, when creating audit scope documentation, or when
  the user says "prepare for audit", "audit package", "scope document", "what do auditors need",
  "I'm getting this audited", or "external security review". Enforces: complete audit package
  (scope, protocol overview, threat model, internal findings log, and coverage report) before
  engaging auditors. Produces professional-grade documentation that maximizes audit value and
  minimizes wasted auditor time on obvious issues.
compatibility: Claude Code with Foundry-based Solidity projects (Solidity ^0.8.20, forge)
metadata:
  author: Zaryab
  version: "1.0"
---
```

---

## The Strict Rule

```
NO EXTERNAL AUDIT ENGAGEMENT WITHOUT A COMPLETE AUDIT PACKAGE (5 DOCUMENTS + COVERAGE REPORT)
```

---

## Hard Gate

The audit package must exist before contacting auditors. Incomplete packages get returned.
Required documents:
1. `docs/audit/scope.md` — exact commit hash, in/out-of-scope files, dependencies
2. `docs/audit/protocol.md` — protocol overview, actors, state machine, invariants
3. `docs/audit/threat-model.md` — attacker goals, capabilities, specific attack vectors of concern
4. `docs/audit/findings-log.md` — all internal findings with resolutions and regression test names
5. Coverage report — `forge coverage` with justification for every uncovered line

---

## Document 1: Scope Document (`docs/audit/scope.md`)

The scope document is the contract between the dev team and the auditors. Auditors quote time
and cost based on scope. Scope changes mid-audit add cost and delay.

### Required Sections

**1.1 Commit Hash (Exact)**

```markdown
# Audit Scope

## Commit
Repository: https://github.com/<org>/<repo>
Commit hash: `abc123def456789...` (exact 40-char hash)
Branch: main
Tag (if any): v1.0.0-audit
```

This must be the EXACT commit that auditors review. Not "the main branch at the time of audit."
Pin it.

**1.2 In-Scope Files**

```markdown
## In-Scope Files
| File | Lines of Code | Description |
|------|---------------|-------------|
| src/Vault.sol | 287 | Core ERC-4626 vault implementation |
| src/VaultFactory.sol | 95 | Factory for deploying new vaults |
| src/interfaces/IVault.sol | 64 | Vault interface and events |
| src/libraries/ShareMath.sol | 42 | Share calculation library |

Total in-scope LOC: 488
```

Count lines with `cloc src/ --include-lang=Solidity` or similar.

**1.3 Out-of-Scope Files**

```markdown
## Out-of-Scope Files
| File/Directory | Reason |
|----------------|--------|
| src/mocks/ | Test-only, not deployed |
| lib/ | Third-party dependencies, separately audited |
| test/ | Test code, not deployed |
| script/ | Deployment scripts, not deployed |
| src/legacy/ | Deprecated, not deployed in this version |
```

Be explicit. Auditors may flag issues in out-of-scope files anyway (as informational) —
but they won't block on them.

**1.4 Dependencies**

```markdown
## Dependencies
| Dependency | Version | Audit Status | Where Used |
|------------|---------|--------------|------------|
| OpenZeppelin Contracts | 5.0.2 | Audited by multiple firms | All contracts |
| Chainlink Data Feeds | v0.8 | Audited | src/Vault.sol (oracle) |
| Uniswap V3 Core | 1.0.0 | Audited | src/Vault.sol (price TWAP) |
```

Unaudited dependencies are high-priority audit targets. Highlight them.

---

## Document 2: Protocol Overview (`docs/audit/protocol.md`)

This document gives auditors the context they need before reading a line of code.

### Required Sections

**2.1 What It Does**

Plain English. No jargon. Write it for someone smart who has never heard of your protocol:

```markdown
## What It Does

The Vault is an ERC-4626 yield-bearing vault that:
1. Accepts deposits of USDC from users
2. Deploys the deposited USDC to a lending strategy (Aave v3)
3. Accrues yield continuously from Aave interest
4. Allows users to withdraw their proportional share of assets plus yield at any time
5. Charges a 1% fee on withdrawals, sent to the protocol treasury

The vault represents user ownership via ERC-20 shares (vUSDC). One vUSDC share is always
redeemable for assets + accumulated yield, denominated in USDC.
```

**2.2 Actors and Their Permissions**

```markdown
## Actors

| Role | Who | Permissions | Address Type |
|------|-----|-------------|--------------|
| Owner | Protocol multisig | Set fees, pause, unpause, upgrade, set oracle | 3-of-5 Gnosis Safe |
| User | Any EOA or contract | Deposit, withdraw, transfer shares | Any address |
| Keeper | Protocol bot | Harvest yield from strategy (no fund access) | EOA controlled by team |
| Liquidator | Anyone | Trigger liquidations when position is unhealthy | Any address |

Note: There is no admin role that can confiscate user funds. Ownership only controls
protocol configuration parameters.
```

**2.3 State Machine**

```markdown
## Contract Lifecycle

Deployment → Initialized → Active ←→ Paused → [Deprecated]
                                ↓
                          Strategy migration

### Active State
- Users can deposit and withdraw
- Keeper can harvest yield
- Owner can update fee (max 10%, 24h timelock)

### Paused State
- Users CANNOT deposit
- Users CAN withdraw (pause cannot trap funds)
- Owner can pause (1-of-5 multisig sufficient)
- Owner can unpause (requires full 3-of-5 multisig)

### Deprecated State (irreversible)
- No deposits allowed
- Withdrawals still permitted until all funds are claimed
- Triggered by renouncing ownership after full migration
```

**2.4 Invariants**

List the invariants from the planner phase. These are the auditor's truth table:

```markdown
## Invariants

These must hold true after every transaction under any sequence of operations:

1. **Solvency**: `token.balanceOf(vault) >= vault.totalAssets()`
   - The vault always holds enough tokens to cover all redemptions
   - Violation: vault is insolvent (users cannot withdraw their full share)

2. **Share accounting**: `vault.totalSupply() == Σ vault.balanceOf(user) for all users`
   - Total supply equals sum of all individual balances
   - Violation: shares were created or destroyed without corresponding asset movement

3. **Monotonicity**: `totalAssetsDeposited is non-decreasing (absent strategy loss)`
   - Total deposited amount can only increase
   - Violation: assets disappeared without user withdrawals

4. **Access control**: `only OWNER_ROLE can call setFee(), pause(), upgradeTo()`
   - No unauthorized address can change protocol parameters
   - Violation: unauthorized configuration change

5. **Pause**: `whenPaused → deposit() reverts AND withdraw() succeeds`
   - Pause cannot trap user funds
   - Violation: users cannot exit during pause (regulatory/legal risk)
```

**2.5 Trust Assumptions**

```markdown
## Trust Assumptions

### Trusted
- Owner multisig (3-of-5) is not malicious and key distribution is secure
- Chainlink oracle provides accurate prices within the configured staleness threshold (1 hour)
- OpenZeppelin contracts behave as documented (separately audited)
- Aave v3 strategy does not silently lose or steal principal (separately audited)

### Adversarial (Treated as Untrusted)
- Any user-supplied address (may be a malicious contract)
- Any ERC-20 token the vault hasn't explicitly allowlisted
- Transaction ordering (MEV bots may front-run, sandwich, or back-run)
- Flash loan capital (any amount can be borrowed atomically within one block)

### Known Limitations (By Design, Not Bugs)
- Fee-on-transfer tokens are not supported
- Rebasing tokens are not supported
- Tokens with blocklists may cause individual user issues (USDC blacklist)
- Maximum single deposit: 10M USDC (gas cost constraint for share math)
```

---

## Document 3: Threat Model (`docs/audit/threat-model.md`)

The threat model is the auditor's attack playbook. Write it as if you're trying to break
your own protocol.

### Required Sections

**3.1 Attacker Goals**

```markdown
## Attacker Goals

Rank by potential profit (highest = highest audit priority):

1. **Drain vault funds** — steal all deposited USDC from all users
2. **Inflate own position** — manipulate share price to receive more assets than deposited
3. **Deflate other positions** — reduce the redeemable value of other users' shares
4. **Brick the contract (DoS)** — prevent all users from withdrawing permanently
5. **Extract MEV** — front-run large deposits/withdrawals for risk-free profit
6. **Bypass access control** — gain owner-level permissions without multisig
```

**3.2 Attacker Capabilities**

```markdown
## Attacker Capabilities

An attacker in this threat model can:
- Submit transactions at any time and in any order
- Control transaction ordering (as a validator or via Flashbots)
- Take flash loans of any token in unlimited amounts within one block
- Deploy contracts with arbitrary logic (including malicious receive() / fallback())
- Make multiple calls from the same or different addresses
- Read all on-chain state and pending transactions in the mempool
- Manipulate oracle prices within economic bounds (cost of capital)
- Fake or replay signatures (if nonces are incorrect)

An attacker CANNOT:
- Forge signatures without the private key
- Break EVM cryptographic primitives
- Exceed the block gas limit in a single transaction
- Modify the state of a previous block (assuming >2 confirmations)
```

**3.3 Specific Attack Vectors of Concern**

This is the most valuable section. List every known attack vector that MIGHT apply, even if
you've mitigated it. This tells auditors where to focus:

```markdown
## Specific Attack Vectors of Concern

### HIGH PRIORITY

**V-1: First-Depositor Share Inflation Attack**
- Scenario: First depositor deposits 1 wei of USDC to receive 1 share, then donates
  1M USDC directly to the vault (not through deposit), inflating the share price to 1M USDC/share.
  Next depositor receives 0 shares for any deposit < 1M USDC.
- Mitigation implemented: Virtual shares offset (totalSupply + 1e18, totalAssets + 1e18)
  prevents the manipulation from being economically viable.
- Status: Mitigated. Ask auditors to verify the virtual share math is correct.

**V-2: Flash Loan Price Manipulation**
- Scenario: Attacker takes flash loan, deposits large amount to inflate their share count,
  triggers a privileged operation that uses share count, then withdraws.
- Mitigation implemented: No share-count-dependent logic executes within the same block
  as a deposit. EIP-1559 replay protection in governance operations.
- Status: Partially mitigated. Ask auditors to verify no path exists for same-block manipulation.

### MEDIUM PRIORITY

**V-3: Oracle Staleness Attack**
- Scenario: Chainlink oracle goes offline. Last price was stale by >1 hour.
  Contract continues using stale price to value assets, enabling incorrect liquidations.
- Mitigation implemented: Staleness check in oracle consumer: if (block.timestamp - updatedAt > 1 hours) revert.
- Status: Mitigated.

**V-4: Reentrancy via Malicious Token**
- Scenario: User deposits a malicious ERC-20 token (not USDC, but a fake token with
  reentrancy in transferFrom). Reenters withdraw() before state is updated.
- Mitigation: Only allowlisted tokens are accepted. CEI + nonReentrant on all functions.
- Status: Mitigated by allowlist. Ask auditors to confirm allowlist cannot be bypassed.
```

---

## Document 4: Internal Findings Log (`docs/audit/findings-log.md`)

This document proves to external auditors that internal review was thorough. It is also the
starting point for "known issues" — findings that auditors should not re-report.

```markdown
# Internal Findings Log

This log tracks all issues found and resolved during internal security review.

## Finding Table
| ID | Severity | Title | Status | Regression Test |
|----|----------|-------|--------|-----------------|
| INT-001 | High | Missing CEI in withdraw() — reentrancy possible | Fixed in commit abc123 | test_withdraw_nonReentrant |
| INT-002 | Medium | No staleness check on Chainlink oracle | Fixed in commit def456 | test_getPrice_revertsWhenStale |
| INT-003 | Low | uint256 overflow possible in calculateFee for extreme values | Fixed with SafeMath | testFuzz_calculateFee_noOverflow |
| INT-004 | Informational | withdrawalFeeBps is not bounded by constant MAX_FEE in error message | Fixed | N/A |

## Wontfix / Known Limitations
| ID | Severity | Title | Reason |
|----|----------|-------|--------|
| INT-005 | Low | Fee-on-transfer tokens silently lose value | By design: only allowlisted standard tokens are supported |
```

---

## Coverage Report

Run coverage and annotate every uncovered line:

```bash
# Generate coverage report
forge coverage --report lcov

# Generate HTML report for easy browsing
genhtml lcov.info --branch-coverage --output-dir coverage/
```

**Coverage requirements:**
- All security-critical paths: 100% line and branch coverage
- Happy paths: 100% line coverage
- Error paths: 100% (every revert path has at least one test)
- Uncovered lines: annotate each with the reason in a `coverage-notes.md` file

```markdown
# Coverage Notes

## Uncovered Lines and Justification

| File | Line | Code | Reason |
|------|------|------|--------|
| src/Vault.sol | 247 | `revert UnreachableCode();` | Defensive revert for a state impossible given the function's preconditions. Covered by invariant tests. |
| src/Vault.sol | 312 | `catch {}` | External call to Chainlink; oracle failure path. Covered by mock oracle fork test. |
```

Auditors see every uncovered line. An unexplained uncovered line looks like an untested bug.
Explain all of them.

---

## Pre-Audit Submission Checklist

Before sending the audit package, verify all of these:

```
[ ] Exact commit hash pinned and tagged
[ ] scope.md: all in-scope files listed with LOC count
[ ] scope.md: all out-of-scope files listed with reason
[ ] scope.md: all dependencies listed with versions and audit status
[ ] protocol.md: plain-English protocol description written
[ ] protocol.md: all actors and permissions listed
[ ] protocol.md: state machine documented
[ ] protocol.md: all invariants listed (minimum 3, ideally 5+)
[ ] protocol.md: trust assumptions explicitly written out
[ ] threat-model.md: attacker goals listed and ranked
[ ] threat-model.md: attacker capabilities explicitly bounded
[ ] threat-model.md: specific vectors of concern listed with current mitigation status
[ ] findings-log.md: all internal findings logged with resolution and regression test
[ ] Coverage report generated and all uncovered lines annotated
[ ] forge test passes (zero failures at audit commit)
[ ] slither runs clean (all findings triaged or documented)
[ ] No console.log in src/ (grep -rn "console" src/ returns nothing)
[ ] All NatSpec complete
[ ] README updated with deployment addresses and setup instructions
```

---

## Supporting File: audit-scope-template.md

This file lives at `skills/solidity-audit-prep/audit-scope-template.md`.

Required content:
- Complete templates for all 4 documents (scope, protocol, threat model, findings log)
- Pre-filled placeholder sections with [FILL IN] markers
- LOC counting commands
- Coverage generation commands
- Audit firm-specific formatting guidance (where it differs from the default)
- Timeline guide: when to send what to auditors, how to respond to preliminary findings

---

## Output Artifacts

- `docs/audit/scope.md`
- `docs/audit/protocol.md`
- `docs/audit/threat-model.md`
- `docs/audit/findings-log.md`
- `coverage/` — HTML coverage report
- `coverage/lcov.info` — raw LCOV data
- `coverage/coverage-notes.md` — uncovered line justifications

---

## Terminal State

This is the final skill in the V1 lifecycle. After audit prep is complete:
- Send the package to auditors
- Engage with auditor questions using the documentation as reference
- After audit completion: apply findings, write regression tests, update findings log

---

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The auditors will figure it out" | Auditors bill by the day. Every hour figuring out what your code does is an hour not finding security bugs. Audit prep directly reduces audit cost and improves audit quality. |
| "We'll write the threat model after the audit" | The threat model tells auditors what to look for. Without it, they're guessing at what's in scope and what economic attacks apply. |
| "Coverage doesn't matter if tests pass" | Coverage shows what isn't tested. Untested code is unreviewed behavior. An auditor seeing 60% coverage will spend half their time on the untested 40%. |
| "Our internal review found everything" | Internal review is biased by implementation familiarity. External auditors bring fresh eyes and different mental models. Both are necessary. |
| "The findings log is unnecessary" | The findings log tells auditors which issues are known and resolved. Without it, they'll re-report the same issues, wasting their time and your money. |
| "The code is simple enough to skip scope definition" | Simple scope definitions take 30 minutes. Scope misunderstandings mid-audit cause delays, additional charges, and re-audits. |
