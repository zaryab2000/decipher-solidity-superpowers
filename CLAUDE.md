# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

`decipher-solidity-superpowers` is a Claude Code plugin providing gate-enforced workflow for Solidity smart contract development. It enforces a strict phase sequence: **Plan → Build → Test → Gas Optimize → NatSpec → Deploy/Upgrade → Audit Prep** — where each phase is a mandatory gate, not an optional suggestion.

This is a plugin *definition* repository. The actual Foundry contracts being developed live in the *user's* project. This repo contains only plugin components: skills, agents, commands, hooks, and their supporting reference files.

## Repository Structure

```
decipher-solidity-superpowers/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest
│   └── marketplace.json       # Marketplace listing
├── hooks/
│   ├── hooks.json             # Hook event wiring
│   ├── session-start.sh       # Injects using-solidity-superpowers skill at session start
│   └── plan-gate.sh           # PreToolUse gate: blocks .sol writes without a design doc
├── skills/
│   ├── using-solidity-superpowers/SKILL.md    # Master orchestrator (THE RULE + skill inventory)
│   ├── solidity-planner/SKILL.md              # Design-before-code gate
│   ├── solidity-builder/SKILL.md              # TDD RED-GREEN-REFACTOR gate
│   ├── solidity-tester/SKILL.md               # Fuzz + invariant testing gate
│   ├── solidity-gas-optimizer/SKILL.md        # Gas review gate (dispatches optimizoor)
│   ├── solidity-natspec/SKILL.md              # Documentation gate
│   ├── solidity-deployer/SKILL.md             # Deployment gate (no manual deploys)
│   ├── solidity-upgrader/SKILL.md             # Upgrade gate (storage layout verification)
│   ├── solidity-code-reviewer/SKILL.md        # Security review gate (dispatches reviewoor)
│   └── solidity-audit-prep/SKILL.md           # Audit package gate
├── agents/
│   ├── optimizoor.md          # Gas optimization agent (8-category checklist)
│   └── reviewoor.md           # Security review agent (2-stage review)
└── commands/
    ├── new-contract.md        # /new-contract → solidity-planner
    ├── gas-audit.md           # /gas-audit → solidity-gas-optimizer → optimizoor
    ├── security-review.md     # /security-review → solidity-code-reviewer → reviewoor
    ├── audit-prep.md          # /audit-prep → solidity-audit-prep
    ├── pre-deploy.md          # /pre-deploy → solidity-deployer
    └── pre-upgrade.md         # /pre-upgrade → solidity-upgrader
```

Each skill directory may also contain a supporting reference file (e.g., `brainstorming-questions.md`, `foundry-test-patterns.md`, `gas-checklist.md`) that is loaded only when the skill needs it, not injected into context by default.

## Component Architecture

### How Components Interact

1. **SessionStart hook** (`session-start.sh`) fires at every session start and injects `using-solidity-superpowers/SKILL.md` as `additionalContext`. This makes THE RULE and skill inventory available before the agent's first turn. Hook must be `async: false`.

2. **PreToolUse hook** (`plan-gate.sh`) fires before every Write or Edit tool call. If the target file is a `src/*.sol` file and `docs/designs/` is empty or absent, it injects a hard-gate block preventing code writing and redirecting to the planner.

3. **Skills** are the primary enforcement layer. Each skill has: a strict rule (in a code block), a hard gate (what is blocked), a numbered mandatory checklist, Forge commands, output artifacts, terminal state (which skill comes next), and blocked rationalizations.

4. **Agents** (`optimizoor`, `reviewoor`) are dispatched *by* skills — not directly by the user. `solidity-gas-optimizer` dispatches `optimizoor`; `solidity-code-reviewer` dispatches `reviewoor`.

5. **Commands** are thin wrappers with `disable-model-invocation: true` that delegate entirely to the corresponding skill. Commands are the user's entry points; skills do the work.

### Skill File Structure

Every `SKILL.md` follows this exact section order:
```
## When
## The strict rules   ← single rule in a code block
## Hard Gate
## Mandatory Checklist
## Solidity-Specific Guidelines / Forge Commands
## Output Artifacts
## Terminal State
## Blocked Rationalizations
```

### using-solidity-superpowers (Master Orchestrator)

This is NOT a skill the user invokes — it is the routing layer injected at session start. It contains:
- **THE RULE**: "Before responding to ANY user message, check if a skill applies. If there is even a 1% chance a skill is relevant, you MUST invoke it."
- The skill inventory table (trigger signal → skill name)
- At least 4 blocked rationalizations agents must refuse
- A process flow graph

Keep this file under 200 lines. It must not contain detailed instructions for any individual skill.

## Skill Summaries

| Skill | Hard Gate |
|---|---|
| `solidity-planner` | No `.sol` files until design doc + interfaces committed |
| `solidity-builder` | No implementation code without a failing Forge test first (TDD) |
| `solidity-tester` | No value-handling contract without fuzz + invariant tests |
| `solidity-gas-optimizer` | No deployment without gas review; dispatches optimizoor agent |
| `solidity-natspec` | No function/error/event committed without complete NatSpec |
| `solidity-deployer` | No manual deploys; all via `script/Deploy*.s.sol`; verify on-chain |
| `solidity-upgrader` | No upgrade without storage layout diff verification + fork test |
| `solidity-code-reviewer` | No contract marked complete without reviewoor security review |
| `solidity-audit-prep` | No external audit without full audit package (4 required docs) |

## Output Artifacts by Phase

| Phase | Artifacts Written to User's Project |
|---|---|
| planner | `docs/designs/YYYY-MM-DD-<name>-design.md`, `src/interfaces/I<Contract>.sol` |
| builder | `src/<Contract>.sol`, `test/unit/<Contract>.t.sol`, `.gas-snapshot` |
| tester | `test/fuzz/<Contract>.fuzz.t.sol`, `test/invariant/<Contract>.inv.t.sol`, `test/invariant/handlers/<Contract>Handler.sol` |
| deployer | `script/Deploy<Contract>.s.sol`, `script/config/<network>.json`, `deployments/<network>/<contract>.json` |
| audit-prep | `audit/scope.md`, `audit/protocol-overview.md`, `audit/threat-model.md`, `audit/internal-findings.md` |

## Hooks Implementation Notes

- `hooks.json` wires both events in a single file. SessionStart uses matcher `"startup|resume|clear|compact"`.
- `plan-gate.sh` reads the tool input from stdin as JSON, extracts `file_path`, and checks `^src/.*\.sol$`.
- The plan gate is a safety net. The primary enforcement is THE RULE from `using-solidity-superpowers`.
- Both hook scripts require `chmod +x`.

## Forge Commands Referenced in Skills

```bash
# Run single test
forge test --match-test test_<name> -vv

# Run full suite
forge test

# Gas snapshot
forge snapshot
forge snapshot --diff

# Check contract sizes
forge build --sizes

# Storage layout inspection (for upgrader skill)
forge inspect <Contract> storage-layout --pretty

# Static analysis (required before deploy)
slither . --filter-paths "test,script,lib"

# Deployment (simulation then broadcast)
forge script script/Deploy<Contract>.s.sol --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
forge script script/Deploy<Contract>.s.sol --rpc-url $RPC_URL --private-key $DEPLOYER_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY
```

## Build Phases (from PRD §9)

Build phases in order:
0. **Scaffold** — plugin.json, hooks, directory structure, using-solidity-superpowers SKILL.md
1. **Planning Skill** — solidity-planner SKILL.md + brainstorming-questions.md + /new-contract command
2. **Build and Test Skills** — solidity-builder + solidity-tester + their supporting files
3. **Quality Skills** — solidity-natspec, solidity-gas-optimizer, optimizoor agent, solidity-code-reviewer, reviewoor agent
4. **Deployment and Upgrade Skills** — solidity-deployer, solidity-upgrader, /pre-deploy, /pre-upgrade commands
5. **Audit Prep** — solidity-audit-prep SKILL.md + audit-scope-template.md + /audit-prep command
6. **End-to-End Test** — full ERC-4626 vault walkthrough through all phases

## Key Solidity Standards Enforced by Skills

- **Ownable2Step** (not Ownable) for single-admin patterns
- **AccessControl** for multi-role patterns
- **SafeERC20** for all token interactions (handles non-standard ERC-20s)
- **Custom errors** over `require(condition, "string")` — no exceptions
- **Checks-Effects-Interactions** pattern mandatory on every external-facing function
- **ReentrancyGuard** as defense-in-depth on state-changing functions with external calls
- Test naming: `test_<function>_<scenario>`, `testFuzz_<function>_<property>`, `invariant_<property>`
- UUPS proxy as default for new upgradeable contracts (not Transparent)
- `__gap` pattern required for upgradeable contract storage

## V2 Deferred (Do Not Implement in V1)

`solidity-systematic-debugging`, `solidity-incident-response`, standalone fork/invariant skills (merged into solidity-tester), Slither as automated hook, multi-chain deployment, formal verification (Certora/SMTChecker), Cursor/Codex/OpenCode support.
