# Command PRD: `/pre-upgrade`

**File:** `commands/pre-upgrade.md`

**Delegates to:** `solidity-upgrader` skill

---

## Purpose

User-triggered entry point to run mandatory storage layout verification and staged rollout checks before executing any proxy upgrade.

---

## File Contents

```markdown
---
disable-model-invocation: true
---

# /pre-upgrade

Invoke the `decipher-solidity-superpowers:solidity-upgrader` skill.

Use this command before any proxy upgrade. Verifies storage layout compatibility,
staged rollout requirements, and implementation initialization safety.
```

---

## When to Use

Before implementing or executing any proxy upgrade. This command enforces the `solidity-upgrader` skill's hard gate: no upgrade transaction is submitted until the storage layout diff is clean and the upgrade has been tested on a fork.

---

## What Happens on Invocation

1. The `solidity-upgrader` skill is invoked.
2. The skill runs through the 8-item pre-upgrade checklist:
   - Storage layout exported for old implementation (`forge inspect OldImpl storage-layout --pretty > old-layout.txt`)
   - Storage layout exported for new implementation (`forge inspect NewImpl storage-layout --pretty > new-layout.txt`)
   - Layouts diffed — no existing slots shifted or removed (`diff old-layout.txt new-layout.txt`)
   - New state variables only appended at end (or fill `__gap`)
   - `_disableInitializers()` in new implementation constructor
   - New initializer function is versioned (e.g., `initializeV2` with `reinitializer(2)` modifier)
   - All existing tests pass with new implementation (`forge test`)
   - New tests for new functionality written and passing
3. The skill enforces the staged rollout sequence: fork → testnet → mainnet.
4. Post-upgrade: `cast storage` verification of new implementation address.

---

## Notes

- `disable-model-invocation: true` means the command only fires when the user explicitly types `/pre-upgrade`.
- Storage layout verification is non-negotiable. "The layout is obviously the same" is an explicitly blocked rationalization.
- Inheritance order changes corrupt storage layouts silently — the diff command catches these.
