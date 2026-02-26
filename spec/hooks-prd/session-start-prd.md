# Hook PRD: Session Start Hook

**Files:** `hooks/hooks.json` + `hooks/session-start.sh`

**Event:** `SessionStart`

---

## Purpose

Inject the `using-solidity-superpowers` skill content as session context before the agent's first turn. This ensures the agent knows THE RULE and the skill inventory from the very first message, in every session.

---

## hooks.json Entry

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
    ]
  }
}
```

**Why `async: false`:** If the hook is async, it may not complete before the model's first response. The agent would answer the first message without skill context. Synchronous execution guarantees context injection before turn 1. This was a critical fix in Superpowers v4.3.0.

---

## session-start.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory (works even when BASH_SOURCE is unbound)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read the using-solidity-superpowers skill content
SKILL_FILE="$PLUGIN_ROOT/skills/using-solidity-superpowers/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo '{"additionalContext": "WARNING: using-solidity-superpowers skill not found. Skills may not trigger correctly."}'
  exit 0
fi

SKILL_CONTENT=$(cat "$SKILL_FILE")

# Escape for JSON using bash parameter substitution (O(n) performance)
# This approach replaces the O(n²) character-by-character loop
s="$SKILL_CONTENT"
s="${s//\\/\\\\}"     # backslash
s="${s//\"/\\\"}"     # double quote
s="${s//$'\n'/\\n}"   # newline
s="${s//$'\r'/\\r}"   # carriage return
s="${s//$'\t'/\\t}"   # tab

# Output as JSON for Claude Code to consume
cat <<EOF
{"additionalContext": "$s"}
EOF
```

---

## Post-Creation Step

Make executable: `chmod +x hooks/session-start.sh`

---

## Behavior

- Reads `skills/using-solidity-superpowers/SKILL.md`
- JSON-escapes the content using O(n) bash parameter substitution
- Outputs `{"additionalContext": "<escaped skill content>"}` for Claude Code to consume
- If the skill file is missing, outputs a warning instead of failing (graceful degradation)

---

## Verification

After implementation, start a Claude Code session and verify:
1. The SessionStart hook fires.
2. THE RULE from `using-solidity-superpowers` is present in the session context.
3. The agent applies the correct skill before the first response.
