# Command PRD: `/new-contract`

**Output file:** `commands/new-contract.md`
**Delegates to:** `decipher-solidity-superpowers:solidity-planner` skill
**Position in lifecycle:** Phase 1 — mandatory entry point for all new Solidity work

---

## Purpose

The `/new-contract` command is the single mandatory entry point for starting any new Solidity
contract, interface, library, or protocol component. It enforces design-before-code discipline
by invoking the `solidity-planner` skill before a single line of `.sol` code is written.

This command exists because AI agents left to their own devices skip design and write code
immediately. The command is a forcing function: there is no other sanctioned way to begin
contract work.

---

## What the Coding Agent Must Produce

The coding agent must produce a file at `commands/new-contract.md` with this exact structure:

```markdown
---
disable-model-invocation: true
description: Start a new smart contract, interface, library, or protocol component
---

# /new-contract

Invoke the `decipher-solidity-superpowers:solidity-planner` skill.

Use this command to start designing a new smart contract, interface, library, or protocol
component. The planner enforces design-before-code: no `.sol` files are written until the
architecture is approved, invariants are defined, and interfaces are committed.

Do not skip this command. Do not write contract code before running `/new-contract`.
```

---

## Frontmatter Requirements

| Field | Value | Why |
|---|---|---|
| `disable-model-invocation` | `true` | Prevents the model from auto-triggering this command. User must type `/new-contract` explicitly. |
| `description` | `"Start a new smart contract, interface, library, or protocol component"` | Shown in `/help` listings and command discovery. Should be specific enough to distinguish from other commands. |

Do NOT add `arguments`, `allowed_tools`, or any other frontmatter fields. Commands in this
plugin are intentionally minimal wrappers.

---

## Command Body Requirements

The body must:

1. **Name the skill exactly** — `decipher-solidity-superpowers:solidity-planner` (plugin-qualified
   name, not just `solidity-planner`). This ensures the correct plugin's skill is invoked even
   if another plugin defines a skill with the same base name.

2. **State the purpose in one sentence** — why this command exists and what it prevents.

3. **Include a hard-stop directive** — a short line that explicitly blocks skipping, e.g.,
   "Do not skip this command." This is read by the agent when the command fires and reinforces
   the gate before the skill even loads.

4. **Not describe the skill's internal logic** — the command body is not a checklist. The
   checklist lives in `skills/solidity-planner/SKILL.md`. The command only routes; it does
   not instruct.

---

## Behavior on Invocation

When the user types `/new-contract`, the following sequence occurs:

1. Claude Code loads `commands/new-contract.md`.
2. Because `disable-model-invocation: true`, the model does NOT generate a free-form response.
   Instead, it fires the skill named in the body.
3. `solidity-planner` skill takes over. The command's job is done.

The command must not attempt to collect arguments, ask clarifying questions, or do any work
of its own. If the user types `/new-contract MyToken ERC-20`, the skill will handle that
input — the command does not need to parse it.

---

## Optional: Argument Passthrough

If the user provides a contract name or brief description after the command
(e.g., `/new-contract StakingVault`), the command body should not discard it. The skill
invocation line may optionally reference the user's input context with a note like:

```
If the user provided a contract name or description, pass it to the planner as initial context.
```

This line is optional but recommended. It prevents the planner from asking "what contract are
you building?" when the user already told it.

---

## What This Command Must NOT Do

- Must NOT contain a checklist. Checklists belong in the skill.
- Must NOT describe what the planner does internally. That belongs in the skill PRD.
- Must NOT have conditional logic or branches. Commands are single-purpose routers.
- Must NOT set `disable-model-invocation: false`. Every command in this plugin uses `true`.
- Must NOT allow invocation without user intent. This command must only fire on explicit
  `/new-contract` invocation.

---

## Placement in the Lifecycle

```
/new-contract
    └─► solidity-planner skill
            └─► design doc committed
            └─► interface files committed
            └─► ► ► solidity-builder skill (next phase)
```

No other command in this plugin precedes `/new-contract`. It is always the first command
in any new contract lifecycle. Running it a second time (for a second contract in the same
project) is valid and expected.

---

## Verification Checklist for the Coding Agent

After writing `commands/new-contract.md`, verify:

- [ ] `disable-model-invocation: true` is present in frontmatter
- [ ] `description` field is present and accurate
- [ ] Skill name is plugin-qualified: `decipher-solidity-superpowers:solidity-planner`
- [ ] Body is ≤ 6 lines (commands are thin wrappers, not documentation)
- [ ] No checklist items in the body
- [ ] Hard-stop directive is present ("Do not skip", "Do not write code before...")
- [ ] File is saved to `commands/new-contract.md` (not `commands/new_contract.md`)
