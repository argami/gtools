---
name: squash-branch
description: >-
  Squash all commits on the current branch into one, generating a rich commit
  message from the full history. Optionally updates the associated PR description.
  Always shows a plan and waits for explicit user approval before executing.
argument-hint: "--base [branch] --message [msg] --no-pr"
when_to_use: Use when consolidating multiple commits into one before merging a feature branch, with optional custom message and PR description update.
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

If no explicit instructions are found, classify the convention from recent history using TypeSafe:

```bash
git log --oneline -20 | jq -Rs \
  '{"model":"jev-latest","state":.,"questions":{"convention":{"type":"choice","instructions":"What commit message convention does this repository use, based on these recent commit messages?","criteria":{"conventional":"Uses Conventional Commits prefixes: feat:, fix:, chore:, docs:, refactor:, test:, style:, etc.","custom-prefix":"Has consistent prefixes but not Conventional Commits (e.g. [WIP], ADD:, update:, custom emoji or tags)","plain":"No consistent prefix — plain imperative sentences or mixed free-form style"}}}}' | \
  curl -s -X POST https://api.typesafe.ai/v1/systemone \
    -H "Authorization: Bearer $TYPESAFE_API_KEY" \
    -H "Content-Type: application/json" \
    -d @- | tee /tmp/ts_convention_resp.json
CONVENTION=$(jq -r '.answers.convention.choice' /tmp/ts_convention_resp.json)
CONFIDENCE=$(jq '.answers.convention.confidence' /tmp/ts_convention_resp.json)
```

- `confidence` ≥ 0.7 → use `$CONVENTION` for the new commit message
- `confidence` < 0.7 (mixed signals) → ask the user which convention to follow before generating the message

**Fallback** if `TYPESAFE_API_KEY` is unset or the call fails: infer the convention yourself from the log output.

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

Use TypeSafe to classify the user's intent (handles ambiguous responses like "no wait, yes go ahead"):

```bash
USER_RESP='<user response verbatim>'
INTENT=$(jq -n --arg state "$USER_RESP" \
  '{"model":"jev-latest","state":$state,"questions":{"intent":{"type":"choice","instructions":"What does the user want to do after seeing the squash plan?","criteria":{"proceed":"Confirms or approves — wants to proceed with the squash as shown","cancel":"Rejects or cancels — does not want to squash","custom-message":"Provides a different or edited commit message, or asks to modify the plan"}}}}' | \
  curl -s -X POST https://api.typesafe.ai/v1/systemone \
    -H "Authorization: Bearer $TYPESAFE_API_KEY" \
    -H "Content-Type: application/json" \
    -d @- | jq -r '.answers.intent.choice')
```

Route based on the result:
- `proceed` → go to Step 10 with the generated message
- `cancel` → stop: "Cancelled. No changes were made."
- `custom-message` → use the user's text as the commit message in Step 10; if only a subject line, append the generated body; confirm: "Using your message. Proceeding..."

**Fallback** if `TYPESAFE_API_KEY` is unset or the call fails: "yes"/affirmative → proceed, "no"/rejection → cancel, anything else → custom message.

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
