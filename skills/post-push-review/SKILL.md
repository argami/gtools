---
name: post-push-review
description: Use this skill automatically right after a `git push` is made. Watches the `code-review` GitHub Action run for the pushed commit/PR, and if it produces review comments, resolves the issues, commits, and pushes again, repeating until the review is clean or the user is asked how to proceed.
when_to_use: right after a `git push` is made.
---

# Post-push Review

## Purpose

After pushing a branch, automatically wait for the company's `code-review` GitHub Action to finish, read whatever it reports on the current PR, fix the issues, and push again — without the user having to manually watch the run or babysit the review comments.

## Workflow

1. **Identify the run**: right after a `git push`, find the most recent `code-review` workflow run for the current branch:
   ```
   gh run list --workflow=code-review --branch "$(git branch --show-current)" --limit 1 --json databaseId,status,conclusion
   ```
2. **Watch it to completion**:
   ```
   gh run watch <run-id> --exit-status
   ```
3. **Check the outcome**:
   - Fetch the current PR number for this branch: `gh pr view --json number,comments,reviews`.
   - Collect the review comments / issues left by the `code-review` action (via `gh pr view --json comments,reviews` or `gh api repos/{owner}/{repo}/pulls/{pr}/comments` if the tool leaves inline comments).
4. **If there are issues**:
   1. Fix each reported issue in the code.
   2. Commit and push the fixes.
   3. This triggers `code-review` again — repeat from step 1.
   4. Continue this cycle until the run reports no remaining issues.
5. **If an issue cannot be resolved automatically** after a few reasonable attempts (e.g. it requires a decision, more context, or looks like a false positive):
   - Stop.
   - List the unresolved issue(s) and why they could not be fixed automatically.
   - Ask the user how to proceed. Do not push further changes until the user responds.
6. **If the run passes cleanly with no issues**: report success and stop, no further action needed.

## Notes

- This skill only reads and acts on PR review comments/checks via the `gh` CLI; it never modifies GitHub Actions workflow files or any CI configuration in the company repository.
- Intended to run interactively inside an active Claude Code session (the user is actively developing), not as an unattended background process.