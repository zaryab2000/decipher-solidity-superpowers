# Command PRD: `/gas-audit`

**Output file:** `commands/gas-audit.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-gas-optimizer` skill
**Position in lifecycle:** Phase 3 — after tests pass, before security review or deployment

---

## Purpose

`/gas-audit` is the user-triggered entry point for running a full gas optimization audit on
one or more contracts. It routes to the `solidity-gas-optimizer` skill, which in turn
dispatches the `optimizoor` agent to run the 8-category gas checklist.

This command exists because gas optimization without structure produces inconsistent results.
The `optimizoor` agent runs every gas category systematically — storage layout, loops, calldata,
deployment, type optimization, custom errors, compiler, immutable/constant, unchecked arithmetic,
visibility, event logging — and cannot be partially skipped.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/gas-audit.md` with this exact structure:

```markdown
---
disable-model-invocation: true
description: Run a full gas optimization audit on a contract before deployment
---

# /gas-audit

Invoke the `decipher-solidity-superpowers:solidity-gas-optimizer` skill, which dispatches
the `optimizoor` agent to run the full 8-category gas optimization audit.

Use this command after all tests pass and before running `/security-review` or `/pre-deploy`.
The audit produces a severity-categorized findings report and a gas snapshot diff.

Do not deploy without completing the gas audit. `/pre-deploy` will block if the gas audit
report is absent.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Prevents auto-triggering. Must be explicitly invoked. |
| `description` | `"Run a full gas optimization audit on a contract before deployment"` | Shown in `/help`. Should communicate the blocking nature (before deployment). |

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-gas-optimizer`.

2. **State what the skill dispatches** — mention `optimizoor` agent and "8-category" to set
   the user's expectation. This prevents the user from expecting a quick scan and being
   surprised by a thorough multi-step audit.

3. **State the precondition** — "after all tests pass". The user should not run `/gas-audit`
   on failing code. The command body should make this clear.

4. **State the postcondition** — explain that `/pre-deploy` depends on the audit report. This
   makes the command feel mandatory, not optional.

5. **Include a hard-stop directive** — "Do not deploy without completing the gas audit."

---

## Optional: Target Contract Specification

The user may specify a contract name or path:
- `/gas-audit` — audits all contracts in `src/`
- `/gas-audit src/Vault.sol` — audits only `Vault.sol`
- `/gas-audit Vault` — audits any contract named `Vault`

The command body may include a note:

```
If the user specifies a contract name or path, pass it to the gas optimizer as the audit target.
If no target is specified, audit all contracts in src/.
```

This prevents the optimizer from asking "which contract?" when the user already said.

---

## What This Command Must NOT Do

- Must NOT contain the 8-category checklist. That lives in the `optimizoor` agent.
- Must NOT specify gas thresholds or pass/fail criteria. Those live in the skill.
- Must NOT describe `forge snapshot` commands in the body. Those are in the skill.
- Must NOT have conditional logic or branches.
- Must NOT be run before tests pass. The command body should communicate this constraint.

---

## Behavior on Invocation

When the user types `/gas-audit` (or `/gas-audit <target>`):

1. Claude Code loads `commands/gas-audit.md`.
2. `disable-model-invocation: true` suppresses free-form model response.
3. The `solidity-gas-optimizer` skill fires.
4. The skill dispatches the `optimizoor` agent.
5. `optimizoor` runs the full 8-category audit and writes the report.
6. The command's job is done when the skill fires.

---

## Placement in the Lifecycle

```
solidity-builder (TDD complete)
    └─► solidity-tester (fuzz + invariant tests pass)
            └─► /gas-audit
                    └─► solidity-gas-optimizer skill
                            └─► optimizoor agent
                                    └─► docs/audits/YYYY-MM-DD-<contract>-gas.md
                    └─► /security-review (next)
                    └─► /pre-deploy (blocked until gas audit done)
```

---

## Output Artifact

The `optimizoor` agent (dispatched by the skill) produces:
`docs/audits/YYYY-MM-DD-<contract-name>-gas.md`

This file is checked by `solidity-deployer` before any deployment proceeds. The command body
does not need to specify the output path — that is the skill's and agent's responsibility.
The PRD mentions it here so the coding agent understands the downstream dependency.

---

## Verification Checklist for the Coding Agent

After writing `commands/gas-audit.md`, verify:

- [ ] `disable-model-invocation: true` is present
- [ ] `description` mentions "gas optimization" and "before deployment"
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-gas-optimizer`
- [ ] Body mentions `optimizoor` agent and "8-category"
- [ ] Precondition (tests pass) is stated
- [ ] Hard-stop directive is present
- [ ] Body is ≤ 8 lines
- [ ] No checklist items from the skill or agent appear in the command body
- [ ] File is saved to `commands/gas-audit.md`
