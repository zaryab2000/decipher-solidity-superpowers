# decipher-solidity-superpowers

A Claude Code plugin that enforces a gate-based workflow for Solidity smart contract development. Every phase — planning, building, testing, gas optimization, documentation, deployment, upgrades, and audit prep — is a mandatory checkpoint, not a suggestion.

## ⚠️ Work in Progress — Do Not Install Yet

This plugin is under active development and is not ready for use. APIs, skill files, and hook behavior may change without notice. Installation instructions will be added when the first stable release is ready.

---

## What It Does

Left to its own defaults, an AI agent will happily write 200 lines of implementation code the moment you describe a contract — no design doc, no interface, no invariants, no tests. This plugin corrects that by injecting a strict rule before every response in a Solidity session:

> Before responding to ANY message, check if a phase skill applies. If there is even a 1% chance a skill is relevant — invoke it first. No exceptions.

### Enforced Phase Sequence

```
Plan → Build → Test → Gas Optimize → NatSpec → Deploy/Upgrade → Audit Prep
```

Each phase has a hard gate that blocks the next phase until its conditions are met.

---

## Plugin Components

| Component | Count | Purpose |
|---|---|---|
| Skills | 10 | Phase gates — each enforces a mandatory checklist |
| Agents | 2 | `optimizoor` (gas audit), `reviewoor` (security review) |
| Commands | 6 | User entry points (`/new-contract`, `/gas-audit`, `/security-review`, `/audit-prep`, `/pre-deploy`, `/pre-upgrade`) |
| Hooks | 2 | Session start (injects THE RULE), PreToolUse (plan gate) |

## Hard Gates by Phase

| Phase | What Is Blocked Without It |
|---|---|
| `solidity-planner` | No `.sol` files until design doc + interface committed |
| `solidity-builder` | No implementation without a failing test first (TDD) |
| `solidity-tester` | No value-handling contract without fuzz + invariant tests |
| `solidity-gas-optimizer` | No deployment without a gas audit report |
| `solidity-natspec` | No commit without NatSpec on every public/external function |
| `solidity-deployer` | No manual deployments — only `forge script` with simulation |
| `solidity-upgrader` | No upgrade without storage layout diff + fork test |
| `solidity-code-reviewer` | No contract marked complete without security review |
| `solidity-audit-prep` | No external audit without a complete 4-document package |

---

## Requirements

- Claude Code
- Foundry (`forge`, `cast`)
- Solidity `^0.8.20`

---

## License

MIT — Zaryab
