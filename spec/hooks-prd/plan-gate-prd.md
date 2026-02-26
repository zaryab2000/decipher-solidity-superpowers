# Hook PRD: Plan Gate Hook

**Files:** `hooks/hooks.json` (additional entry) + `hooks/plan-gate.sh`

**Event:** `PreToolUse` — fires before Write or Edit tool calls

---

## Purpose

Catch cases where the agent tries to write Solidity code in `src/` without having invoked the planner first. This is the safety net behind THE RULE — it handles edge cases where session context was lost or the user explicitly tried to bypass planning.

---

## hooks.json Entry (Merged with Session Start)

The complete `hooks/hooks.json` with both hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
            "async": false
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/plan-gate.sh",
            "async": false
          }
        ]
      }
    ]
  }
}
```

---

## plan-gate.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# This hook fires before any Write or Edit tool use.
# It checks if the target file is a .sol file and injects a reminder
# to use the planner if no design doc exists.

# The tool input is available via stdin as JSON
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"file_path"\s*:\s*"//' | sed 's/"//')

# Check if it's a .sol file in src/ (not test/ or script/)
if echo "$FILE_PATH" | grep -qE '\.sol$' && echo "$FILE_PATH" | grep -qE '^src/'; then
  # Check if a design doc exists for this project
  if [ ! -d "docs/designs" ] || [ -z "$(ls -A docs/designs/ 2>/dev/null)" ]; then
    cat <<'EOF'
{"additionalContext": "<HARD-GATE>\nA Solidity implementation file write was detected but no design document exists in docs/designs/.\nYou MUST invoke the solidity-planner skill before writing any .sol file in src/.\nIf a plan already exists and was approved, invoke solidity-builder instead.\nNo exceptions.\n</HARD-GATE>"}
EOF
    exit 0
  fi
fi

# If not a .sol file or design doc exists, proceed normally
echo '{}'
```

---

## Post-Creation Step

Make executable: `chmod +x hooks/plan-gate.sh`

---

## Detection Logic

| Condition | Action |
|---|---|
| Target file matches `src/*.sol` AND `docs/designs/` is absent or empty | Inject hard-gate block, redirect to planner |
| Target file matches `src/*.sol` AND `docs/designs/` exists and has files | Proceed normally |
| Target file is `test/*.sol` or `script/*.sol` | Proceed normally (not a production source file) |
| Target file is any non-`.sol` file | Proceed normally |

---

## Role in the System

The plan gate is a **safety net**, not the primary enforcement layer. Primary enforcement is THE RULE from `using-solidity-superpowers` injected at session start.

The plan gate specifically catches:
- The user phrases a request as a direct implementation instruction ("just write me a vault contract")
- The session context was lost after compaction
- The user explicitly tries to bypass planning

---

## Verification

After implementation, test by asking Claude to "write a simple ERC-20 token" without running `/new-contract` first. The hook should inject the hard-gate block and redirect to the planner.
