---
name: list-unresolved-comments
description: >-
  List all unresolved review threads on a GitHub PR.
when_to_use: Use this skill whenever the user asks to see open review comments, unresolved threads, pending feedback, or wants to know what review items are left to address — even if they don't use the exact words "unresolved threads". Works on the current repo and PR automatically. Also use when the user wants to bulk-resolve threads after reviewing them. Supports an optional --outdated-only flag to show only threads that are both unresolved and outdated.
argument-hint: "--outdated-only"
arguments:
  - name: --outdated-only
    description: Show only threads that are both unresolved and outdated
    required: false
---

## GitHub Unresolved Review Threads

Fetch and display all review threads with `isResolved: false` for the current repo and PR.

### Step 1 — Detect repo owner and name

```bash
REMOTE_URL=$(git remote get-url origin)
# Extract owner/repo from SSH (git@github.com:owner/repo.git) or HTTPS format
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+?)\.git$|\1|; s|.*github\.com[:/]([^/]+/[^/]+)$|\1|')
OWNER=$(echo "$OWNER_REPO" | cut -d'/' -f1)
REPO=$(echo "$OWNER_REPO" | cut -d'/' -f2)
```

Verify both `$OWNER` and `$REPO` are non-empty strings. If either is empty (enterprise GitHub URL, subgroup, or non-standard format), ask the user to provide the owner and repo name directly.

### Step 2 — Detect the PR number

```bash
gh pr view --json number --jq '.number'
```

If the command fails (not on a PR branch), ask the user for the PR number.

### Step 3 — Fetch unresolved threads

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
        totalCount
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 1) {
            nodes {
              body
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

**If `--outdated-only` flag is passed**, modify the `jq` filter to also require `isOutdated: true`:

```bash
| jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == true)]'
```

### Step 4 — Display results

Present the unresolved threads in a clean table or list. For each thread show:

| Field | Source |
|---|---|
| # | index (1-based) |
| File | `path` |
| Line | `line` (or `"—"` if null) |
| Author | `comments.nodes[0].author.login` |
| Comment | first 120 chars of `comments.nodes[0].body` |
| Outdated | `isOutdated` (flag with ⚠️ if true) |

Lead with a summary line: **"X unresolved thread(s) on PR #N"**.

When `--outdated-only` filter is active, use: **"X outdated+unresolved thread(s) on PR #N"**.

If there are zero threads, say so clearly.

Keep the `id` field available (but you don't need to show it in the table) — the user may ask to resolve threads in a follow-up.

### Notes

- Outdated threads (`isOutdated: true`) are still unresolved — include them but call them out.
- Do NOT resolve any threads unless the user explicitly asks.
- The `id` values are GitHub node IDs needed for the `resolveReviewThread` mutation — keep them in context.
