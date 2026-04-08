#!/bin/bash
# escalate.sh — Generate a blocking hook from a persistent correction
#
# When a correction keeps firing but the AI still fails, the correction
# needs to escalate from advisory (injected rule) to enforcement (blocking hook).
#
# This script generates a PreToolUse blocking hook for a specific pattern,
# following the same design as verify-gate.sh.
#
# Usage: escalate.sh <correction-file> <output-hook-path>

CORRECTION_FILE="$1"
OUTPUT_PATH="$2"

if [ -z "$CORRECTION_FILE" ] || [ -z "$OUTPUT_PATH" ]; then
  echo "Usage: escalate.sh <correction-file> <output-hook-path>"
  echo "Example: escalate.sh corrections/2026-04-08_shallow-api.md ~/.claude/hooks/deep-api-verify.sh"
  exit 1
fi

if [ ! -f "$CORRECTION_FILE" ]; then
  echo "Correction file not found: $CORRECTION_FILE"
  exit 1
fi

TAGS=$(grep "^tags:" "$CORRECTION_FILE" | head -1 | sed 's/^tags: //' | tr -d '[]')
BODY=$(awk '/^---$/{n++; next} n>=2' "$CORRECTION_FILE" | head -10)

cat > "$OUTPUT_PATH" << 'HOOKHEADER'
#!/bin/bash
# AUTO-GENERATED blocking hook from ABMS correction escalation
# This hook BLOCKS the action and injects a mandatory check.
# Remove this hook when the behavioral pattern is resolved.
#
HOOKHEADER

cat >> "$OUTPUT_PATH" << HOOKBODY
# Generated from: $(basename "$CORRECTION_FILE")
# Tags: $TAGS
# Escalated because: correction fired repeatedly without behavioral change

INPUT=\$(cat)
TOOL=\$(echo "\$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))" 2>/dev/null)

COMMAND=\$(echo "\$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('command', ti.get('file_path', '')))" 2>/dev/null)

# Pattern matching — customize this for the specific behavior
# Currently matches based on the correction's tags
HOOKBODY

# Generate pattern matching based on tags
for TAG in $(echo "$TAGS" | tr ',' ' '); do
  TAG=$(echo "$TAG" | tr -d ' ')
  case "$TAG" in
    api)
      cat >> "$OUTPUT_PATH" << 'PATTERN'
# Block completion claims on API work without evidence
if echo "$COMMAND" | grep -qi "api\|route\|handler\|endpoint"; then
  echo "BLOCKED: Deep API verification required."
  echo ""
  echo "$BODY"
  echo ""
  echo "Provide evidence (actual response body) before proceeding."
  exit 2
fi
PATTERN
      ;;
    ui)
      cat >> "$OUTPUT_PATH" << 'PATTERN'
# Block completion claims on UI work without visual verification
if echo "$COMMAND" | grep -qi "component\|page\|view\|tsx\|jsx"; then
  echo "BLOCKED: Visual verification required."
  echo ""
  echo "Take a screenshot and describe what you see before proceeding."
  exit 2
fi
PATTERN
      ;;
  esac
done

cat >> "$OUTPUT_PATH" << 'HOOKFOOTER'

# Default: allow action
exit 0
HOOKFOOTER

chmod +x "$OUTPUT_PATH"

echo "Generated blocking hook: $OUTPUT_PATH"
echo "Add it to your PreToolUse hooks in settings.json to activate."
echo ""
echo "WARNING: Blocking hooks are heavy-handed. Only use when advisory rules"
echo "have repeatedly failed to change behavior. Remove when the pattern is resolved."
