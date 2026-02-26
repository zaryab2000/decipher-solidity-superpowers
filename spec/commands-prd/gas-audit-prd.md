# Command PRD: `/gas-audit`

**File:** `commands/gas-audit.md`

**Delegates to:** `solidity-gas-optimizer` skill → dispatches `optimizoor` agent

---

## Purpose

User-triggered entry point to run a full gas optimization audit on a contract. Dispatches the `optimizoor` agent to run the 8-category gas checklist.

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /gas-audit

Invoke the `decipher-solidity-superpowers:solidity-gas-optimizer` skill, which
dispatches the `optimizoor` agent to run the full 8-category gas checklist.

Use this command when your tests pass and you want a gas optimization report
before deployment.
```

---

## When to Use

After all tests pass for a contract. Before security review or deployment. Typically run after the TDD cycle (`solidity-builder` + `solidity-tester`) is complete.

---

## What Happens on Invocation

1. The `solidity-gas-optimizer` skill is invoked.
2. The skill dispatches the `optimizoor` agent with the contract source code.
3. The `optimizoor` agent:
   - Runs `forge inspect <Contract> storage-layout --pretty`
   - Runs `forge build --sizes`
   - Runs `forge snapshot` for a baseline
   - Audits all 8 gas categories
   - Produces findings categorized as High/Medium/Low
   - Runs `forge snapshot --diff` after changes
   - Saves report to `docs/audits/YYYY-MM-DD-<contract>-gas.md`

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/gas-audit`.
- No deployment is allowed without the gas audit report. This command is mandatory before `/pre-deploy`.
