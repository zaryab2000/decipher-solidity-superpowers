# Decipher Solidity Superpowers — Product Requirements Document (v1)

A Claude Code plugin providing an end-to-end, gate-enforced workflow for Solidity smart contract development. Inspired by the [Superpowers](https://github.com/obra/superpowers) plugin architecture — skills as mandatory workflow gates, not optional suggestions.

**Plugin name:** `decipher-solidity-superpowers`
**Target users:** Junior and senior Solidity developers working in Foundry-based projects
**Solidity version target:** 0.8.20+
**Core framework:** Foundry (forge, cast, anvil)
**Core promise:** Enforce disciplined smart contract engineering from first idea to mainnet deployment, with zero shortcuts at any phase.

---

## Table of Contents

1. [Why This Plugin Needs to Exist](#1-why-this-plugin-needs-to-exist)
2. [Architecture Overview](#2-architecture-overview)
3. [Plugin Manifest and Directory Structure](#3-plugin-manifest-and-directory-structure)
4. [The Master Orchestrator: using-solidity-superpowers](#4-the-master-orchestrator-using-solidity-superpowers)
5. [Skills — Detailed Specifications](#5-skills--detailed-specifications)
6. [Agents — Detailed Specifications](#6-agents--detailed-specifications)
7. [Commands — Detailed Specifications](#7-commands--detailed-specifications)
8. [Hooks — Detailed Specifications](#8-hooks--detailed-specifications)
9. [Build Task List](#9-build-task-list)
10. [Success Criteria](#10-success-criteria)
11. [V2 Deferred Scope](#11-v2-deferred-scope)

---

## 1. Why This Plugin Needs to Exist

AI agents writing Solidity without workflow discipline produce code that:

- Ships reentrancy vulnerabilities because nobody forced a Checks-Effects-Interactions checklist
- Has 300% higher gas costs because storage layout was never reviewed
- Fails audits because invariants were never written down
- Gets exploited because access control was "obvious" and went unreviewed
- Uses wrong proxy patterns because upgradability wasn't designed before implementation
- Has no NatSpec and no deployment docs because those were "the last step" that never happened
- Deploys with `console.log` imports still in production code
- Uses `require(condition, "string")` instead of custom errors, wasting gas on every revert

The Superpowers plugin solves the general software workflow problem. This plugin solves it for smart contracts, where the cost of mistakes is irreversible and often measured in millions of dollars. In the first half of 2025, over $2.3B in crypto was lost to exploits, with access control flaws alone causing over $1.6B in losses.

---

## 2. Architecture Overview

### 2.1 Lifecycle Gates

Every smart contract project moves through phases. Each phase has an entry gate (cannot skip in) and an exit gate (cannot leave without evidence).

```
Plan → Build → Test → Gas Optimize → NatSpec → Deploy/Upgrade → Audit Prep
```

Each phase maps to a skill. Skills have strict rules, mandatory checklists, hard gates, and named rationalizations — exactly like Superpowers skills.

### 2.2 V1 Scope Summary

| Component | Count | Items                                                                                           |
| --------- | ----- | ----------------------------------------------------------------------------------------------- |
| Skills    | 9     | planner, builder, tester, gas-optimizer, natspec, deployer, upgrader, code-reviewer, audit-prep |
| Agents    | 2     | optimizoor, reviewoor                                                                           |
| Commands  | 6     | /new-contract, /gas-audit, /security-review, /audit-prep, /pre-deploy, /pre-upgrade             |
| Hooks     | 2     | SessionStart (context injection), PreToolUse (plan gate)                                        |

### 2.3 How Skills, Agents, Commands, and Hooks Interact

```
┌─────────────────────────────────────────────────────────────────────┐
│ SESSION START                                                       │
│  Hook: session-start.sh injects using-solidity-superpowers          │
│  (THE RULE: always check skills before ANY response)                │
└───────────┬─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│ USER MESSAGE                                                        │
│  Hook: plan-gate.sh intercepts Solidity implementation intent       │
│  without an approved plan → redirects to solidity-planner           │
└───────────┬─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SKILL INVOCATION                                                    │
│  Agent checks current phase, invokes the correct skill              │
│  Skill enforces its strict rules, runs its checklist                │
│  Some skills dispatch sub-agents (optimizoor, reviewoor)            │
└───────────┬─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│ COMMANDS (user-triggered shortcuts)                                 │
│  /new-contract → solidity-planner                                   │
│  /gas-audit → solidity-gas-optimizer → optimizoor agent             │
│  /security-review → solidity-code-reviewer → reviewoor agent        │
│  /audit-prep → solidity-audit-prep                                  │
│  /pre-deploy → solidity-deployer                                    │
│  /pre-upgrade → solidity-upgrader                                   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Plugin Manifest and Directory Structure

### 3.1 Directory Layout

```
decipher-solidity-superpowers/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── hooks/
│   ├── hooks.json
│   ├── session-start.sh
│   └── plan-gate.sh
├── skills/
│   ├── using-solidity-superpowers/
│   │   └── SKILL.md                          # Master orchestrator (THE RULE)
│   ├── solidity-planner/
│   │   ├── SKILL.md
│   │   └── brainstorming-questions.md
│   ├── solidity-builder/
│   │   ├── SKILL.md
│   │   └── foundry-test-patterns.md
│   ├── solidity-tester/
│   │   ├── SKILL.md
│   │   └── invariant-testing-guide.md
│   ├── solidity-gas-optimizer/
│   │   ├── SKILL.md
│   │   └── gas-checklist.md
│   ├── solidity-natspec/
│   │   ├── SKILL.md
│   │   └── natspec-templates.md
│   ├── solidity-deployer/
│   │   ├── SKILL.md
│   │   └── deployment-checklist.md
│   ├── solidity-upgrader/
│   │   ├── SKILL.md
│   │   └── proxy-pattern-guide.md
│   ├── solidity-code-reviewer/
│   │   ├── SKILL.md
│   │   └── security-checklist.md
│   └── solidity-audit-prep/
│       ├── SKILL.md
│       └── audit-scope-template.md
├── agents/
│   ├── optimizoor.md
│   └── reviewoor.md
├── commands/
│   ├── new-contract.md
│   ├── gas-audit.md
│   ├── security-review.md
│   ├── audit-prep.md
│   ├── pre-deploy.md
│   └── pre-upgrade.md
└── docs/
    └── README.md
```

### 3.2 plugin.json

```json
{
  "name": "decipher-solidity-superpowers",
  "description": "End-to-end Solidity smart contract workflow: planning, TDD with Foundry, gas optimization, security review, deployment, upgrades, and audit preparation",
  "version": "1.0.0",
  "author": {
    "name": "Zaryab"
  },
  "repository": "https://github.com/zaryab2000/decipher-solidity-superpowers",
  "license": "MIT",
  "keywords": ["solidity", "foundry", "smart-contracts", "tdd", "security", "gas", "audit", "defi", "evm"]
}
```

### 3.3 marketplace.json

```json
{
  "plugins": [
    {
      "name": "decipher-solidity-superpowers",
      "description": "End-to-end Solidity smart contract workflow enforcement for Claude Code",
      "repository": "https://github.com/zaryab2000/decipher-solidity-superpowers"
    }
  ]
}
```

---

## Important NOTE:
- THE DETAILED INSTRUCTIONS ( PRD ) for building any of the skills, commands , hooks or agents needed for this plugin is in the respective file path inside spec/ folder.
for instance detailed prd to build the solidity-builder SKILL is in spec/skills-prd/solidity-builder-prd.md FILE.
ALWAYS TAKE INSTRUCTIONS of HOW TO BUILD Something in the main plugin, by going to its respective FILE in the spec/ folder.
This FILE just acts as a pointer to the respective PRD files.

## 4. The Master Orchestrator: using-solidity-superpowers

**File:** `skills/using-solidity-superpowers/SKILL.md`

This is the foundational skill injected at session start via the `session-start.sh` hook. It functions identically to the `using-superpowers` skill in the parent Superpowers plugin. It defines THE RULE and ensures the agent always checks for applicable skills before responding.

**Skill inventory table** — the agent's routing map:

| Skill                    | Trigger Signal                                                                            |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| `solidity-planner`       | User wants to build/design/create any contract, interface, library, or protocol component |
| `solidity-builder`       | Plan is approved, interfaces exist, implementation is next                                |
| `solidity-tester`        | Adding fuzz tests, invariant tests, or fork tests beyond unit tests                       |
| `solidity-gas-optimizer` | Tests pass, gas review needed before deploy                                               |
| `solidity-natspec`       | Any function, error, or event is being committed                                          |
| `solidity-deployer`      | Any deployment to any network (testnet or mainnet)                                        |
| `solidity-upgrader`      | Any proxy upgrade is being planned or executed                                            |
| `solidity-code-reviewer` | Contract implementation is complete, needs review                                         |
| `solidity-audit-prep`    | Code is feature-complete, external audit is coming                                        |

> **Full specification:** `spec/skills-prd/using-solidity-superpowers-prd.md`

---

## 5. Skills — Detailed Specifications

Each skill follows a consistent structure: when it activates, the strict rule, hard gate, mandatory checklist, Solidity-specific guidelines, forge commands, output artifacts, terminal state, and blocked rationalizations.

> **Note to coding agent:** Each skill's full implementation specification lives in its dedicated PRD file. The sections below provide the summary context and routing information. Read the linked PRD file before implementing each skill.

---

### Skill 1: `solidity-planner`

**File:** `skills/solidity-planner/SKILL.md`
**Supporting file:** `skills/solidity-planner/brainstorming-questions.md`

**When:** Before writing ANY contract, interface, library, or significant function. Entry point for all new Solidity work.

**The strict rule:**
```
NO CONTRACT CODE BEFORE A PLAN IS APPROVED
```

**Hard Gate:** No `.sol` files, no scaffolding, no function signatures until the design is presented to the user and explicitly approved.

**Terminal State:** Only valid exit is invoking `solidity-builder`. Plan must be approved, design doc written, and interfaces committed.

> **Full specification:** `spec/skills-prd/solidity-planner-prd.md`

---

### Skill 2: `solidity-builder`

**File:** `skills/solidity-builder/SKILL.md`
**Supporting file:** `skills/solidity-builder/foundry-test-patterns.md`

**When:** After the plan is approved and interfaces are committed. Before any implementation code.

**The strict rule:**
```
NO PRODUCTION SOLIDITY WITHOUT A FAILING FORGE TEST FIRST
```

**Hard Gate:** No implementation `.sol` file may be created without a corresponding test file containing at least one failing test for the function being implemented.

**Terminal State:** Exit to `solidity-tester` (fuzz/invariant tests), `solidity-natspec` (documentation), or `solidity-gas-optimizer` (after all tests pass).

> **Full specification:** `spec/skills-prd/solidity-builder-prd.md`

---

### Skill 3: `solidity-tester`

**File:** `skills/solidity-tester/SKILL.md`
**Supporting file:** `skills/solidity-tester/invariant-testing-guide.md`

**When:** During or after build, when the contract handles value (ETH, tokens, shares) and needs testing beyond unit tests.

**The strict rule:**
```
EVERY CONTRACT WITH VALUE-HANDLING LOGIC MUST HAVE FUZZ AND INVARIANT TESTS
```

**Hard Gate:** No contract that handles deposits, withdrawals, minting, burning, swapping, or lending can exit the testing phase without fuzz tests and invariant tests.

**Terminal State:** Exit to `solidity-gas-optimizer` (after all tests pass), `solidity-natspec` (documentation), or `solidity-code-reviewer` (security review).

> **Full specification:** `spec/skills-prd/solidity-tester-prd.md`

---

### Skill 4: `solidity-gas-optimizer`

**File:** `skills/solidity-gas-optimizer/SKILL.md`
**Supporting file:** `skills/solidity-gas-optimizer/gas-checklist.md`

**When:** After all tests pass for a contract. Before security review or deployment.

**The strict rule:**
```
NO DEPLOYMENT WITHOUT A GAS AUDIT REPORT IN docs/audits/
```

**Hard Gate:** Dispatches the `optimizoor` agent to run the full 8-category checklist. No deployment proceeds without the gas audit report.

**8 Categories:** Storage layout, function visibility, calldata vs memory, loop optimization, unchecked arithmetic, custom errors, compiler configuration, events vs storage.

**Terminal State:** Exit to `solidity-code-reviewer` or `solidity-deployer`.

> **Full specification:** `spec/skills-prd/solidity-gas-optimizer-prd.md`

---

### Skill 5: `solidity-natspec`

**File:** `skills/solidity-natspec/SKILL.md`
**Supporting file:** `skills/solidity-natspec/natspec-templates.md`

**When:** After GREEN phase in TDD, before committing any function. Runs continuously during development.

**The strict rule:**
```
NO COMMIT WITHOUT NATSPEC ON EVERY PUBLIC AND EXTERNAL FUNCTION, CUSTOM ERROR, AND EVENT
```

**Hard Gate:** Functions without NatSpec cannot be committed. Applies on every commit, not just at "the docs phase."

**Terminal State:** Runs continuously — does not block transitions between other skills.

> **Full specification:** `spec/skills-prd/solidity-natspec-prd.md`

---

### Skill 6: `solidity-deployer`

**File:** `skills/solidity-deployer/SKILL.md`
**Supporting file:** `skills/solidity-deployer/deployment-checklist.md`

**When:** Before any deployment to any network (testnet or mainnet).

**The strict rule:**
```
NO MANUAL DEPLOYMENTS. ALL DEPLOYMENTS VIA FORGE SCRIPTS WITH FULL ON-CHAIN VERIFICATION.
```

**Hard Gate:** No `forge create` or manual contract deployment. All deployments must go through a `script/Deploy<ContractName>.s.sol` script.

**Terminal State:** Exit to `solidity-upgrader` (if future upgrades planned) or `solidity-audit-prep`.

> **Full specification:** `spec/skills-prd/solidity-deployer-prd.md`

---

### Skill 7: `solidity-upgrader`

**File:** `skills/solidity-upgrader/SKILL.md`
**Supporting file:** `skills/solidity-upgrader/proxy-pattern-guide.md`

**When:** Before implementing or executing any proxy upgrade.

**The strict rule:**
```
NO UPGRADE WITHOUT STORAGE LAYOUT DIFF VERIFICATION AND FORK TEST CONFIRMATION
```

**Hard Gate:** No upgrade transaction is submitted until the storage layout diff is clean and the upgrade has been tested on a fork.

**Terminal State:** Exit to `solidity-deployer` (upgrade deployment) or `solidity-code-reviewer` (review of new implementation).

> **Full specification:** `spec/skills-prd/solidity-upgrader-prd.md`

---

### Skill 8: `solidity-code-reviewer`

**File:** `skills/solidity-code-reviewer/SKILL.md`
**Supporting file:** `skills/solidity-code-reviewer/security-checklist.md`

**When:** After completing any contract implementation, before marking work as done.

**The strict rule:**
```
NO CONTRACT IS COMPLETE WITHOUT A REVIEWOOR SECURITY REVIEW
```

**Hard Gate:** Dispatches the `reviewoor` agent. All Critical and High findings must be resolved before proceeding.

**Severity blocking:** Critical blocks everything. High blocks merge. Medium blocks deploy.

**Terminal State:** After all Critical and High findings are resolved, exit to `solidity-gas-optimizer`, `solidity-deployer`, or `solidity-audit-prep`.

> **Full specification:** `spec/skills-prd/solidity-code-reviewer-prd.md`

---

### Skill 9: `solidity-audit-prep`

**File:** `skills/solidity-audit-prep/SKILL.md`
**Supporting file:** `skills/solidity-audit-prep/audit-scope-template.md`

**When:** Code is feature-complete, internally reviewed, all findings resolved. Before external audit engagement.

**The strict rule:**
```
NO EXTERNAL AUDIT WITHOUT A COMPLETE AUDIT PACKAGE
```

**Hard Gate:** The audit package (4 documents + coverage report) must exist before engaging auditors:
1. `docs/audit/scope.md` — in-scope files, commit hash, dependencies
2. `docs/audit/protocol.md` — actors, state machine, invariants, trust assumptions
3. `docs/audit/threat-model.md` — attacker goals, capabilities, vectors
4. `docs/audit/findings-log.md` — internal findings with resolutions and regression tests
5. Coverage report — `forge coverage --report lcov`

**Terminal State:** Final skill in the lifecycle. After audit prep is complete, the project is ready for external audit engagement.

> **Full specification:** `spec/skills-prd/solidity-audit-prep-prd.md`

---

## 6. Agents — Detailed Specifications

### Agent: `optimizoor`

**File:** `agents/optimizoor.md`

**Role:** Gas optimization specialist. Dispatched by `solidity-gas-optimizer` skill. Runs the full 8-category gas checklist autonomously, applies fixes, and produces a structured report at `docs/audits/YYYY-MM-DD-<contract>-gas.md`.

**Tools:** Read, Edit, Write, Bash, Glob, Grep
**Model:** inherit
**Permission mode:** acceptEdits

> **Full specification:** `spec/agents-prd/optimizoor-prd.md`

---

### Agent: `reviewoor`

**File:** `agents/reviewoor.md`

**Role:** Security-focused code reviewer. Dispatched by `solidity-code-reviewer` skill. Performs a two-stage review: spec compliance, then security analysis. Produces structured findings with severity ratings.

**Tools:** Read, Bash, Glob, Grep
**Model:** opus
**Permission mode:** default

> **Full specification:** `spec/agents-prd/reviewoor-prd.md`

---

## 7. Commands — Detailed Specifications

All commands follow the Superpowers pattern: they set `disable-model-invocation: true` and delegate entirely to the corresponding skill.

| Command            | Delegates To             | When to Use                                                       |
| ------------------ | ------------------------ | ----------------------------------------------------------------- |
| `/new-contract`    | `solidity-planner`       | Starting design of any new contract, interface, or library        |
| `/gas-audit`       | `solidity-gas-optimizer` | Tests pass, ready for gas optimization report before deployment   |
| `/security-review` | `solidity-code-reviewer` | Contract implementation complete, need structured security review |
| `/audit-prep`      | `solidity-audit-prep`    | Code is feature-complete, preparing for external audit            |
| `/pre-deploy`      | `solidity-deployer`      | Before any deployment to testnet or mainnet                       |
| `/pre-upgrade`     | `solidity-upgrader`      | Before any proxy upgrade                                          |

> **Full specifications:**
> - `spec/commands-prd/new-contract-prd.md`
> - `spec/commands-prd/gas-audit-prd.md`
> - `spec/commands-prd/security-review-prd.md`
> - `spec/commands-prd/audit-prep-prd.md`
> - `spec/commands-prd/pre-deploy-prd.md`
> - `spec/commands-prd/pre-upgrade-prd.md`

---

## 8. Hooks — Detailed Specifications

### Hook 1: Session Start Hook

**Files:** `hooks/hooks.json` + `hooks/session-start.sh`
**Event:** `SessionStart`

**Purpose:** Inject the `using-solidity-superpowers` skill content as `additionalContext` before the agent's first turn. This ensures the agent knows THE RULE and the skill inventory from the very first message.

**Key implementation constraint:** Must use `async: false`. If the hook is async, it may not complete before the model's first response — the agent would answer the first message without skill context.

> **Full specification:** `spec/hooks-prd/session-start-prd.md`

---

### Hook 2: Plan Gate Hook

**Files:** `hooks/hooks.json` + `hooks/plan-gate.sh`
**Event:** `PreToolUse` — intercepts before Write or Edit tools on `.sol` files

**Purpose:** Catch cases where the agent tries to write Solidity code to `src/` without a design doc in `docs/designs/`. Safety net behind THE RULE — fires when session context is lost or the user explicitly tries to bypass planning.

**Key implementation constraint:** Also uses `async: false` — must block the tool call before it executes, not after.

> **Full specification:** `spec/hooks-prd/plan-gate-prd.md`

---

## 9. Build Task List

### Phase 0: Scaffold

- [ ] Create repo `decipher-solidity-superpowers`
- [ ] Create `.claude-plugin/plugin.json` with metadata
- [ ] Create `.claude-plugin/marketplace.json`
- [ ] Create `hooks/hooks.json` with both SessionStart and PreToolUse entries
- [ ] Write `hooks/session-start.sh` — inject using-solidity-superpowers skill
- [ ] Write `hooks/plan-gate.sh` — intercept .sol writes without design docs
- [ ] Make both hook scripts executable (`chmod +x`)
- [ ] Create directory structure: `skills/`, `agents/`, `commands/`, `docs/`
- [ ] Write `skills/using-solidity-superpowers/SKILL.md` — THE RULE, skill inventory, blocked rationalizations
- [ ] **Verify:** Start Claude Code session, confirm SessionStart hook fires, confirm THE RULE is in context

### Phase 1: Planning Skill

- [ ] Write `skills/solidity-planner/SKILL.md` — per `spec/skills-prd/solidity-planner-prd.md`
- [ ] Write `skills/solidity-planner/brainstorming-questions.md`
- [ ] Write `commands/new-contract.md` — per `spec/commands-prd/new-contract-prd.md`
- [ ] **Pressure test:** Ask Claude to "write a simple ERC-20 token" — verify it stops, runs planner, produces design doc and interfaces before any .sol code

### Phase 2: Build and Test Skills

- [ ] Write `skills/solidity-builder/SKILL.md` — per `spec/skills-prd/solidity-builder-prd.md`
- [ ] Write `skills/solidity-builder/foundry-test-patterns.md`
- [ ] Write `skills/solidity-tester/SKILL.md` — per `spec/skills-prd/solidity-tester-prd.md`
- [ ] Write `skills/solidity-tester/invariant-testing-guide.md`
- [ ] **Pressure test:** Ask Claude to implement a vault — verify it writes failing tests before implementation code

### Phase 3: Quality Skills

- [ ] Write `skills/solidity-natspec/SKILL.md` — per `spec/skills-prd/solidity-natspec-prd.md`
- [ ] Write `skills/solidity-natspec/natspec-templates.md`
- [ ] Write `skills/solidity-gas-optimizer/SKILL.md` — per `spec/skills-prd/solidity-gas-optimizer-prd.md`
- [ ] Write `skills/solidity-gas-optimizer/gas-checklist.md`
- [ ] Write `agents/optimizoor.md` — per `spec/agents-prd/optimizoor-prd.md`
- [ ] Write `agents/reviewoor.md` — per `spec/agents-prd/reviewoor-prd.md`
- [ ] Write `skills/solidity-code-reviewer/SKILL.md` — per `spec/skills-prd/solidity-code-reviewer-prd.md`
- [ ] Write `skills/solidity-code-reviewer/security-checklist.md`
- [ ] Write `commands/gas-audit.md` — per `spec/commands-prd/gas-audit-prd.md`
- [ ] Write `commands/security-review.md` — per `spec/commands-prd/security-review-prd.md`
- [ ] **Pressure test:** Complete a contract with a known reentrancy bug — verify reviewoor catches it

### Phase 4: Deployment and Upgrade Skills

- [ ] Write `skills/solidity-deployer/SKILL.md` — per `spec/skills-prd/solidity-deployer-prd.md`
- [ ] Write `skills/solidity-deployer/deployment-checklist.md`
- [ ] Write `skills/solidity-upgrader/SKILL.md` — per `spec/skills-prd/solidity-upgrader-prd.md`
- [ ] Write `skills/solidity-upgrader/proxy-pattern-guide.md`
- [ ] Write `commands/pre-deploy.md` — per `spec/commands-prd/pre-deploy-prd.md`
- [ ] Write `commands/pre-upgrade.md` — per `spec/commands-prd/pre-upgrade-prd.md`
- [ ] **Pressure test:** Simulate a deployment flow — verify checklist is mandatory before forge script runs

### Phase 5: Audit Prep

- [ ] Write `skills/solidity-audit-prep/SKILL.md` — per `spec/skills-prd/solidity-audit-prep-prd.md`
- [ ] Write `skills/solidity-audit-prep/audit-scope-template.md`
- [ ] Write `commands/audit-prep.md` — per `spec/commands-prd/audit-prep-prd.md`

### Phase 6: End-to-End Test and Polish

- [ ] End-to-end test with a realistic ERC-4626 vault:
  - `/new-contract` → design doc → interfaces → `solidity-builder` TDD → `solidity-tester` invariants → `solidity-natspec` → `solidity-gas-optimizer` (optimizoor) → `solidity-code-reviewer` (reviewoor) → `/pre-deploy`
  - Verify every skill fires in the correct order
  - Verify no skill can be skipped by direct instruction
  - Verify all output artifacts are created in the correct locations
- [ ] Fix any gaps discovered during end-to-end test
- [ ] Write `docs/README.md` with installation instructions and quick start guide
- [ ] Tag v1.0.0

---

## 10. Success Criteria

The plugin is complete when ALL of the following are true:

1. **Plan gate works:** A developer cannot write a contract without first producing a design document and committed interfaces.
2. **TDD enforced:** No implementation code exists without a failing test preceding it.
3. **NatSpec enforced:** No function can be committed without NatSpec on public/external functions, errors, and events.
4. **Gas audit runs:** The optimizoor agent catches at minimum: storage packing issues, string reverts, public-vs-external visibility, uncached array lengths.
5. **Security review runs:** The reviewoor agent catches at minimum: missing CEI pattern, missing access control, `tx.origin` usage, missing SafeERC20, unchecked external call returns.
6. **Deploy gate works:** No deployment proceeds without the full pre-deployment checklist completing.
7. **Upgrade gate works:** No upgrade proceeds without storage layout diff verification.
8. **All 6 commands** trigger the correct skill with zero extra steps.
9. **SessionStart hook** injects THE RULE before the first agent turn in every session.
10. **Plan gate hook** catches attempts to write .sol files without a design doc.

---

## 11. V2 Deferred Scope

The following were considered for v1 and deliberately removed to keep scope achievable:

- `solidity-systematic-debugging` — debugging guide specific to Solidity traces and `forge test -vvvv` output analysis
- `solidity-incident-response` — emergency response runbook (pause, identify, fix, upgrade cycle)
- `solidity-deployment-scripting` — advanced multi-chain deployment orchestration
- `solidity-fork-testing` — standalone fork testing skill with mainnet state management (merged into `solidity-tester`)
- `solidity-invariant-tester` — standalone invariant testing skill (merged into `solidity-tester`)
- `solidity-receiving-review` — how to respond to reviewer feedback systematically
- `solidity-verification-before-completion` — final verification gate (merged into `solidity-deployer`)
- Multi-platform support (Cursor, Codex, OpenCode) — Claude Code only for v1
- Slither integration as automated hook — v1 requires manual Slither runs; v2 could add a PostToolUse hook
- Formal verification integration (Certora, SMTChecker) — requires additional tooling setup
- Multi-chain deployment support — v1 targets single-chain (Ethereum mainnet + testnets)
