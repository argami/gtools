#!/bin/bash
command -v jq >/dev/null 2>&1 || exit 0
CMD=$(jq -r '.tool_input.command // empty')
if echo "$CMD" | grep -qE '(^|\s)git commit($|\s)'; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  command -v sha256sum >/dev/null 2>&1 && HASHER="sha256sum" || HASHER="shasum -a 256"
  HASH=$( { printf '%s\n' "${CLAUDE_PROJECT_DIR:-$(pwd)}"; git diff --staged; } | $HASHER | cut -d' ' -f1)
  MARKER="/tmp/gtools-review-${HASH}"
  if [ -f "$MARKER" ]; then
    rm "$MARKER"
    exit 0
  fi
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "decision": "block", "reason": "Pre-commit review required. Run /gtools:pre-commit-review, fix all issues, then it will create the approval marker and retry the commit automatically."}}'
  exit 2
fi
exit 0
