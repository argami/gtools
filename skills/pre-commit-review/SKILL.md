---
name: pre-commit-review
description: Use this skill automatically whenever a task is about to be finished or before making a git commit. Runs the code-review skill (if installed) and iterates fixing issues until they are resolved, or asks the user how to proceed if something cannot be fixed automatically.
when_to_use: whenever you are about to make a git commit.
---

# Pre-commit Review

## Purpose

Ensure that no commit is made without first running an automated code review (via the `code-review` skill, if available) and resolving any issues it reports.

## Workflow

1. **Check availability**: Before considering a task finished or making a commit, check if the `code-review` skill is installed and available.
2. **If `code-review` is installed**:
   1. Run the `code-review` skill on the changed code.
   2. If issues are found:
      - Fix the reported issues in the code.
      - Re-run the `code-review` skill on the updated code.
      - Repeat this fix-and-review cycle until the skill reports no remaining issues.
   3. If, after several reasonable attempts, an issue cannot be resolved automatically (e.g. it requires a design decision, external input, or looks like a false positive):
      - Stop before committing.
      - Clearly list the unresolved issue(s) and explain why they could not be fixed automatically.
      - Ask the user how to proceed (fix manually, accept the risk, or mark it as a known false positive).
      - Do not commit until the user explicitly confirms how to handle the remaining issue(s).
   4. Only proceed to commit once `code-review` reports zero issues, or the user has explicitly approved proceeding despite specific known issues.
   5. Create the approval marker in a **separate Bash call** (no `git commit` in this call — the PreToolUse hook fires at the tool-call boundary, so the marker must exist before the commit call is made):
      ```bash
      command -v sha256sum >/dev/null 2>&1 && HASHER="sha256sum" || HASHER="shasum -a 256"
      HASH=$( { printf '%s\n' "${CLAUDE_PROJECT_DIR:-$(pwd)}"; git diff --staged; } | $HASHER | cut -d' ' -f1)
      touch "/tmp/gtools-review-${HASH}"
      ```
      Then commit in a **second, separate Bash call** — the hook fires here, finds the marker, and allows the commit through:
      ```bash
      git commit -m "<your commit message>"
      ```
3. **If `code-review` is not installed**:
   - Create the approval marker in a separate Bash call (same as step 2.5 above), then run `git commit` in a second separate Bash call.
   - Mention in the final summary that the skill was not available and therefore no automated review was performed.

## Notes

- This skill should trigger passively, i.e. without the user needing to explicitly invoke it, whenever a commit is about to happen or a development task is being wrapped up.
- Combine with a `PreToolUse` hook on `git commit` commands (see `hooks/hooks.json` in this plugin) for a more deterministic guarantee that this workflow is always followed.