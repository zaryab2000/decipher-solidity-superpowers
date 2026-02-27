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
│   ├── hooks.json             # Hook event wiring (SessionStart + PreToolUse)
│   ├── session-start.sh       # Injects using-solidity-superpowers skill at session start
│   └── plan-gate.sh           # PreToolUse gate: blocks .sol writes without a design doc
├── skills/
│   ├── using-solidity-superpowers/
│   │   └── SKILL.md                        # Master orchestrator (THE RULE + skill inventory)
│   ├── solidity-planner/
│   │   ├── SKILL.md                        # Design-before-code gate
│   │   └── brainstorming-questions.md      # Category-specific design questions
│   ├── solidity-builder/
│   │   ├── SKILL.md                        # TDD RED-GREEN-REFACTOR gate
│   │   └── foundry-test-patterns.md        # 8 copy-paste test patterns
│   ├── solidity-tester/
│   │   ├── SKILL.md                        # Fuzz + invariant testing gate
│   │   └── invariant-testing-guide.md      # Handler patterns, ghost variables, debugging
│   ├── solidity-gas-optimizer/
│   │   ├── SKILL.md                        # Gas review gate (dispatches optimizoor)
│   │   └── gas-checklist.md               # 8-category checklist with cost table
│   ├── solidity-natspec/
│   │   ├── SKILL.md                        # Documentation gate
│   │   └── natspec-templates.md            # 7 copy-paste NatSpec templates
│   ├── solidity-deployer/
│   │   ├── SKILL.md                        # Deployment gate (no manual deploys)
│   │   └── deployment-checklist.md        # Pre/post deploy checklist + network configs
│   ├── solidity-upgrader/
│   │   ├── SKILL.md                        # Upgrade gate (storage layout verification)
│   │   └── proxy-pattern-guide.md         # UUPS/Transparent/Beacon comparison + EIP-1967 slots
│   ├── solidity-code-reviewer/
│   │   ├── SKILL.md                        # Security review gate (dispatches reviewoor)
│   │   └── security-checklist.md          # 10-domain vuln checklist with PoC examples
│   └── solidity-audit-prep/
│       ├── SKILL.md                        # Audit package gate
│       └── audit-scope-template.md        # Fill-in templates for all 4 audit docs
├── agents/
│   ├── optimizoor.md          # Gas optimization agent (8-category, dispatched by solidity-gas-optimizer)
│   └── reviewoor.md           # Security review agent (2-stage, dispatched by solidity-code-reviewer)
├── commands/
│   ├── new-contract.md        # /new-contract → solidity-planner
│   ├── gas-audit.md           # /gas-audit → solidity-gas-optimizer → optimizoor
│   ├── security-review.md     # /security-review → solidity-code-reviewer → reviewoor
│   ├── audit-prep.md          # /audit-prep → solidity-audit-prep
│   ├── pre-deploy.md          # /pre-deploy → solidity-deployer
│   └── pre-upgrade.md         # /pre-upgrade → solidity-upgrader
└── spec/                      # Read-only PRD source files (do not modify)
    ├── skills-prd/            # One PRD per skill (10 files)
    ├── agents-prd/            # One PRD per agent (2 files)
    ├── commands-prd/          # One PRD per command (6 files)
    └── hooks-prd/             # One PRD per hook (2 files)
```

## Component Architecture

### How Components Interact

1. **SessionStart hook** (`session-start.sh`) fires at every session start and injects `using-solidity-superpowers/SKILL.md` as `additionalContext`. This makes THE RULE and skill inventory available before the agent's first turn. Hook is `async: false`.

2. **PreToolUse hook** (`plan-gate.sh`) fires before every Write or Edit tool call. If the target file is a `src/*.sol` file and `docs/designs/` is empty or absent, it injects a `<HARD-GATE>` block preventing code writing and redirecting to the planner.

3. **Skills** are the primary enforcement layer. Each skill has: a strict rule (in a code block), a hard gate (what is blocked), a numbered mandatory checklist, Forge commands, output artifacts, terminal state (which skill comes next), and blocked rationalizations.

4. **Agents** (`optimizoor`, `reviewoor`) are dispatched *by* skills — not directly by the user. `solidity-gas-optimizer` dispatches `optimizoor`; `solidity-code-reviewer` dispatches `reviewoor`.

5. **Commands** are thin wrappers with `disable-model-invocation: true` that delegate entirely to the corresponding skill. Commands are the user's entry points; skills do the work.

### Skill File Structure

Every `SKILL.md` follows this exact section order:
```
YAML frontmatter (name, description, compatibility, metadata)
## The Strict Rule   ← single rule in a fenced code block
## Hard Gate
## Mandatory Checklist (or Pre-X Checklist)
## Solidity-Specific Guidelines / Forge Commands
## Output Artifacts
## Terminal State
## Blocked Rationalizations
```

### using-solidity-superpowers (Master Orchestrator)

This is NOT a skill the user invokes — it is the routing layer injected at session start. It contains:
- **THE RULE**: "Before responding to ANY user message, check if a skill applies. If there is even a 1% chance a skill is relevant, you MUST invoke it."
- The skill inventory table (trigger signal → skill name)
- At least 7 blocked rationalizations agents must refuse
- A process flow graph

Keep this file under 200 lines. It must not contain detailed instructions for any individual skill.

## Skill Summaries

| Skill | Hard Gate | Supporting File |
|---|---|---|
| `solidity-planner` | No `.sol` files until design doc + interfaces committed | `brainstorming-questions.md` |
| `solidity-builder` | No implementation code without a failing Forge test first (TDD) | `foundry-test-patterns.md` |
| `solidity-tester` | No value-handling contract without fuzz + invariant tests | `invariant-testing-guide.md` |
| `solidity-gas-optimizer` | No deployment without gas audit report in `docs/audits/` | `gas-checklist.md` |
| `solidity-natspec` | No function/error/event committed without complete NatSpec | `natspec-templates.md` |
| `solidity-deployer` | No manual deploys; all via `script/Deploy*.s.sol`; verify on-chain | `deployment-checklist.md` |
| `solidity-upgrader` | No upgrade without storage layout diff verification + fork test | `proxy-pattern-guide.md` |
| `solidity-code-reviewer` | No contract marked complete without reviewoor security review | `security-checklist.md` |
| `solidity-audit-prep` | No external audit without full audit package (4 required docs) | `audit-scope-template.md` |

## Agent Summaries

| Agent | Dispatched By | Tools | Model | Mode |
|---|---|---|---|---|
| `optimizoor` | `solidity-gas-optimizer` | Read, Edit, Write, Bash, Glob, Grep | inherit | acceptEdits |
| `reviewoor` | `solidity-code-reviewer` | Read, Bash, Glob, Grep (read-only) | opus | default |

## Output Artifacts by Phase

| Phase | Artifacts Written to User's Project |
|---|---|
| planner | `docs/designs/YYYY-MM-DD-<name>-design.md`, `src/interfaces/I<Contract>.sol` |
| builder | `src/<Contract>.sol`, `test/unit/<Contract>.t.sol`, `.gas-snapshot` |
| tester | `test/fuzz/<Contract>.fuzz.t.sol`, `test/invariant/<Contract>.inv.t.sol`, `test/invariant/handlers/<Contract>Handler.sol` |
| gas-optimizer | `docs/audits/YYYY-MM-DD-<contract>-gas.md` |
| deployer | `script/Deploy<Contract>.s.sol`, `script/config/<network>.json`, `deployments/<network>/<contract>.json` |
| code-reviewer | `docs/audits/YYYY-MM-DD-<contract>-security.md` |
| audit-prep | `audit/scope.md`, `audit/protocol-overview.md`, `audit/threat-model.md`, `audit/findings-log.md` |

## Hooks Implementation Notes

- `hooks.json` wires both events in a single file. SessionStart uses matcher `"startup|resume|clear|compact"`.
- `plan-gate.sh` reads tool input from stdin as JSON, extracts `file_path`, checks `^src/.*\.sol$`.
- The plan gate is a safety net. The primary enforcement is THE RULE from `using-solidity-superpowers`.
- Both hook scripts are `chmod +x` executable.

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
- `_disableInitializers()` in implementation constructors

## Spec Folder (Read-Only)

The `spec/` folder contains the authoritative PRD for every plugin component. It is **read-only** — never modify these files. When a skill, command, agent, or hook needs to be rebuilt or updated, the spec file is the source of truth.

| Spec file | Builds |
|---|---|
| `spec/skills-prd/using-solidity-superpowers-prd.md` | `skills/using-solidity-superpowers/SKILL.md` |
| `spec/skills-prd/solidity-planner-prd.md` | `skills/solidity-planner/` |
| `spec/skills-prd/solidity-builder-prd.md` | `skills/solidity-builder/` |
| `spec/skills-prd/solidity-tester-prd.md` | `skills/solidity-tester/` |
| `spec/skills-prd/solidity-gas-optimizer-prd.md` | `skills/solidity-gas-optimizer/` |
| `spec/skills-prd/solidity-natspec-prd.md` | `skills/solidity-natspec/` |
| `spec/skills-prd/solidity-deployer-prd.md` | `skills/solidity-deployer/` |
| `spec/skills-prd/solidity-upgrader-prd.md` | `skills/solidity-upgrader/` |
| `spec/skills-prd/solidity-code-reviewer-prd.md` | `skills/solidity-code-reviewer/` |
| `spec/skills-prd/solidity-audit-prep-prd.md` | `skills/solidity-audit-prep/` |
| `spec/agents-prd/optimizoor-prd.md` | `agents/optimizoor.md` |
| `spec/agents-prd/reviewoor-prd.md` | `agents/reviewoor.md` |
| `spec/commands-prd/new-contract-prd.md` | `commands/new-contract.md` |
| `spec/commands-prd/gas-audit-prd.md` | `commands/gas-audit.md` |
| `spec/commands-prd/security-review-prd.md` | `commands/security-review.md` |
| `spec/commands-prd/audit-prep-prd.md` | `commands/audit-prep.md` |
| `spec/commands-prd/pre-deploy-prd.md` | `commands/pre-deploy.md` |
| `spec/commands-prd/pre-upgrade-prd.md` | `commands/pre-upgrade.md` |
| `spec/hooks-prd/session-start-prd.md` | `hooks/session-start.sh` + `hooks/hooks.json` |
| `spec/hooks-prd/plan-gate-prd.md` | `hooks/plan-gate.sh` + `hooks/hooks.json` |

## V2 Deferred (Do Not Implement in V1)

`solidity-systematic-debugging`, `solidity-incident-response`, standalone fork/invariant skills (merged into solidity-tester), Slither as automated hook, multi-chain deployment, formal verification (Certora/SMTChecker), Cursor/Codex/OpenCode support.
