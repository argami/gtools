---
name: squash-branch
description: >-
  Squash all commits on the current branch into one, generating a rich commit
  message from the full history. Optionally updates the associated PR description.
  Always shows a plan and waits for explicit user approval before executing.
argument-hint: "--base [branch] --message [msg] --no-pr"
arguments:
  - name: --base
    description: "Base branch to calculate commits from (default: main)"
    required: false
  - name: --message
    description: "Fix the commit's first line; Claude fills the body automatically"
    required: false
  - name: --no-pr
    description: Skip PR description update even if a PR exists
    required: false
---

## Squash Branch

Consolidate all commits on the current branch (since diverging from a base branch) into a single commit with a detailed message. If a PR is associated, updates its description too. **Never mutates anything without explicit user approval.**

### Usage

```
/gtools:squash-branch [--base <branch>] [--message <msg>] [--no-pr]
```

| Parameter | Default | Description |
|---|---|---|
| `--base <branch>` | `main` | Base branch to calculate commits from |
| `--message <msg>` | _(auto-generated)_ | Fix the commit's first line; Claude fills the body |
| `--no-pr` | false | Skip PR description update even if a PR exists |

---

### Step 1 — Parse arguments

Read the arguments passed after `/gtools:squash-branch`:
- Extract `--base <value>` → `BASE_BRANCH` (default: `main`)
- Extract `--message <value>` → `FIXED_SUBJECT` (default: empty)
- Detect `--no-pr` flag → `SKIP_PR` (default: false)

---

### Step 2 — Detect current branch

```bash
git branch --show-current
```

Store as `CURRENT_BRANCH`. If the result is empty (detached HEAD), stop and inform the user.

If `CURRENT_BRANCH` equals `BASE_BRANCH`, stop: "You are already on the base branch. Nothing to squash."

---

### Step 3 — Find merge-base and list commits

```bash
git merge-base HEAD <BASE_BRANCH>
```

Store as `MERGE_BASE`. Then list commits to squash:

```bash
git log <MERGE_BASE>..HEAD --oneline
```

If the list is empty, stop: "No commits found between `<CURRENT_BRANCH>` and `<BASE_BRANCH>`. Nothing to squash."

Count the commits → `COMMIT_COUNT`.

---

### Step 4 — Read full commit messages

```bash
git log <MERGE_BASE>..HEAD --pretty=format:"%H%n%s%n%b%n---COMMIT_SEPARATOR---"
```

Store the output as `COMMIT_HISTORY`. This is the raw material for generating the new message.

---

### Step 5 — Detect commit convention

Read these files in the repo root (if they exist) looking for commit message format rules:
- `CLAUDE.md`
- `AGENTS.md`
- `.github/CONTRIBUTING.md`
- `CONTRIBUTING.md`

If no explicit instructions are found, infer the convention from recent history:

```bash
git log --oneline -20
```

Determine whether the repo uses Conventional Commits (`feat:`, `fix:`, etc.), a custom prefix style, or plain messages. Use this convention for the new commit message.

---

### Step 6 — Check for associated PR (unless --no-pr)

If `SKIP_PR` is false:

```bash
gh pr view --json number,title,body --jq '{number: .number, title: .title, body: .body}'
```

If the command succeeds, store `PR_NUMBER`, `PR_TITLE`, `PR_BODY`. If it fails (no PR), set `HAS_PR=false` and skip PR steps silently.

---

### Step 7 — Generate the plan (NO execution yet)

Using `COMMIT_HISTORY` and the detected convention, synthesize:

**A) New squash commit message**
- If `FIXED_SUBJECT` was passed: use it as the first line verbatim
- Otherwise: write a concise first line (≤72 chars) following the detected convention that summarizes all the work
- Body: a detailed bullet list of what was done, grouped thematically when there are 4+ commits. Include enough detail to understand the change without reading the diff.

**B) Updated PR description** (only if `HAS_PR=true` and `SKIP_PR=false`)
- Preserve the existing structure of `PR_BODY`
- Expand or rewrite to reflect all the work captured in the commits
- Use markdown appropriate for GitHub

---

### Step 8 — Present plan and STOP

Display the full plan to the user in this format:

```
## Squash Plan

**Current branch:** <CURRENT_BRANCH>
**Base branch:** <BASE_BRANCH>
**Commits to squash:** <COMMIT_COUNT>

### Commits that will be consolidated:
<git log --oneline output>

### Proposed commit message:
```
<first line>

<body>
```

[### PR #<number> description update:  ← only if HAS_PR]
<new PR body>

---
Proceed with the squash? Reply **yes** to execute, **no** to cancel, or paste an edited commit message to use instead.
```

**STOP HERE. Do not run any git commands. Wait for the user's explicit response.**

---

### Step 9 — Handle user response

- **"no"** or any rejection → stop, no changes made, confirm: "Cancelled. No changes were made."
- **"yes"** or affirmative → proceed to Step 10 with the generated message
- **Any other text** → treat it as the user's custom commit message (first line or full message). Use it in Step 10 instead of the generated one. If it's only a subject line, still append the generated body. Confirm: "Using your message. Proceeding..."

---

### Step 10 — Execute squash

```bash
git reset --soft <MERGE_BASE>
```

Then commit with the approved message. Pass the full message via a heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<approved commit message>
EOF
)"
```

---

### Step 11 — Update PR description (if applicable)

Only if `HAS_PR=true` and `SKIP_PR=false`:

```bash
gh pr edit <PR_NUMBER> --body "<new PR description>"
```

Use `--body` with a heredoc via `$(cat <<'EOF' ... EOF)` to handle multi-line content safely.

---

### Step 12 — Report results

Display a summary:
- New commit hash: `git log -1 --format="%H %s"`
- "PR #<number> description updated" (if applicable)
- "Done. `<COMMIT_COUNT>` commits squashed into 1 on `<CURRENT_BRANCH>`."

---

### Safety Rules

- **Never run `git reset`, `git commit`, or `gh pr edit` before Step 9 approval.**
- **Never force-push.** This skill only modifies the local branch. The user pushes manually.
- If `git reset --soft` fails (e.g., merge conflicts in staging area), stop and report the error without attempting recovery.
- If the commit step fails (e.g., hooks rejecting the message), report the hook output and stop — do not retry or bypass hooks.
