# Command PRD: `/new-contract`

**File:** `commands/new-contract.md`

**Delegates to:** `solidity-planner` skill

---

## Purpose

Entry point for all new Solidity work. Triggers the planning gate before any code is written.

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /new-contract

Invoke the `decipher-solidity-superpowers:solidity-planner` skill.

Use this command to start designing a new smart contract, interface, library, or
protocol component. The planner will guide you through architecture decisions,
invariant definition, and interface specification before any code is written.
```

---

## When to Use

Any time a developer wants to start a new contract, library, or protocol component. This is the mandatory entry point — no `.sol` files are written until the planner has been run and the design approved.

---

## What Happens on Invocation

1. The `solidity-planner` skill is invoked.
2. The planner runs its 13-item mandatory checklist.
3. The planner asks Solidity-specific design questions (token interactions, upgradability, emergency mechanisms, events, governance).
4. The planner proposes 2-3 architectural approaches.
5. The user approves one approach.
6. The design document is written to `docs/designs/YYYY-MM-DD-<contract-name>-design.md`.
7. Interface files are written to `src/interfaces/I<ContractName>.sol`.
8. Interfaces are committed before any implementation code is written.

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/new-contract`. It is not triggered automatically by the model.
- The command is intentionally minimal — all logic lives in the `solidity-planner` skill.
