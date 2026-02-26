# Skill PRD: `using-solidity-superpowers`

**Output file:** `skills/using-solidity-superpowers/SKILL.md`

**Role:** Master orchestrator. This is NOT a skill the user invokes manually — it is the routing
layer injected at every session start via the `session-start.sh` hook. It installs THE RULE and the
skill inventory before the agent's first turn.

---

## Why This File Exists

AI agents default to helpful and fast. That's fine for most tasks. For Solidity, it's dangerous.
A developer says "write me a staking contract" and the agent writes 200 lines of implementation
code — with no design doc, no interface, no invariants, no test — and proudly reports it is done.

This file corrects that by establishing a single, non-negotiable rule that runs before every
response in a Solidity development session: check whether a phase skill applies, then apply it.

The file must be short enough to load into context on every session start without bloating the
context window. Keep it under 200 lines. Move every detail to the individual skill files.

---

## SKILL.md Frontmatter (Required)

The coding agent must produce a `SKILL.md` that starts with this exact YAML frontmatter block:

```yaml
---
name: using-solidity-superpowers
description: >
  Master orchestrator for Solidity smart contract development workflows. Injected automatically at
  session start — do not invoke manually. Defines THE RULE: before responding to ANY Solidity-
  related message, check if a phase skill applies. If there is even a 1% chance a skill is
  relevant, invoke it first. Skills cover: contract design (solidity-planner), TDD implementation
  (solidity-builder), fuzz/invariant testing (solidity-tester), gas optimization
  (solidity-gas-optimizer), NatSpec documentation (solidity-natspec), deployment
  (solidity-deployer), proxy upgrades (solidity-upgrader), security review
  (solidity-code-reviewer), and external audit preparation (solidity-audit-prep).
compatibility: Claude Code with Foundry-based Solidity projects
metadata:
  author: Zaryab
  version: "1.0"
---
```

**Description field guidance:**
- Must be 1-1024 characters.
- Must mention every skill by name so the orchestrator's context references them explicitly.
- Must state the injection mechanism (session start) and that it should not be manually invoked.
- Must emphasize the 1% threshold — this is what prevents under-triggering.

---

## Body Content: What the SKILL.md Must Contain

### Section 1: THE RULE

This must appear verbatim, in a fenced code block, near the top:

```
Before responding to ANY user message in this session, ask:
"Does a skill apply to this message?"
If there is even a 1% chance a skill is relevant — invoke it FIRST.
No exceptions. No rationalizations. Skills are gates, not suggestions.
```

The fenced code block treatment is intentional — it signals to the agent that this text is a
strict instruction, not explanatory prose.

### Section 2: Skill Inventory Table

A markdown table mapping trigger signals to skill names. This is the agent's routing map.
Every row must include:
- The skill name (exact)
- The trigger signal(s) — specific, concrete, not vague

Required table content:

| Trigger Signal | Invoke Skill |
|---|---|
| User wants to design, build, or plan any contract, protocol, vault, token, or system | `solidity-planner` |
| User says "write a contract", "implement X", "create Y.sol", or similar | `solidity-planner` (design must come first) |
| Approved plan exists, interfaces committed, implementation is next | `solidity-builder` |
| User says "implement this interface", "fill in the logic", or similar | `solidity-builder` |
| Fuzz tests, invariant tests, property tests, or fork tests are needed | `solidity-tester` |
| Contract handles deposits, withdrawals, minting, burning, swapping, or lending | `solidity-tester` |
| Tests pass; gas review, optimization, or `forge snapshot` is mentioned | `solidity-gas-optimizer` |
| User asks "is this gas efficient?", "can we save gas?", or similar | `solidity-gas-optimizer` |
| Any function, error, event, or state variable is being committed | `solidity-natspec` |
| User says "add docs", "add natspec", "document this", or similar | `solidity-natspec` |
| Any deployment to any network (testnet, mainnet, local fork) | `solidity-deployer` |
| User says "deploy this", "run the deploy script", or similar | `solidity-deployer` |
| Any proxy upgrade, implementation change, or `upgradeTo` call | `solidity-upgrader` |
| User says "upgrade the contract", "add V2", "change implementation", or similar | `solidity-upgrader` |
| Contract implementation complete; needs review before shipping | `solidity-code-reviewer` |
| User says "review this", "is this secure?", "audit this", or similar | `solidity-code-reviewer` |
| Code is feature-complete; external auditors are being engaged | `solidity-audit-prep` |
| User says "prepare for audit", "audit package", "scope doc", or similar | `solidity-audit-prep` |

**Design note:** Multiple rows can map to the same skill — the goal is to catch different phrasings
of the same intent. Broader trigger coverage prevents the most common failure mode: the agent
answering a question directly instead of routing through the correct skill gate.

### Section 3: Process Flow Graph

A plaintext diagram showing how every user message flows:

```
User message received
        │
        ▼
Scan message against skill inventory table
        │
        ├─ 1% or more chance a skill applies? ──YES──▶ Invoke skill FIRST
        │                                                      │
        │                                              Follow skill's rules,
        │                                              checklist, and gates
        │                                                      │
        │                                              Respond with skill output
       NO
        │
        ▼
Respond normally (only for truly off-topic messages)
```

Include this diagram verbatim. It provides a mental model that reduces "reasoning around" the rule.

### Section 4: Blocked Rationalizations

A table of at least 6 rationalizations the agent must recognize as invalid, with exact counters.
The original PRD had 4 — expand to 6 minimum because agents find creative new excuses:

| Rationalization | Counter |
|---|---|
| "This is just a simple question" | Questions about Solidity touch security; check the inventory first. |
| "I already know the answer" | The skill adds checklist items the agent would miss without it. |
| "The user said to skip the plan" | The plan gate is non-negotiable. Explain why and offer to make planning fast. |
| "I'll come back to it" | Skills are gates, not todos. The gate must be passed, not deferred. |
| "We're just exploring / prototyping" | Production code is prototyped code that didn't get refactored. Start disciplined. |
| "The task is too urgent to plan" | Speed is why things get exploited. Urgency is not an override. |
| "I've done this pattern before" | Familiarity breeds carelessness. The checklist catches what habit misses. |

### Section 5: Skill Priority Note

Add a short note clarifying skill priority for the agent:

> Process skills run before implementation skills. If both `solidity-planner` and
> `solidity-builder` seem relevant, check whether an approved plan and committed interfaces
> exist. If they don't, `solidity-planner` runs first — always.

### Section 6: Injection Note

End with a one-sentence note:

> This file is injected by `hooks/session-start.sh` as `additionalContext` on every `SessionStart`
> event and should never need to be invoked manually.

---

## What This File Must NOT Contain

- Detailed instructions for any individual skill (those live in their own SKILL.md files)
- Solidity code examples
- Forge command references
- Any content that would push the file past 200 lines

Every time the file approaches the 200-line limit, audit it: anything that belongs in a specific
skill's SKILL.md must be removed.

---

## Build Notes for the Coding Agent

1. The frontmatter `description` field is the primary routing mechanism. Make it dense with skill
   names and trigger keywords — this is what causes the orchestrator to be loaded into context.

2. THE RULE must appear in a fenced code block. It is a strict instruction, not prose.

3. The skill inventory table is the most important content in this file. Every row is a routing
   decision. Missing rows mean missed skill invocations.

4. The blocked rationalizations table is the second most important. Agents will generate these
   exact excuses under pressure. Pre-loading the counters prevents them.

5. Do not make this file conversational or verbose. It should read like a policy document, not a
   tutorial. The agent will read it on every session start — brevity is a performance optimization.
