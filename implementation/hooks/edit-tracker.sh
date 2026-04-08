#!/bin/bash
# PostToolUse hook on Edit/Write: clears verification stamp and nudges after repeated edits

INPUT=$(cat /dev/stdin)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
VERIFIED="$PROJECT_DIR/.claude/.verified"
COUNTER="$PROJECT_DIR/.claude/.edit-count"

mkdir -p "$PROJECT_DIR/.claude"

# Clear verification stamp — edits invalidate previous test runs
if [ -f "$VERIFIED" ]; then
    rm -f "$VERIFIED"
fi

# Increment edit counter
COUNT=0
if [ -f "$COUNTER" ]; then
    COUNT=$(cat "$COUNTER" 2>/dev/null || echo 0)
fi
COUNT=$(( COUNT + 1 ))
echo "$COUNT" > "$COUNTER"

# Nudge every 5 edits
if [ $(( COUNT % 5 )) -eq 0 ]; then
    echo "REMINDER: ${COUNT} file changes since last verification. Run tests before committing. The commit gate WILL block you."
fi

exit 0
