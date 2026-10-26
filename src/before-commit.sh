#!/bin/bash
CMD=$(jq -r '.tool_input.command // empty')
echo "before: $CMD" >> /tmp/gtools.log
if echo "$CMD" | grep -q 'git commit'; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "Reminder: run /gtools:pre-commit-review and resolve all issues before completing this commit."}}'
fi
exit 0
