#!/bin/bash
CMD=$(jq -r '.tool_input.command // empty')
echo "before: $CMD" >> /tmp/gtools.log
if echo "$CMD" | grep -q 'git commit'; then
  echo "it is a commit command injecting" >> /tmp/gtools.log
  echo '{"additionalContext": "Reminder: run /gtools:pre-commit-review and resolve all issues before completing this commit."}'
fi
exit 0
