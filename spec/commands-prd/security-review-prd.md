# Command PRD: `/security-review`

**File:** `commands/security-review.md`

**Delegates to:** `solidity-code-reviewer` skill → dispatches `reviewoor` agent

---

## Purpose

User-triggered entry point to run a two-stage security review on a completed contract. Dispatches the `reviewoor` agent for spec compliance check followed by full security analysis.

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /security-review

Invoke the `decipher-solidity-superpowers:solidity-code-reviewer` skill, which
dispatches the `reviewoor` agent for a two-stage security review.

Use this command after completing a contract implementation to get a structured
security review with severity-rated findings.
```

---

## When to Use

After completing a contract implementation, before marking work as done. Can also be run after any significant change to an existing contract.

---

## What Happens on Invocation

1. The `solidity-code-reviewer` skill is invoked.
2. The skill collects context to pass to the `reviewoor` agent:
   - Full source code of the contract
   - The interface file it implements
   - The design document from `docs/designs/`
   - The invariant list from the planner skill
   - Git diff (if reviewing a change to existing contract)
3. The `reviewoor` agent runs:
   - **Stage 1:** Spec compliance (interface match, error usage, event emission, invariant coverage)
   - **Stage 2:** Security analysis (reentrancy, access control, arithmetic, external calls, oracle, flash loan/MEV, upgrades)
4. Findings are output with severity ratings (Critical/High/Medium/Low/Informational).
5. Critical and High findings must be fixed and regression tests written before proceeding.

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/security-review`.
- All Critical and High findings block further progress. Medium findings block deployment (not merge). Low and Informational findings are logged for audit prep.
