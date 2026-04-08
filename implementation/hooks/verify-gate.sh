#!/bin/bash
# PreToolUse hook on Bash: blocks git commit without fresh verification stamp
# The stamp is created by post-bash.sh when a recognized test/build command passes.
# Edits clear the stamp (via edit-tracker.sh), forcing re-verification.

INPUT=$(cat /dev/stdin)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only gate git commit
echo "$COMMAND" | grep -qE 'git\s+commit\b' || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
VERIFIED="$PROJECT_DIR/.claude/.verified"

# No stamp = no commit
if [ ! -f "$VERIFIED" ]; then
    cat >&2 << 'EOF'
COMMIT BLOCKED — no verification stamp.

Before committing you MUST run the project's test or build command:
  npm test / npm run test / npm run build / pytest / go test / cargo test / dotnet test / bun test

The stamp is created automatically when a recognized test/build command succeeds.
If you edited files after the last test run, you need to re-run tests.
If this project has no tests or build, run: touch .claude/.verified
EOF
    exit 2
fi

# Stale stamp (>30 minutes) = no commit
STAMP_AGE=$(( $(date +%s) - $(stat -c %Y "$VERIFIED" 2>/dev/null || echo 0) ))
if [ "$STAMP_AGE" -gt 1800 ]; then
    echo "COMMIT BLOCKED — verification stamp is $(( STAMP_AGE / 60 ))m old (stale after 30m). Re-run tests." >&2
    rm -f "$VERIFIED"
    exit 2
fi

echo "Verified $(( STAMP_AGE / 60 ))m ago. Commit allowed."
exit 0
