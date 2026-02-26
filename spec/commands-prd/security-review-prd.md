# Command PRD: `/security-review`

**Output file:** `commands/security-review.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-code-reviewer` skill
**Position in lifecycle:** Phase 4 — after gas audit, before deployment or audit prep

---

## Purpose

`/security-review` is the user-triggered entry point for a two-stage structured security
review of a completed contract. It routes to `solidity-code-reviewer`, which dispatches the
`reviewoor` agent to run spec compliance verification followed by full security analysis.

This command exists because ad-hoc security review misses entire vulnerability classes.
The `reviewoor` agent runs a deterministic two-stage process:
- **Stage 1:** Spec compliance (interface match, error usage, event emission, invariant coverage)
- **Stage 2:** Security analysis (reentrancy, access control, arithmetic, external calls,
  oracle manipulation, flash loan/MEV attack surfaces, upgrade safety)

Critical and High severity findings from this command block all further progress. This is a
hard gate, not a suggestion.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/security-review.md` with this exact
structure:

```markdown
---
disable-model-invocation: true
description: Run a two-stage security review on a completed contract implementation
---

# /security-review

Invoke the `decipher-solidity-superpowers:solidity-code-reviewer` skill, which dispatches
the `reviewoor` agent for a two-stage security review: spec compliance, then full security
analysis.

Use this command after completing a contract implementation and passing the gas audit.
Findings are severity-rated (Critical / High / Medium / Low / Informational).

Critical and High findings block all further progress and must be resolved before
`/pre-deploy` or `/audit-prep`.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Must be explicitly invoked. |
| `description` | `"Run a two-stage security review on a completed contract implementation"` | Shown in `/help`. "Two-stage" sets expectation for a thorough review. |

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-code-reviewer`.

2. **Name the agent** — `reviewoor`. The user should know a specialized security agent is
   running, not a generic code review.

3. **Describe the two stages explicitly** — "spec compliance, then full security analysis".
   This sets expectations: Stage 1 is fast (interface/invariant check); Stage 2 is thorough
   (vulnerability analysis). Users who have just finished coding should understand both stages
   will run.

4. **State the precondition** — after completing contract implementation AND passing the gas
   audit. Both conditions must be met.

5. **State what blocks on findings** — Critical and High block all further progress. This
   makes the severity system meaningful rather than advisory.

6. **State what the findings unblock** — `/pre-deploy` and `/audit-prep`. This places the
   command clearly in the lifecycle.

---

## Optional: Target Contract Specification

The user may specify a contract:
- `/security-review` — reviews the most recently modified contract, or prompts if ambiguous
- `/security-review src/Vault.sol` — reviews `Vault.sol` specifically
- `/security-review Vault` — reviews the `Vault` contract

The command body may include:

```
If the user specifies a contract name or path, pass it to the code reviewer as the review target.
If no target is specified, the reviewer will identify the contract from context or ask.
```

---

## Context Collection

The `solidity-code-reviewer` skill (not the command) is responsible for collecting:
- Full contract source code
- Corresponding interface file from `src/interfaces/`
- Design document from `docs/designs/`
- Invariant list (from the design doc or planning phase)
- Git diff if reviewing a modification to an existing contract

The command body does NOT instruct context collection. That is the skill's job. The command
only routes.

---

## What This Command Must NOT Do

- Must NOT list the security categories that `reviewoor` checks. Those live in the agent.
- Must NOT define severity thresholds. Those live in the skill.
- Must NOT describe how the reviewer collects context. That is the skill's responsibility.
- Must NOT allow partial reviews (e.g., "just check reentrancy"). The full two-stage review
  always runs. If the user asks for a partial review, the skill handles that request.
- Must NOT have conditional branches.

---

## Behavior on Invocation

When the user types `/security-review` (or `/security-review <target>`):

1. Claude Code loads `commands/security-review.md`.
2. `disable-model-invocation: true` suppresses free-form model response.
3. The `solidity-code-reviewer` skill fires.
4. The skill collects context and dispatches the `reviewoor` agent.
5. `reviewoor` runs Stage 1 (spec compliance) then Stage 2 (security analysis).
6. Findings are output with severity ratings.
7. The command's job is done when the skill fires.

---

## Severity Blocking Rules (Enforced by Skill, Stated in Command for User Clarity)

| Severity | Blocks |
|---|---|
| Critical | All further progress — fix immediately |
| High | All further progress — fix immediately |
| Medium | Deployment (not merge) — fix before `/pre-deploy` |
| Low | Logged for audit package — fix preferred but not blocking |
| Informational | Logged for audit package — no blocking requirement |

These rules are enforced by the `solidity-code-reviewer` skill. The command body summarizes
the Critical/High rule to prime the user's expectations before the skill runs.

---

## Placement in the Lifecycle

```
/gas-audit (complete, report exists)
    └─► /security-review
            └─► solidity-code-reviewer skill
                    └─► reviewoor agent
                            └─► Stage 1: spec compliance
                            └─► Stage 2: security analysis
                            └─► findings report with severity ratings
            └─► Critical/High findings → fix required → re-run /security-review
            └─► All clear → /pre-deploy or /audit-prep
```

---

## Verification Checklist for the Coding Agent

After writing `commands/security-review.md`, verify:

- [ ] `disable-model-invocation: true` is present
- [ ] `description` mentions "two-stage security review"
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-code-reviewer`
- [ ] Body names the `reviewoor` agent
- [ ] Body names both stages (spec compliance, security analysis)
- [ ] Body states Critical/High blocking rule
- [ ] Precondition (gas audit complete) is stated
- [ ] Body is ≤ 10 lines
- [ ] No security checklist items from the agent appear in the command body
- [ ] File is saved to `commands/security-review.md`
