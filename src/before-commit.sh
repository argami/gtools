#!/bin/bash
CMD=$(jq -r '.tool_input.command // empty')
echo $CMD >> /tmp/gtools.log
if echo "$CMD" | grep -q 'git commit'; then
  echo '{"additionalContext": "Reminder: run /gtools:pre-commit-review and resolve all issues before completing this commit."}'
fi
exit 0
