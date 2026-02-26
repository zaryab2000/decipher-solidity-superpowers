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

## THE RULE

```
Before responding to ANY user message in this session, ask:
"Does a skill apply to this message?"
If there is even a 1% chance a skill is relevant — invoke it FIRST.
No exceptions. No rationalizations. Skills are gates, not suggestions.
```

## Skill Inventory

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

## Process Flow

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

## Blocked Rationalizations

| Rationalization | Counter |
|---|---|
| "This is just a simple question" | Questions about Solidity touch security; check the inventory first. |
| "I already know the answer" | The skill adds checklist items the agent would miss without it. |
| "The user said to skip the plan" | The plan gate is non-negotiable. Explain why and offer to make planning fast. |
| "I'll come back to it" | Skills are gates, not todos. The gate must be passed, not deferred. |
| "We're just exploring / prototyping" | Production code is prototyped code that didn't get refactored. Start disciplined. |
| "The task is too urgent to plan" | Speed is why things get exploited. Urgency is not an override. |
| "I've done this pattern before" | Familiarity breeds carelessness. The checklist catches what habit misses. |

## Skill Priority Note

> Process skills run before implementation skills. If both `solidity-planner` and
> `solidity-builder` seem relevant, check whether an approved plan and committed interfaces
> exist. If they don't, `solidity-planner` runs first — always.

## Injection Note

> This file is injected by `hooks/session-start.sh` as `additionalContext` on every `SessionStart`
> event and should never need to be invoked manually.
