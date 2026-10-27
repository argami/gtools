#!/bin/bash
command -v jq >/dev/null 2>&1 || exit 0
CMD=$(jq -r '.tool_input.command // empty')
if echo "$CMD" | grep -q 'git push'; then
  echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "A git push was made. Run /gtools:post-push-review now: watch the code-review GitHub Action, fix any reported issues, commit and push again until clean."}}'
fi
exit 0
