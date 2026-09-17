# squash-branch

Consolidate all commits on the current branch into a single commit with an auto-generated or custom commit message. Optionally updates the associated PR description. **Always shows a plan first and waits for explicit approval before modifying anything.**

## Quick Start

```bash
/gtools:squash-branch --base main
```

You'll see:
1. **Plan**: number of commits to squash, list of commits, proposed message
2. **Prompt**: "Proceed with squash? Reply **yes** to execute, **no** to cancel, or paste an edited message"
3. **Result**: commits are consolidated into one, you push manually, PR description is updated (optional)

## Usage

### Basic usage (infer base branch)
```bash
/gtools:squash-branch
```
Squashes all commits since the current branch diverged from `main` (default base).

### Specify a different base branch
```bash
/gtools:squash-branch --base develop
```
Squashes commits since diverging from `develop`.

### Custom commit message (first line only)
```bash
/gtools:squash-branch --message "fix: resolve race condition in auth middleware"
```
Uses your message as the first line; Claude auto-generates the body from commit history.

### Full custom message
After the skill shows the plan, you can paste a complete multi-line message instead of just "yes":
```
feat: add new dashboard feature

- Implement real-time data sync
- Add user preferences panel
- Update tests
```
The skill will use this instead of the generated message.

### Skip PR description update
```bash
/gtools:squash-branch --no-pr
```
Squashes commits but does not update an associated PR's description.

## How It Works

### Phase 1: Analyze
- Reads all commits since the branch diverged from the base branch
- Detects the project's commit message convention (Conventional Commits, custom prefix, or plain)
- If a PR is associated, fetches its current description

### Phase 2: Generate Plan
- **Commit count**: how many commits will be consolidated
- **Commit list**: `git log --oneline` for review
- **Proposed message**: auto-generated based on commit history and convention
- **PR update preview**: (if a PR exists and `--no-pr` is not set)

### Phase 3: Wait for Approval
Presents the full plan and asks:
- **"yes"** → execute the squash
- **"no"** → cancel without changes
- **paste a message** → use your custom message instead

### Phase 4: Execute
1. Stages all changes and resets to base branch tip
2. Creates a new commit with the approved message (or your custom one)
3. Updates PR description (if applicable)
4. Reports the new commit hash

## Workflow: Linear History

This skill preserves **linear history** — no merge commits. It's designed for workflows where:
- You're working on a feature branch
- You've made several incremental commits
- Before merging to main, you want to consolidate into one logical commit

**Common scenario:**
```
main ──●── (base tip)
        \
         ●─○─○─○  (your feature branch with 4 commits)
```

After squash:
```
main ──●──●  (your consolidated commit, ready to merge)
```

## Important Notes

### No force-push
The skill **never force-pushes**. You push manually after approval. This is intentional — it prevents accidental history rewrites on shared branches.

### Rebase-based
Uses `git reset --soft` to preserve all changes in the staging area, then creates a new commit. This is safe and reversible (you can undo with `git reflog` if needed).

### Commit message convention
The skill reads your project's recent commit history to infer the convention (e.g., "feat:", "fix:", "chore:"). If your repo doesn't have clear conventions, it falls back to a simple descriptive message.

### PR description sync
If your branch has an associated PR:
- **Default**: updates the PR description to reflect the squashed commits
- **With `--no-pr`**: skips this step
- The description is expanded (not squashed) — it still contains full details of what was done

## Examples

### Feature branch
```bash
# You've been working on a feature with several commits
git log --oneline
# a1b2c3d docs: update API docs
# d4e5f6g feat: add new endpoint
# h8i9j0k feat: scaffold feature structure

/gtools:squash-branch --base main
# → Plan shows 3 commits, generated message:
#   "feat: add new API endpoint with documentation"
# → You review, reply "yes"
# → Single commit replaces the 3
```

### Work-in-progress turned final
```bash
# You've been committing as you go: "wip", "fix typo", "refactor", etc.
/gtools:squash-branch --message "feat: implement user authentication system"
# → Claude generates a detailed body from your WIP commits
# → Final commit is clean and follows project conventions
```

### Cancel and edit locally
```bash
/gtools:squash-branch
# → You see the proposed message
# → You reply "no" (cancels without changes)
# → You manually edit some commits, then try again
```

## Troubleshooting

### "You are already on the base branch"
You can't squash commits if you're on the base branch itself. Switch to your feature branch first:
```bash
git checkout your-feature-branch
/gtools:squash-branch
```

### "No commits found between X and Y"
Your branch is already merged or identical to the base. Check:
```bash
git log --oneline main..HEAD
```
If that's empty, there are no unique commits on your branch.

### "Branch is stale"
If the base branch has moved since you started, the skill will tell you. Rebase first:
```bash
git rebase origin/main
/gtools:squash-branch
```

## See Also

- **[post-push-review](../post-push-review/)** — Auto-fix PR review comments after pushing
- **[team-lead](../team-lead/)** — Multi-agent task orchestration with automatic branching and merging
