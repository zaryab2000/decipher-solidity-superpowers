# Command PRD: `/audit-prep`

**Output file:** `commands/audit-prep.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-audit-prep` skill
**Position in lifecycle:** Phase 6 — final step before engaging an external audit firm

---

## Purpose

`/audit-prep` is the user-triggered entry point for generating the complete audit package
required before engaging an external security auditor. It invokes `solidity-audit-prep`,
which assembles four mandatory documents that external auditors need to review efficiently.

This command exists because poorly prepared audit packages waste auditor time on issues that
should have been caught internally. Auditors reading a well-structured protocol overview,
threat model, and findings log can focus on novel attack vectors rather than rediscovering
known issues.

The audit package is not optional and not partial. All four documents must be complete before
an external audit is engaged.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/audit-prep.md` with this exact structure:

```markdown
---
disable-model-invocation: true
description: Generate the complete audit package before engaging an external auditor
---

# /audit-prep

Invoke the `decipher-solidity-superpowers:solidity-audit-prep` skill.

Use this command when all internal work is complete: code is feature-complete, all tests
pass, gas audit is done, and all Critical/High security findings are resolved.

Generates the mandatory 4-document audit package:
- `audit/scope.md` — in-scope files, exact commit hash, dependency audit status
- `audit/protocol.md` — actors, state machine, invariants, trust assumptions
- `audit/threat-model.md` — attacker goals, capabilities, vectors of concern
- `audit/findings-log.md` — all internal findings with resolutions and regression tests

Do not engage an external auditor without this package.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Must be explicitly invoked. |
| `description` | `"Generate the complete audit package before engaging an external auditor"` | Shown in `/help`. "Before engaging an external auditor" clarifies this is a terminal lifecycle step. |

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-audit-prep`.

2. **State the full set of preconditions explicitly** — this command sits at the end of the
   lifecycle and depends on every earlier phase being complete. The user must see all four
   conditions:
   - Code is feature-complete
   - All tests pass
   - Gas audit is done
   - All Critical/High security findings are resolved

3. **List all four output documents** — this is one case where the command body should go
   slightly beyond a one-liner, because auditors (and team leads) need to know at a glance
   what the package contains. The document list is a user-facing manifest, not internal
   implementation detail.

4. **Include a hard-stop directive** — "Do not engage an external auditor without this
   package." This is the terminal gate of the entire plugin lifecycle.

5. **Use the exact output paths** that the skill will write:
   - `audit/scope.md`
   - `audit/protocol.md`
   - `audit/threat-model.md`
   - `audit/findings-log.md`

   Note: these are top-level `audit/` paths, not `docs/audit/`. The skill determines the
   canonical paths — the command reflects them for user clarity.

---

## What This Command Must NOT Do

- Must NOT describe how each document is structured. That is the skill's job.
- Must NOT include the document templates themselves.
- Must NOT describe `forge coverage` commands. Those are in the skill.
- Must NOT describe how findings are classified. That is the `reviewoor` agent's output.
- Must NOT allow running before Critical/High findings are resolved. The skill enforces
  this gate — the command primes the user's expectation.

---

## Behavior on Invocation

When the user types `/audit-prep`:

1. Claude Code loads `commands/audit-prep.md`.
2. `disable-model-invocation: true` suppresses free-form model response.
3. The `solidity-audit-prep` skill fires.
4. The skill checks preconditions (tests pass, findings resolved, gas audit exists).
5. The skill assembles all four documents from existing artifacts (design docs, findings log,
   invariant lists, dependency manifests).
6. Documents are written to the `audit/` directory.
7. The command's job is done when the skill fires.

---

## Placement in the Lifecycle

```
/security-review (all Critical/High findings resolved)
    └─► /gas-audit (report exists)
            └─► /audit-prep
                    └─► solidity-audit-prep skill
                            └─► audit/scope.md
                            └─► audit/protocol.md
                            └─► audit/threat-model.md
                            └─► audit/findings-log.md
                    └─► ► ► Engage external auditor
```

This is the terminal command in the plugin lifecycle. There is no next phase within the
plugin after `/audit-prep`. The output is handed to an external audit firm.

---

## The Four Required Documents

The command body lists these. The skill specifies their full structure. Listed here for
coding agent reference:

| Document | Purpose | Source Material |
|---|---|---|
| `audit/scope.md` | Defines exactly what is in scope for the audit | Files list, commit hash, dependency audit status, out-of-scope exclusions |
| `audit/protocol.md` | Plain-English protocol description for auditors unfamiliar with the codebase | Design docs, actors, state machine, invariants, trust assumptions, known limitations |
| `audit/threat-model.md` | Attacker goals, capabilities, and specific attack vectors the team is worried about | Economic attack surfaces from design phase, external integration risks |
| `audit/findings-log.md` | All internal `reviewoor` findings with resolution status and regression test names | `reviewoor` output from all `/security-review` runs |

---

## Verification Checklist for the Coding Agent

After writing `commands/audit-prep.md`, verify:

- [ ] `disable-model-invocation: true` is present
- [ ] `description` mentions "audit package" and "external auditor"
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-audit-prep`
- [ ] All four output documents are listed with their paths
- [ ] All preconditions are stated (feature-complete, tests pass, gas audit, no Critical/High)
- [ ] Hard-stop directive is present ("Do not engage an external auditor without this package")
- [ ] File is saved to `commands/audit-prep.md`
- [ ] This is understood as the terminal lifecycle command — no next command follows it
