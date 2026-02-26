# MAIN_INSTRUCTION.md — Project Build Orchestrator

This file orchestrates the complete build of the `decipher-solidity-superpowers` Claude Code plugin. It is designed to be run by a coding agent in bypass mode from the `dev-v0` branch.

**Repository:** https://github.com/zaryab2000/decipher-solidity-superpowers
**Developer:** Zaryab
**Current branch:** `dev-v0` (already exists locally and on remote)

---

## CRITICAL RULES — READ BEFORE DOING ANYTHING

1. **NEVER push to GitHub.** All commits are local only. Zaryab reviews and pushes manually.
2. **NEVER create the GitHub repository.** It already exists.
3. **The `spec/` folder contains the full PRD for every skill, command, agent, and hook.** Do NOT invent specifications. Read the corresponding `spec/` file and follow it exactly.
4. **Do NOT write any content that is not specified in the PRDs.** If a PRD says the SKILL.md should contain X, write X. Do not add Y.
5. **Do NOT modify anything in the `spec/` folder.** It is read-only reference material.
6. **Do NOT modify `BASE_PRD.md`.** It is read-only reference material.
7. **Do NOT modify `CLAUDE.md` or `README.md`.** They already exist.

---

## EXECUTION ORDER

```
PHASE 0: Scaffold (run directly on dev-v0)
    │
    ▼
Create 4 worktree branches from dev-v0
    │
    ▼
PHASE 1: Launch Worktrees 1, 2, 3 IN PARALLEL (skills only)
    │    Worktree 1: Skills — Planning & Building
    │    Worktree 2: Skills — Quality & Security
    │    Worktree 3: Skills — Deployment
    │
    ▼
PHASE 2: Launch Worktree 4 AFTER skills are done (commands + agents)
    │    Worktree 4: All commands + all agents
    │
    ▼
DONE — Zaryab reviews, merges each worktree into dev-v0, creates PR to main
```

---

## PHASE 0 — Scaffold (Run on `dev-v0`)

Phase 0 creates the core plugin infrastructure that all worktrees depend on. This runs directly on `dev-v0` before any worktrees are created.

### Step 0.1: Read Project Context

Before doing anything, read `BASE_PRD.md` to understand the full project context — what the plugin is, the lifecycle gates, how skills/agents/commands/hooks interact, and the v1 scope.

### Step 0.2: Create the Full Directory Structure

```bash
# Plugin metadata
mkdir -p .claude-plugin

# Hooks
mkdir -p hooks

# All 10 skill directories
mkdir -p skills/using-solidity-superpowers
mkdir -p skills/solidity-planner
mkdir -p skills/solidity-builder
mkdir -p skills/solidity-tester
mkdir -p skills/solidity-gas-optimizer
mkdir -p skills/solidity-natspec
mkdir -p skills/solidity-deployer
mkdir -p skills/solidity-upgrader
mkdir -p skills/solidity-code-reviewer
mkdir -p skills/solidity-audit-prep

# Agents
mkdir -p agents

# Commands
mkdir -p commands

# Docs
mkdir -p docs
```

### Step 0.3: Create plugin.json

Create `.claude-plugin/plugin.json` with exactly this content (from `BASE_PRD.md` Section 3.2):

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

### Step 0.4: Create marketplace.json

Create `.claude-plugin/marketplace.json` with exactly this content (from `BASE_PRD.md` Section 3.3):

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

### Step 0.5: Create hooks.json

Read `spec/hooks-prd/session-start-prd.md` AND `spec/hooks-prd/plan-gate-prd.md` for the full hook specifications.

Create `hooks/hooks.json` that registers both hooks:
- A `SessionStart` hook pointing to `session-start.sh` with `async: false`
- A `PreToolUse` hook pointing to `plan-gate.sh` with `async: false` and matcher for `Write|Edit`

Follow the exact JSON structure specified in the hook PRDs.

### Step 0.6: Create session-start.sh

Read `spec/hooks-prd/session-start-prd.md` for the complete specification.

Create `hooks/session-start.sh` that:
- Reads `skills/using-solidity-superpowers/SKILL.md`
- Escapes the content for JSON using bash parameter substitution (NOT character-by-character loops)
- Outputs `{"additionalContext": "<escaped content>"}`

Make it executable: `chmod +x hooks/session-start.sh`

### Step 0.7: Create plan-gate.sh

Read `spec/hooks-prd/plan-gate-prd.md` for the complete specification.

Create `hooks/plan-gate.sh` that:
- Reads the tool input from stdin
- Checks if the target file is a `.sol` file in `src/`
- If no design doc exists in `docs/designs/`, injects a `<HARD-GATE>` reminder
- Otherwise outputs `{}`

Make it executable: `chmod +x hooks/plan-gate.sh`

### Step 0.8: Create using-solidity-superpowers/SKILL.md

Read `spec/skills-prd/using-solidity-superpowers-prd.md` for the complete specification.

Create `skills/using-solidity-superpowers/SKILL.md` — the master orchestrator skill that defines THE RULE, the skill inventory table, blocked rationalizations, and the decision process flow.

### Step 0.9: Commit Phase 0

```bash
git add -A
git commit -m "Phase 0: scaffold plugin structure, hooks, and master orchestrator"
```

**Do NOT push.** Local commit only.

### Step 0.10: Create 4 Worktree Branches

```bash
git worktree add ../dss-skills-planning   -b agent/skills-planning
git worktree add ../dss-skills-quality    -b agent/skills-quality
git worktree add ../dss-skills-deployment -b agent/skills-deployment
git worktree add ../dss-commands-agents   -b agent/commands-agents
```

All 4 branches are created from `dev-v0` and contain the Phase 0 scaffold.

---

## PHASE 1 — Skills Worktrees (Launch All 3 in Parallel)

Worktrees 1, 2, and 3 work on skills ONLY. They write to the `skills/` folder exclusively. Since each worktree writes to different subdirectories within `skills/`, there are zero merge conflicts.

---

### Worktree 1: Skills — Planning & Building

**Branch:** `agent/skills-planning`
**Working directory:** `../dss-skills-planning`

**Files to create (6 total):**

| #   | File                                                 | PRD Source                                     |
| --- | ---------------------------------------------------- | ---------------------------------------------- |
| 1   | `skills/solidity-planner/SKILL.md`                   | Read `spec/skills-prd/solidity-planner-prd.md` |
| 2   | `skills/solidity-planner/brainstorming-questions.md` | Read `spec/skills-prd/solidity-planner-prd.md` |
| 3   | `skills/solidity-builder/SKILL.md`                   | Read `spec/skills-prd/solidity-builder-prd.md` |
| 4   | `skills/solidity-builder/foundry-test-patterns.md`   | Read `spec/skills-prd/solidity-builder-prd.md` |
| 5   | `skills/solidity-tester/SKILL.md`                    | Read `spec/skills-prd/solidity-tester-prd.md`  |
| 6   | `skills/solidity-tester/invariant-testing-guide.md`  | Read `spec/skills-prd/solidity-tester-prd.md`  |

**Instructions for the agent:**

1. Read `BASE_PRD.md` to understand the project context.
2. For each skill, read its dedicated PRD file from `spec/skills-prd/` BEFORE writing anything.
3. The PRD tells you exactly what the SKILL.md and supporting file should contain. Follow it.
4. Write ONLY to the `skills/` folder. Do NOT touch `commands/`, `agents/`, `hooks/`, or any other directory.
5. When all 6 files are created, commit locally:
   ```bash
   git add skills/solidity-planner/ skills/solidity-builder/ skills/solidity-tester/
   git commit -m "feat(skills): add planner, builder, tester skills with supporting files"
   ```
6. Do NOT push. Do NOT create pull requests.

---

### Worktree 2: Skills — Quality & Security

**Branch:** `agent/skills-quality`
**Working directory:** `../dss-skills-quality`

**Files to create (8 total):**

| #   | File                                                  | PRD Source                                           |
| --- | ----------------------------------------------------- | ---------------------------------------------------- |
| 1   | `skills/solidity-gas-optimizer/SKILL.md`              | Read `spec/skills-prd/solidity-gas-optimizer-prd.md` |
| 2   | `skills/solidity-gas-optimizer/gas-checklist.md`      | Read `spec/skills-prd/solidity-gas-optimizer-prd.md` |
| 3   | `skills/solidity-natspec/SKILL.md`                    | Read `spec/skills-prd/solidity-natspec-prd.md`       |
| 4   | `skills/solidity-natspec/natspec-templates.md`        | Read `spec/skills-prd/solidity-natspec-prd.md`       |
| 5   | `skills/solidity-code-reviewer/SKILL.md`              | Read `spec/skills-prd/solidity-code-reviewer-prd.md` |
| 6   | `skills/solidity-code-reviewer/security-checklist.md` | Read `spec/skills-prd/solidity-code-reviewer-prd.md` |
| 7   | `skills/solidity-audit-prep/SKILL.md`                 | Read `spec/skills-prd/solidity-audit-prep-prd.md`    |
| 8   | `skills/solidity-audit-prep/audit-scope-template.md`  | Read `spec/skills-prd/solidity-audit-prep-prd.md`    |

**Instructions for the agent:**

1. Read `BASE_PRD.md` to understand the project context.
2. For each skill, read its dedicated PRD file from `spec/skills-prd/` BEFORE writing anything.
3. The PRD tells you exactly what the SKILL.md and supporting file should contain. Follow it.
4. Write ONLY to the `skills/` folder. Do NOT touch `commands/`, `agents/`, `hooks/`, or any other directory.
5. When all 8 files are created, commit locally:
   ```bash
   git add skills/solidity-gas-optimizer/ skills/solidity-natspec/ skills/solidity-code-reviewer/ skills/solidity-audit-prep/
   git commit -m "feat(skills): add gas-optimizer, natspec, code-reviewer, audit-prep skills with supporting files"
   ```
6. Do NOT push. Do NOT create pull requests.

---

### Worktree 3: Skills — Deployment

**Branch:** `agent/skills-deployment`
**Working directory:** `../dss-skills-deployment`

**Files to create (4 total):**

| #   | File                                               | PRD Source                                      |
| --- | -------------------------------------------------- | ----------------------------------------------- |
| 1   | `skills/solidity-deployer/SKILL.md`                | Read `spec/skills-prd/solidity-deployer-prd.md` |
| 2   | `skills/solidity-deployer/deployment-checklist.md` | Read `spec/skills-prd/solidity-deployer-prd.md` |
| 3   | `skills/solidity-upgrader/SKILL.md`                | Read `spec/skills-prd/solidity-upgrader-prd.md` |
| 4   | `skills/solidity-upgrader/proxy-pattern-guide.md`  | Read `spec/skills-prd/solidity-upgrader-prd.md` |

**Instructions for the agent:**

1. Read `BASE_PRD.md` to understand the project context.
2. For each skill, read its dedicated PRD file from `spec/skills-prd/` BEFORE writing anything.
3. The PRD tells you exactly what the SKILL.md and supporting file should contain. Follow it.
4. Write ONLY to the `skills/` folder. Do NOT touch `commands/`, `agents/`, `hooks/`, or any other directory.
5. When all 4 files are created, commit locally:
   ```bash
   git add skills/solidity-deployer/ skills/solidity-upgrader/
   git commit -m "feat(skills): add deployer, upgrader skills with supporting files"
   ```
6. Do NOT push. Do NOT create pull requests.

---

## PHASE 2 — Commands & Agents Worktree (Launch AFTER Phase 1)

Worktree 4 writes to `commands/` and `agents/` folders exclusively. It runs after skills worktrees are done (or can run in parallel since it writes to entirely different folders — but sequencing ensures the skill files it references exist for validation).

---

### Worktree 4: Commands + Agents

**Branch:** `agent/commands-agents`
**Working directory:** `../dss-commands-agents`

**Files to create (8 total):**

| #   | File                          | PRD Source                                      |
| --- | ----------------------------- | ----------------------------------------------- |
| 1   | `commands/new-contract.md`    | Read `spec/commands-prd/new-contract-prd.md`    |
| 2   | `commands/gas-audit.md`       | Read `spec/commands-prd/gas-audit-prd.md`       |
| 3   | `commands/security-review.md` | Read `spec/commands-prd/security-review-prd.md` |
| 4   | `commands/audit-prep.md`      | Read `spec/commands-prd/audit-prep-prd.md`      |
| 5   | `commands/pre-deploy.md`      | Read `spec/commands-prd/pre-deploy-prd.md`      |
| 6   | `commands/pre-upgrade.md`     | Read `spec/commands-prd/pre-upgrade-prd.md`     |
| 7   | `agents/optimizoor.md`        | Read `spec/agents-prd/optimizoor-prd.md`        |
| 8   | `agents/reviewoor.md`         | Read `spec/agents-prd/reviewoor-prd.md`         |

**Instructions for the agent:**

1. Read `BASE_PRD.md` to understand the project context.
2. For each command, read its dedicated PRD file from `spec/commands-prd/` BEFORE writing anything.
3. For each agent, read its dedicated PRD file from `spec/agents-prd/` BEFORE writing anything.
4. The PRD tells you exactly what each file should contain. Follow it.
5. Write ONLY to `commands/` and `agents/` folders. Do NOT touch `skills/`, `hooks/`, or any other directory.
6. When all 8 files are created, commit locally:
   ```bash
   git add commands/ agents/
   git commit -m "feat(commands-agents): add all 6 commands and both agents (optimizoor, reviewoor)"
   ```
7. Do NOT push. Do NOT create pull requests.

---
