#!/bin/bash
CMD=$(jq -r '.tool_input.command // empty')
echo "before: $CMD" >> /tmp/gtools.log
if echo "$CMD" | grep -q 'git commit'; then
  if [ -f /tmp/gtools-review-passed ]; then
    rm /tmp/gtools-review-passed
    echo "review passed marker found, allowing commit" >> /tmp/gtools.log
    exit 0
  fi
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "decision": "block", "reason": "Pre-commit review required. Run /gtools:pre-commit-review, fix all issues, then it will create the approval marker and retry the commit automatically."}}'
  exit 2
fi
exit 0
