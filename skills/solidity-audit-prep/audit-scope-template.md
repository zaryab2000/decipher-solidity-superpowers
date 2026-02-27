# Audit Package Templates

Complete fill-in templates for all four required audit documents. Replace every `[FILL IN]`
marker with actual content. Do not leave any marker blank — if you don't know the answer,
find out before sending the package.

---

## Template: `docs/audit/scope.md`

```markdown
# Audit Scope

## Commit
Repository: [FILL IN: https://github.com/<org>/<repo>]
Commit hash: [FILL IN: exact 40-character SHA — run `git rev-parse HEAD`]
Branch: [FILL IN: main / develop]
Tag: [FILL IN: v1.0.0-audit, or "none" if not tagged]

To verify you are reviewing the exact commit:
git checkout [FILL IN: commit-hash]
git log --oneline -1  # should show: <hash> <commit message>

---

## In-Scope Files
| File | Lines of Code | Description |
|------|---------------|-------------|
| [FILL IN: src/Contract.sol] | [FILL IN: LOC] | [FILL IN: one-line description] |
| [FILL IN: src/Contract2.sol] | [FILL IN: LOC] | [FILL IN: one-line description] |
| [FILL IN: src/interfaces/IContract.sol] | [FILL IN: LOC] | [FILL IN: description] |
| [FILL IN: src/libraries/LibName.sol] | [FILL IN: LOC] | [FILL IN: description] |

Total in-scope LOC: [FILL IN: sum of all LOC above]

Run this to count LOC: cloc src/ --include-lang=Solidity

---

## Out-of-Scope Files
| File/Directory | Reason |
|----------------|--------|
| src/mocks/ | Test-only contracts, not deployed |
| lib/ | Third-party dependencies (separately audited — see Dependencies section) |
| test/ | Test code, not deployed to production |
| script/ | Deployment scripts, not deployed as contracts |
| [FILL IN: any other directories] | [FILL IN: reason] |

---

## Dependencies
| Dependency | Version | Audit Status | Where Used |
|------------|---------|--------------|------------|
| OpenZeppelin Contracts | [FILL IN: e.g., 5.0.2] | Audited — see https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/audits | [FILL IN: which contracts] |
| [FILL IN: other dependency] | [FILL IN: version] | [FILL IN: Audited by <firm> / Unaudited — HIGH PRIORITY REVIEW TARGET] | [FILL IN: which contracts] |

Note: Unaudited dependencies are flagged as high-priority review targets.

---

## Known Issues (Wontfix)
These issues are known and accepted by design. Auditors should not re-report them:
| Issue | Reason |
|-------|--------|
| [FILL IN: issue description] | [FILL IN: why it is accepted by design] |

If there are no known wontfix issues, write: "None. All known issues have been resolved."
```

---

## Template: `docs/audit/protocol.md`

```markdown
# Protocol Overview

## What It Does

[FILL IN: Plain English description of what the protocol does. No jargon. Write for a smart
person who has never heard of your project. Include:]
[FILL IN: 1. What assets are accepted]
[FILL IN: 2. What happens to those assets]
[FILL IN: 3. How users benefit]
[FILL IN: 4. How the protocol earns revenue]
[FILL IN: 5. Any other key behaviors]

---

## Actors and Permissions
| Role | Who | Permissions | Address Type |
|------|-----|-------------|--------------|
| [FILL IN: Owner] | [FILL IN: Protocol multisig / DAO] | [FILL IN: list all privileged functions] | [FILL IN: 3-of-5 Gnosis Safe / EOA / DAO] |
| [FILL IN: User] | [FILL IN: Any EOA or contract] | [FILL IN: list user-callable functions] | [FILL IN: Any address] |
| [FILL IN: Role name] | [FILL IN: who holds this role] | [FILL IN: permissions] | [FILL IN: address type] |

Note: [FILL IN: describe any permissions that may surprise auditors — e.g., "Owner cannot
confiscate user funds" or "Anyone can trigger liquidations"]

---

## Contract Lifecycle / State Machine

[FILL IN: Describe the states the contract can be in and how it transitions between them]

[FILL IN: Example:]
Deployment → Initialized → Active ←→ Paused → [Deprecated]

### [FILL IN: State 1: e.g., Active]
[FILL IN: What can happen in this state. Who can act. What is blocked.]

### [FILL IN: State 2: e.g., Paused]
[FILL IN: What can happen. Critically: can users still withdraw? (should be yes)]

### [FILL IN: State 3: e.g., Deprecated — if applicable]
[FILL IN: How the contract reaches this state. Is it reversible?]

---

## Invariants

These must hold true after every transaction under any sequence of operations by any actor:

[FILL IN: List at least 3, ideally 5+ invariants. Each invariant should have:]
[FILL IN: - A name and precise statement]
[FILL IN: - The consequence of violation]

1. **[FILL IN: Invariant Name]**: `[FILL IN: formal or semi-formal statement]`
   - Violation means: [FILL IN: what goes wrong if this breaks]

2. **[FILL IN: Invariant Name]**: `[FILL IN: statement]`
   - Violation means: [FILL IN: consequence]

3. **[FILL IN: Invariant Name]**: `[FILL IN: statement]`
   - Violation means: [FILL IN: consequence]

[Add more as needed — 5+ is strongly preferred]

---

## Trust Assumptions

### Trusted (not in scope for adversarial analysis)
[FILL IN: List what the protocol trusts. Examples:]
- Owner multisig ([FILL IN: N-of-M]) is not malicious and key distribution is secure
- [FILL IN: External protocol, e.g., Chainlink] provides accurate data within [FILL IN: bounds]
- [FILL IN: Any other trusted assumption]

### Adversarial (treated as untrusted — must be resilient against)
[FILL IN: List what the protocol treats as adversarial. Examples:]
- Any user-supplied address (may be a malicious contract)
- Transaction ordering (MEV bots may front-run, sandwich, or back-run)
- Flash loan capital (any amount can be borrowed atomically within one block)
- [FILL IN: any other adversarial inputs or actors]

### Known Limitations (by design — not bugs)
[FILL IN: List limitations. Examples:]
- [FILL IN: Token type] is not supported because [FILL IN: reason]
- Maximum [FILL IN: parameter] of [FILL IN: value] due to [FILL IN: reason]
- [FILL IN: any other known limitations]
```

---

## Template: `docs/audit/threat-model.md`

```markdown
# Threat Model

Write this document as if you are an attacker trying to break your own protocol.
The goal: give auditors a map of the attack surface so they can allocate their time to
the highest-risk areas.

---

## Attacker Goals
Ranked by potential profit (highest = highest audit priority):

1. [FILL IN: e.g., Drain all user funds from the vault]
2. [FILL IN: e.g., Inflate own share position relative to others]
3. [FILL IN: e.g., Prevent users from withdrawing funds (DoS)]
4. [FILL IN: e.g., Gain unauthorized admin/owner access]
5. [FILL IN: e.g., Extract MEV from user transactions]

---

## Attacker Capabilities

An attacker in this threat model CAN:
- Submit transactions at any time and in any order
- Control transaction ordering (as a validator or via Flashbots private mempool)
- Take flash loans of any token in unlimited amounts within one block
- Deploy contracts with arbitrary logic (including malicious receive()/fallback())
- Read all on-chain state and pending transactions in the mempool
- Manipulate oracle prices within the cost of capital for that oracle type
- [FILL IN: any additional capabilities specific to your protocol]

An attacker CANNOT:
- Forge signatures without the private key
- Break EVM cryptographic primitives (ECDSA, keccak256)
- Exceed the block gas limit in a single transaction (~30M gas on Ethereum mainnet)
- Modify the state of a previous block (assuming >2 confirmations)
- [FILL IN: any additional constraints specific to your deployment environment]

---

## Specific Attack Vectors of Concern

For each vector: describe the scenario, the mitigation implemented, and the current status.
"Ask auditors to verify" tells auditors exactly where to focus.

### HIGH PRIORITY VECTORS

**V-1: [FILL IN: Vector Name]**
- Scenario: [FILL IN: Step-by-step attack description. Be specific. Include attacker starting state,
  actions taken, and what is gained.]
- Mitigation implemented: [FILL IN: What you did to prevent this. Reference specific code if possible.]
- Status: [FILL IN: Mitigated / Partially mitigated / Unmitigated (and why)]
- Ask auditors: [FILL IN: What specific question should auditors answer about this mitigation?]

**V-2: [FILL IN: Vector Name]**
- Scenario: [FILL IN: description]
- Mitigation implemented: [FILL IN: mitigation]
- Status: [FILL IN: status]
- Ask auditors: [FILL IN: question]

[Add HIGH PRIORITY vectors for your specific protocol]

### MEDIUM PRIORITY VECTORS

**V-N: [FILL IN: Vector Name]**
- Scenario: [FILL IN: description]
- Mitigation implemented: [FILL IN: mitigation]
- Status: [FILL IN: status]

[Add MEDIUM PRIORITY vectors]

### LOW PRIORITY VECTORS

**V-N: [FILL IN: Vector Name]**
- Scenario: [FILL IN: description]
- Accepted risk: [FILL IN: why this is low priority and/or accepted]

---

## Economic Attack Analysis

[FILL IN: For protocols with token economics, pricing mechanisms, or liquidity pools:]

**Profitability threshold:**
[FILL IN: What is the minimum capital an attacker needs to make an attack economically viable?
Example: "A share inflation attack requires donating at least 1,000 USDC to be economically
viable given the virtual shares offset. Attacks below this threshold are unprofitable."]

**Flash loan viability:**
[FILL IN: Can any attack be executed profitably within a single transaction using flash loans?
Which functions are vulnerable? What is the maximum extractable value?]
```

---

## Template: `docs/audit/findings-log.md`

```markdown
# Internal Security Findings Log

This log documents all issues found during internal security review before the external audit.
It serves two purposes:
1. Evidence to auditors that internal review was thorough
2. List of known issues to avoid duplicate reporting

Last updated: [FILL IN: date]
Reviewed by: [FILL IN: name(s) or "optimizoor + reviewoor agents"]

---

## Finding Table

| ID | Severity | Title | Status | Fixed in Commit | Regression Test |
|----|----------|-------|--------|-----------------|-----------------|
| INT-001 | [Critical/High/Medium/Low/Info] | [FILL IN: short title] | [Fixed/Wontfix/Accepted] | [commit hash] | [test function name] |
| INT-002 | [FILL IN] | [FILL IN] | [FILL IN] | [FILL IN] | [FILL IN] |

[Add one row per finding from the security review. If no findings: "No issues found during
internal review." — but this is extremely rare; be thorough.]

---

## Finding Details

### INT-001: [FILL IN: Title]
**Severity:** [FILL IN]
**File:** [FILL IN: src/Contract.sol, line X]
**Description:**
[FILL IN: Full description of the vulnerability, including how it could be exploited.]

**Root cause:**
[FILL IN: Why this vulnerability existed — missing check, wrong ordering, etc.]

**Fix:**
[FILL IN: What was changed. Include before/after code snippet if helpful.]

**Regression test:**
[FILL IN: Name of the test that proves this is fixed. The test must fail on the unfixed code.]

**Status:** Fixed in commit [FILL IN: hash]

---

### INT-002: [FILL IN: Title]
[Repeat the structure above for each finding]

---

## Wontfix / Accepted Risk Register

| ID | Severity | Title | Reason Accepted |
|----|----------|-------|-----------------|
| INT-XXX | [FILL IN] | [FILL IN] | [FILL IN: precise business reason this risk is accepted] |

[If empty: "No findings accepted as wontfix. All issues were resolved."]

---

## Review Coverage

This internal review covered the following security domains:
- [x] Reentrancy (single, cross-function, cross-contract, read-only)
- [x] Access control (modifiers, ownership, role management)
- [x] Integer arithmetic (precision, overflow, rounding, casting)
- [x] External calls (return values, SafeERC20, fee-on-transfer)
- [x] Oracle security (staleness, negative prices, L2 sequencer)
- [x] Flash loan and MEV vectors
- [x] Upgrade security (storage layout, initializers, authorization)
- [x] Denial of service (loops, push payments, griefing)
- [x] Signature security (replay, nonces, domain separator, deadline)
```

---

## LOC Counting and Coverage Commands

```bash
# Count Solidity LOC in src/ (excludes comments and blanks)
cloc src/ --include-lang=Solidity

# Count per-file LOC
cloc src/ --include-lang=Solidity --by-file

# Generate LCOV coverage data
forge coverage --report lcov

# Generate browsable HTML coverage report (requires lcov installed)
genhtml lcov.info --branch-coverage --output-dir coverage/

# View coverage summary in terminal
forge coverage

# Check for debug artifacts that must not be in audit code
grep -rn "console" src/
grep -rn "TODO\|FIXME\|HACK" src/

# Verify no floating pragma (all must be pinned exact versions)
grep -rn "pragma solidity \^" src/

# Tag the audit commit
git tag -a v1.0.0-audit -m "Audit snapshot — see docs/audit/scope.md"
git push origin v1.0.0-audit
```

---

## Audit Firm Communication Guide

### What to Send

Send the full audit package as a single archive or repository link:
```
docs/audit/scope.md
docs/audit/protocol.md
docs/audit/threat-model.md
docs/audit/findings-log.md
coverage/              (HTML coverage report)
coverage/coverage-notes.md
```

Pin the exact commit. Include the tag if created.

### Timeline

| Phase | Who | What |
|-------|-----|------|
| T-0: Package sent | Team → Auditors | Send all 4 docs + coverage report + tagged commit |
| T+1 to T+3 days | Auditors → Team | Auditors confirm scope is clear; ask clarifying questions |
| T+3 days: Kickoff | Both | 30-minute call to align on priorities and scope |
| During audit | Both | Answer auditor questions within 24 hours; do not push new code to audit branch |
| Preliminary findings | Auditors → Team | Auditors share draft findings; team responds with initial assessment |
| Final report | Auditors → Team | Auditors deliver final report with all findings classified |
| Remediation | Team | Fix all Critical and High findings; write regression tests |
| Remediation review | Auditors | Auditors verify fixes (often at additional cost; clarify upfront) |
| Public disclosure | Both | Agree on timing; coordinate responsible disclosure |

### How to Respond to Preliminary Findings

For each preliminary finding, respond with one of:
1. **Confirmed — will fix:** Acknowledge the vulnerability. Describe the intended fix. Ask if
   the fix approach is sound before implementing.
2. **Confirmed — accepted risk:** Acknowledge. Explain precisely why this risk is accepted by
   design (economic cost > benefit, mitigated by other mechanisms, out of scope by design).
3. **Disputed:** Provide a clear technical argument for why this is not a vulnerability. Be
   specific — reference the exact invariant, check, or mechanism that prevents the attack.
   Do not be defensive; ask the auditor to confirm your understanding.

Never dismiss a finding as "won't happen" without a technical argument. Auditors have seen
"won't happen" become mainnet exploits.
