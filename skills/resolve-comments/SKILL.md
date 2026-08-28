---
name: resolve-review-comments
description: >-
  Bulk resolve unresolved review threads on a GitHub PR. Use this skill when
  the user asks to resolve, mark as resolved, or close review threads, comments,
  or feedback. Works on the current repo and PR automatically. Supports optional
  --outdated-only flag to resolve only outdated threads instead of all unresolved
  ones.
when_to_use: Use this skill when the user asks to resolve, mark as resolved, or close review threads, comments, or feedback. Works on the current repo and PR automatically. Supports optional --outdated-only flag to resolve only outdated threads instead of all unresolved ones.
argument-hint: "--outdated-only"
arguments:
  - name: --outdated-only
    description: Resolve only threads that are both unresolved and outdated
    required: false
---

## GitHub Resolve Review Threads

Bulk resolve unresolved review threads using the `resolveReviewThread` GraphQL mutation.

### Step 1 — Detect repo owner and name

```bash
git remote get-url origin
```

Parse `owner` and `repo` from the URL. Both formats work:
- SSH: `git@github.com:owner/repo.git`
- HTTPS: `https://github.com/owner/repo.git`

### Step 2 — Detect the PR number

```bash
gh pr view --json number --jq '.number'
```

If the command fails (not on a PR branch), ask the user for the PR number.

### Step 3 — Fetch thread IDs to resolve

```bash
gh api graphql --paginate \
  -F owner='<owner>' \
  -F repo='<repo>' \
  -F number=<pr_number> \
  -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
        }
      }
    }
  }
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id]'
```

**If `--outdated-only` flag is passed**, modify the filter to also require `isOutdated: true`:

```bash
| jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == true) | .id]'
```

Store the array of IDs from the jq output.

### Step 4 — Resolve each thread

For each thread ID from Step 3, execute the mutation:

```bash
gh api graphql \
  -F threadId='<thread_id>' \
  -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread {
      id
      isResolved
    }
  }
}'
```

Check the response. If `thread.isResolved` is `true`, the thread was successfully resolved.

### Step 5 — Report results

Display a summary:
- **"Resolved X thread(s) on PR #N"** (if all succeeded)
- **"Resolved X of Y thread(s) on PR #N"** (if any failed)
- **"No threads to resolve on PR #N"** (if the filter returned zero IDs)

When `--outdated-only` was used, note it in the summary: **"Resolved X outdated thread(s) on PR #N"**

### Notes

- The `id` field is the GitHub node ID (starts with `PR_` followed by alphanumerics).
- If a mutation fails, report which thread ID failed and the error message.
- Do NOT resolve threads unless the user explicitly asks (Step 2 of `/gtools:gh-unresolved-threads` keeps them in context for this purpose).
- Authentication must have write access to the PR's repo.
