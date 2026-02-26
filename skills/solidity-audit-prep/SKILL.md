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

## When

Code is feature-complete, all internal review findings are resolved, and the team is preparing
to engage external auditors. Also when the user says "prepare for audit", "audit package",
"scope document", "I'm getting the code audited", or "what do I need for an audit."

## The strict rule

```
NO EXTERNAL AUDIT ENGAGEMENT WITHOUT A COMPLETE AUDIT PACKAGE (5 DOCUMENTS + COVERAGE REPORT)
```

## Hard Gate

The audit package must exist before contacting auditors. Incomplete packages get returned.
Required documents:
1. `docs/audit/scope.md` — exact commit hash, in/out-of-scope files, dependencies
2. `docs/audit/protocol.md` — protocol overview, actors, state machine, invariants
3. `docs/audit/threat-model.md` — attacker goals, capabilities, specific attack vectors
4. `docs/audit/findings-log.md` — all internal findings with resolutions and regression tests
5. Coverage report — `forge coverage` with justification for every uncovered line

## Mandatory Checklist

Before sending the audit package, verify all items:

```
[ ] Exact commit hash pinned and tagged (git tag v1.0.0-audit <hash>)
[ ] scope.md: all in-scope files listed with LOC count
[ ] scope.md: all out-of-scope files listed with reason
[ ] scope.md: all dependencies listed with versions and audit status
[ ] protocol.md: plain-English protocol description written
[ ] protocol.md: all actors and permissions listed
[ ] protocol.md: state machine documented
[ ] protocol.md: all invariants listed (minimum 3, ideally 5+)
[ ] protocol.md: trust assumptions explicitly written out
[ ] threat-model.md: attacker goals listed and ranked by priority
[ ] threat-model.md: attacker capabilities explicitly bounded
[ ] threat-model.md: specific vectors of concern listed with current mitigation status
[ ] findings-log.md: all internal findings logged with resolution and regression test
[ ] Coverage report generated and all uncovered lines annotated with justification
[ ] forge test passes with zero failures at the audit commit
[ ] slither runs clean — all findings triaged or documented
[ ] No console.log in src/ (grep -rn "console" src/ must return nothing)
[ ] All NatSpec complete on public/external functions, errors, events
[ ] README updated with deployment addresses and setup instructions
```

## Document 1: Scope (`docs/audit/scope.md`)

The scope document is the contract between the dev team and auditors. Auditors quote time
and cost based on scope. Scope changes mid-audit add cost and delay.

**Required sections:**

**1.1 Commit Hash (Exact)**

```markdown
# Audit Scope

## Commit
Repository: https://github.com/<org>/<repo>
Commit hash: `abc123def456789...` (exact 40-char SHA — not a branch name)
Branch: main
Tag (if any): v1.0.0-audit
```

Pin the exact commit. Not "the main branch at the time of audit." Tag it.

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

Count lines with: `cloc src/ --include-lang=Solidity`

**1.3 Out-of-Scope Files**

```markdown
## Out-of-Scope Files
| File/Directory | Reason |
|----------------|--------|
| src/mocks/ | Test-only, not deployed |
| lib/ | Third-party dependencies, separately audited |
| test/ | Test code, not deployed |
| script/ | Deployment scripts, not deployed |
```

**1.4 Dependencies**

```markdown
## Dependencies
| Dependency | Version | Audit Status | Where Used |
|------------|---------|--------------|------------|
| OpenZeppelin Contracts | 5.0.2 | Audited by multiple firms | All contracts |
| Chainlink Data Feeds | v0.8 | Audited | src/Vault.sol (oracle) |
| Uniswap V3 Core | 1.0.0 | Audited | src/Vault.sol (TWAP) |
```

Unaudited dependencies are high-priority audit targets. Highlight them explicitly.

## Document 2: Protocol Overview (`docs/audit/protocol.md`)

This document gives auditors the context they need before reading a line of code.

**Required sections:**

**2.1 What It Does — plain English, no jargon**

```markdown
## What It Does

The Vault is an ERC-4626 yield-bearing vault that:
1. Accepts deposits of USDC from users
2. Deploys the deposited USDC to a lending strategy (Aave v3)
3. Accrues yield continuously from Aave interest
4. Allows users to withdraw their proportional share of assets plus yield at any time
5. Charges a 1% fee on withdrawals, sent to the protocol treasury
```

**2.2 Actors and Their Permissions**

```markdown
## Actors
| Role | Who | Permissions | Address Type |
|------|-----|-------------|--------------|
| Owner | Protocol multisig | Set fees, pause, unpause, upgrade, set oracle | 3-of-5 Gnosis Safe |
| User | Any EOA or contract | Deposit, withdraw, transfer shares | Any address |
| Keeper | Protocol bot | Harvest yield (no fund access) | EOA controlled by team |
```

**2.3 State Machine**

```markdown
## Contract Lifecycle

Deployment → Initialized → Active ←→ Paused → [Deprecated]

### Active State: users can deposit and withdraw; keeper can harvest yield
### Paused State: deposits blocked; withdrawals allowed (pause cannot trap funds)
### Deprecated State: irreversible; no deposits; withdrawals until all claimed
```

**2.4 Invariants**

List all invariants from the planner phase. These are the auditor's truth table:

```markdown
## Invariants

These must hold after every transaction under any sequence of operations:

1. **Solvency**: token.balanceOf(vault) >= vault.totalAssets()
2. **Share accounting**: vault.totalSupply() == sum of vault.balanceOf(user) for all users
3. **Monotonicity**: totalAssetsDeposited is non-decreasing (absent strategy loss)
4. **Access control**: only OWNER_ROLE can call setFee(), pause(), upgradeTo()
5. **Pause**: whenPaused → deposit() reverts AND withdraw() succeeds
```

**2.5 Trust Assumptions**

```markdown
## Trust Assumptions

### Trusted
- Owner multisig (3-of-5) is not malicious
- Chainlink oracle provides accurate prices within staleness threshold
- OpenZeppelin contracts behave as documented

### Adversarial
- Any user-supplied address (may be a malicious contract)
- Transaction ordering (MEV bots may front-run or sandwich)
- Flash loan capital (any amount can be borrowed atomically)

### Known Limitations (by design, not bugs)
- Fee-on-transfer tokens are not supported
- Rebasing tokens are not supported
- Tokens with blocklists may cause individual user issues
```

## Document 3: Threat Model (`docs/audit/threat-model.md`)

Write it as if you're trying to break your own protocol. This is the auditor's attack playbook.

**Required sections:**

**3.1 Attacker Goals — ranked by potential profit**

```markdown
## Attacker Goals

1. Drain vault funds — steal all deposited assets from all users
2. Inflate own position — manipulate share price to receive more assets than deposited
3. Deflate other positions — reduce redeemable value of other users' shares
4. Brick the contract (DoS) — prevent all users from withdrawing permanently
5. Extract MEV — front-run large deposits/withdrawals for risk-free profit
6. Bypass access control — gain owner-level permissions without multisig
```

**3.2 Attacker Capabilities**

```markdown
## Attacker Capabilities

An attacker CAN:
- Submit transactions at any time and in any order
- Control transaction ordering (as a validator or via Flashbots)
- Take flash loans of any token in unlimited amounts within one block
- Deploy contracts with arbitrary logic (including malicious receive()/fallback())
- Read all on-chain state and pending mempool transactions
- Manipulate oracle prices within economic bounds

An attacker CANNOT:
- Forge signatures without the private key
- Break EVM cryptographic primitives
- Exceed the block gas limit in a single transaction
- Modify the state of a previous block (assuming >2 confirmations)
```

**3.3 Specific Attack Vectors of Concern**

List every known attack vector, even if mitigated. Include mitigation status:

```markdown
## Specific Attack Vectors of Concern

### HIGH PRIORITY

**V-1: First-Depositor Share Inflation Attack**
- Scenario: First depositor deposits 1 wei, donates 1M tokens directly to vault,
  inflating share price. Next depositor receives 0 shares.
- Mitigation: Virtual shares offset (totalSupply + 1e18, totalAssets + 1e18)
- Status: Mitigated. Ask auditors to verify the virtual share math is correct.

**V-2: Flash Loan Price Manipulation**
- Scenario: Attacker uses flash loan to manipulate spot price used in share math.
- Mitigation: No spot price used; share conversion uses vault's own totalAssets.
- Status: Mitigated. Ask auditors to verify no path for same-block manipulation.

### MEDIUM PRIORITY

**V-3: Oracle Staleness**
- Scenario: Chainlink offline; stale price enables incorrect operations.
- Mitigation: Staleness check: if (block.timestamp - updatedAt > 1 hours) revert.
- Status: Mitigated.
```

## Document 4: Internal Findings Log (`docs/audit/findings-log.md`)

Proves to external auditors that internal review was thorough. Also defines known issues.

```markdown
# Internal Findings Log

## Finding Table
| ID | Severity | Title | Status | Regression Test |
|----|----------|-------|--------|-----------------|
| INT-001 | High | Missing CEI in withdraw() — reentrancy possible | Fixed (commit abc123) | test_withdraw_nonReentrant |
| INT-002 | Medium | No staleness check on Chainlink oracle | Fixed (commit def456) | test_getPrice_revertsWhenStale |
| INT-003 | Low | uint256 overflow in calculateFee for extreme values | Fixed with SafeCast | testFuzz_calculateFee_noOverflow |

## Wontfix / Known Limitations
| ID | Severity | Title | Reason |
|----|----------|-------|--------|
| INT-004 | Low | Fee-on-transfer tokens silently lose value | By design: only allowlisted standard tokens accepted |
```

## Coverage Report

```bash
# Generate LCOV coverage data
forge coverage --report lcov

# Generate HTML report for browsing
genhtml lcov.info --branch-coverage --output-dir coverage/
```

Coverage requirements:
- Security-critical paths: 100% line and branch coverage
- Happy paths: 100% line coverage
- Error paths: 100% (every revert path has at least one test)
- Uncovered lines: annotate each in `coverage/coverage-notes.md`

```markdown
# Coverage Notes

## Uncovered Lines and Justification
| File | Line | Code | Reason |
|------|------|------|--------|
| src/Vault.sol | 247 | revert UnreachableCode(); | Defensive revert; state is impossible given function preconditions. Covered by invariant tests. |
| src/Vault.sol | 312 | catch {} | Chainlink failure path. Covered by mock oracle fork test. |
```

Auditors see every uncovered line. An unexplained uncovered line looks like an untested bug.
Explain all of them.

## Forge Commands

```bash
# Tag the audit commit
git tag v1.0.0-audit <commit-hash>
git push origin v1.0.0-audit

# Run full test suite (must pass at zero failures)
forge test

# Generate coverage report
forge coverage --report lcov
genhtml lcov.info --branch-coverage --output-dir coverage/

# Run Slither (must be triaged before audit)
slither . --filter-paths "test,script,lib"

# Count in-scope LOC
cloc src/ --include-lang=Solidity

# Check for console.log (must return nothing)
grep -rn "console" src/

# Generate NatSpec docs
forge doc --out docs/natspec/

# Verify no compile warnings
forge build
```

## Output Artifacts

- `docs/audit/scope.md`
- `docs/audit/protocol.md`
- `docs/audit/threat-model.md`
- `docs/audit/findings-log.md`
- `coverage/` — HTML coverage report
- `coverage/lcov.info` — raw LCOV data
- `coverage/coverage-notes.md` — uncovered line justifications

## Terminal State

This is the final skill in the V1 lifecycle. After audit prep is complete:
- Send the package to auditors
- Engage with auditor questions using the documentation as reference
- After audit completion: apply findings, write regression tests, update findings log

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "The auditors will figure it out" | Auditors bill by the day. Every hour figuring out what your code does is an hour not finding security bugs. Audit prep directly reduces audit cost and improves audit quality. |
| "We'll write the threat model after the audit" | The threat model tells auditors what to look for. Without it, they're guessing at what's in scope and what economic attacks apply. |
| "Coverage doesn't matter if tests pass" | Coverage shows what isn't tested. Untested code is unreviewed behavior. An auditor seeing 60% coverage will spend half their time on the untested 40%. |
| "Our internal review found everything" | Internal review is biased by implementation familiarity. External auditors bring fresh eyes and different mental models. Both are necessary. |
| "The findings log is unnecessary" | The findings log tells auditors which issues are known and resolved. Without it, they'll re-report the same issues, wasting their time and your money. |
| "The code is simple enough to skip scope definition" | Simple scope definitions take 30 minutes. Scope misunderstandings mid-audit cause delays, additional charges, and re-audits. |
