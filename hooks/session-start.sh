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
