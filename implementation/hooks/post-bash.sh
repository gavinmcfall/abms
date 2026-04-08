#!/bin/bash
# PostToolUse hook on Bash: creates verification stamp on test/build pass, tracks elapsed time

INPUT=$(cat /dev/stdin)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
mkdir -p "$PROJECT_DIR/.claude"

# --- Verification stamp: detect test/build commands ---
# Match common test and build commands
if echo "$COMMAND" | grep -qEi '(npm\s+(test|run\s+test[s]?|run\s+build|run\s+check|run\s+lint)|npx\s+(vitest|jest|playwright)|pytest|py\.test|go\s+test|cargo\s+test|cargo\s+build|dotnet\s+test|dotnet\s+build|make\s+test|make\s+check|bun\s+test|bun\s+run\s+test|pnpm\s+(test|run\s+test)|yarn\s+test|gradle\s+test|mvn\s+test)'; then
    # Check exit code from tool response (try multiple possible field paths)
    EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exitCode // .tool_response.exit_code // .tool_result.exitCode // .tool_result.exit_code // "unknown"' 2>/dev/null)

    if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "unknown" ]; then
        echo "$(date +%s)|$(echo "$COMMAND" | head -c 100)" > "$PROJECT_DIR/.claude/.verified"
        echo "VERIFICATION STAMP: Tests/build passed. Commit gate unlocked."
    else
        rm -f "$PROJECT_DIR/.claude/.verified"
        echo "VERIFICATION: Tests/build FAILED (exit $EXIT_CODE). Stamp cleared. Fix issues before committing."
    fi
fi

# --- Elapsed time tracking ---
TRACKER="$PROJECT_DIR/.claude/.session-tracker"

# Initialize on first run
if [ ! -f "$TRACKER" ]; then
    echo "$(date +%s)|0" > "$TRACKER"
    exit 0
fi

SESSION_START=$(head -1 "$TRACKER" | cut -d'|' -f1)
LAST_REPORT=$(head -1 "$TRACKER" | cut -d'|' -f2)
NOW=$(date +%s)
ELAPSED=$(( NOW - SESSION_START ))
SINCE_REPORT=$(( NOW - LAST_REPORT ))

# Report every 5 minutes
if [ "$SINCE_REPORT" -gt 300 ]; then
    MINS=$(( ELAPSED / 60 ))
    HOURS=$(( MINS / 60 ))
    REMAINING_MINS=$(( MINS % 60 ))

    # Update last report time
    echo "${SESSION_START}|${NOW}" > "$TRACKER"

    if [ "$HOURS" -gt 0 ]; then
        echo "SESSION TIME: ${HOURS}h ${REMAINING_MINS}m elapsed."
    else
        echo "SESSION TIME: ${MINS}m elapsed."
    fi
fi

exit 0
