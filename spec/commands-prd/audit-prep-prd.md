# Command PRD: `/audit-prep`

**File:** `commands/audit-prep.md`

**Delegates to:** `solidity-audit-prep` skill

---

## Purpose

User-triggered entry point to generate the complete audit package required before engaging an external auditor.

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /audit-prep

Invoke the `decipher-solidity-superpowers:solidity-audit-prep` skill.

Use this command when code is feature-complete and internally reviewed.
Generates the full audit package: scope doc, protocol overview, threat model,
coverage report, and internal findings log.
```

---

## When to Use

After code is feature-complete, all internal security reviews are done, and all Critical/High findings from `reviewoor` are resolved. This is the final step before engaging an external audit firm.

---

## What Happens on Invocation

1. The `solidity-audit-prep` skill is invoked.
2. The skill produces the mandatory 4-document audit package:
   - `docs/audit/scope.md` — in-scope/out-of-scope files, exact commit hash, dependency audit status
   - `docs/audit/protocol.md` — plain English protocol overview, actors, state machine, invariants, trust assumptions, known limitations
   - `docs/audit/threat-model.md` — attacker goals, attacker capabilities, attack vectors of concern
   - Coverage report via `forge coverage --report lcov` + HTML generation
3. `docs/audit/findings-log.md` is created or updated — all internal findings from `reviewoor` with resolutions and regression test names.

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/audit-prep`.
- This is the final skill in the lifecycle. No external audit engagement should happen without this package.
- The audit package is what auditors read first. Poorly prepared packages waste auditor time on issues that should have been caught internally.
