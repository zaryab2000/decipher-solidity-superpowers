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
