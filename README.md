# gtools — GitHub Workflow Automation for Claude Code

A Claude Code plugin providing specialized skills for GitHub workflow automation, branch management, and multi-agent task orchestration.

## Installation

### Prerequisites
- Claude Code (claude.ai/code, CLI, or desktop)
- Git
- GitHub CLI (`gh`) for GitHub-related skills

### Option 1 — Direct install (no clone required)

```bash
claude --plugin-url https://github.com/argami/gtools/archive/refs/heads/main.zip
```

### Option 2 — Add as personal marketplace

```
/plugin marketplace add argami/gtools
```

Then install:

```
/plugin install gtools
```

### Option 3 — From community marketplace (after approval)

```
/plugin install gtools@claude-community
```

### Option 4 — Local path (development)

```bash
claude --plugin-dir /path/to/gtools
```

### Verify Installation

Type `/gtools:` in Claude Code — you should see autocomplete suggestions for all 7 skills.

---

## Skills Overview

| Skill | Trigger | Usage | Parameters |
|-------|---------|-------|-----------|
| **squash-branch** | Manual | Consolidate all commits on the current branch into one with auto-generated commit message. | `[--base branch] [--message msg] [--no-pr]` |
| **list-unresolved-comments** | Manual | Fetch and display all unresolved review threads on the current PR. | `[--outdated-only]` |
| **resolve-comments** | Manual | Bulk resolve unresolved (or outdated) review threads on a PR. | `[--outdated-only]` |
| **pre-commit-review** | Auto (pre-commit hook) | Runs code-review before every commit, iterates fixing issues. | *(none)* |
| **post-push-review** | Auto (post-push hook) | Watches code-review CI after push, auto-fixes PR comments, re-pushes. | *(none)* |
| **update_timesheets** | Manual | Submit BambooHR timesheet entries with automatic shift calculation. | `<dates> [dry-run] [session=...] [csrf=...] [employeeId=...] [verbose]` |
| **team-lead** | Manual | Orchestrate multi-agent task execution with Developer-A, Developer-B, and Reviewer. | `<tasks.md> [no-worktrees]` |

### Quick Links

- **Branch Management**: [`squash-branch`](skills/squash-branch)
- **PR Review**: [`list-unresolved-comments`](skills/list-unresolved-comments), [`resolve-comments`](skills/resolve-comments)
- **CI/Review Automation**: [`pre-commit-review`](skills/pre-commit-review), [`post-push-review`](skills/post-push-review)
- **Timesheet**: [`update_timesheets`](skills/update_timesheets)
- **Team Coordination**: [`team-lead`](skills/team-lead)

---

## Usage Examples

### Squash commits with auto-generated message
```
/gtools:squash-branch --base main
```
Shows a plan of commits to squash, generates a message, and waits for approval.

### List unresolved PR review threads
```
/gtools:list-unresolved-comments
```
Fetches and displays all unresolved threads on the current PR.

### Resolve all outdated review threads
```
/gtools:resolve-comments --outdated-only
```
Auto-resolves threads marked as both unresolved and outdated.

### Submit timesheets for this week
```
/gtools:update_timesheets this week
```
Calculates shifts (Mon–Thu: 9–1, 2–6:30; Fri: 9–3) and submits to BambooHR. Supports natural language dates, ranges, and both English/Spanish.

### Orchestrate a multi-developer task run
```
/gtools:team-lead /path/to/tasks.md
```
Spawns Developer-A, Developer-B, and Reviewer agents. Manages git worktrees, rebasing, and ff-only merges. See [`team-lead` docs](skills/team-lead) for full workflow.

### Pre/post-commit automation
Pre-commit and post-push review skills are **auto-triggered** by hooks:
- Before every `git commit` → runs code-review, blocks commit until issues resolved
- After every `git push` → watches CI, auto-fixes reported issues, re-pushes until clean

---

## Skill Details

For in-depth documentation on individual skills, see:

- **[squash-branch](skills/squash-branch/README.md)** — Branch consolidation with linear history
- **[update_timesheets](skills/update_timesheets/README.md)** — BambooHR timesheet automation
- **[team-lead](skills/team-lead/README.md)** — Multi-agent task orchestration

For other skills, documentation is embedded in their `SKILL.md` files (accessible via Claude Code or the skill itself).

---

## Architecture

### Plugin Structure

```
gtools/
├── README.md                          # This file
├── CLAUDE.md                          # Developer guide
├── .claude-plugin/
│   └── plugin.json                    # Plugin metadata
├── hooks/
│   └── hooks.json                     # Pre/post-commit hook definitions (uses ${CLAUDE_PLUGIN_ROOT})
└── skills/
    ├── squash-branch/
    ├── resolve-comments/
    ├── list-unresolved-comments/
    ├── pre-commit-review/
    │   └── src/
    │       └── before-commit.sh       # Blocks commit, checks /tmp/gtools-review-<sha256-hash> marker
    ├── post-push-review/
    │   └── src/
    │       └── after-push.sh          # Injects post-push review context
    ├── update_timesheets/
    │   └── README.md                  # Detailed usage
    └── team-lead/
        └── README.md                  # Workflow details
```

### Naming Convention

Skill directories use kebab-case (e.g., `squash-branch`, `resolve-comments`). The exception is `update_timesheets` which uses underscores to match its slash command `/gtools:update_timesheets`.

### TypeSafe Integration (optional)

Several skills use [TypeSafe](https://typesafe.ai) to replace brittle keyword matching and LLM guessing with calibrated semantic judgments. Set `TYPESAFE_API_KEY` to enable; all skills fall back to their original behavior without it.

| Skill | What TypeSafe handles | Fallback |
|-------|----------------------|---------|
| `update_timesheets` | Dry-run intent detection — catches any phrasing in any language | Keyword list (`dry-run`, `simular`, `prueba`, …) |
| `squash-branch` | Commit convention classification (Conventional Commits vs. custom vs. plain) with confidence gate | Model infers from log output |
| `squash-branch` | User approval routing — correctly handles ambiguous responses like "no wait, yes go ahead" | yes/no/else heuristic |
| `team-lead` | Reviewer verdict parsing — works even if the Reviewer paraphrases or omits the exact emoji | Scans for `APPROVED` / `CHANGES REQUESTED` text |

```bash
export TYPESAFE_API_KEY=your_key_here
```

### Dependencies

- **GitHub skills** require `gh` CLI with write access to your repository
- **BambooHR skill** requires credentials stored in `~/.timesheets_config.json` (persisted after first run)
- **Team-lead skill** requires Claude Code with Agent Teams support (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **TypeSafe features** require `TYPESAFE_API_KEY` env var (optional — all skills work without it)

---

## Hooks

The plugin registers two Claude Code hooks in `hooks/hooks.json`:

| Hook | Trigger | Action |
|------|---------|--------|
| **PreToolUse** | Before `git commit` or `rtk git commit` | **Blocks** the commit and triggers `pre-commit-review`. Allows through once the skill creates `/tmp/gtools-review-<sha256-hash>` (hash of project dir + staged diff). |
| **PostToolUse** | After `git push` or `rtk git push` | Injects context instructing Claude to run `post-push-review` skill. |

Hook logic lives in `skills/pre-commit-review/src/before-commit.sh` and `skills/post-push-review/src/after-push.sh`. These can be disabled in Claude Code settings if desired.

---

## Contributing

To add or modify skills:

1. Create a new directory under `skills/<skill-name>/`
2. Write a `SKILL.md` file with frontmatter (metadata) and markdown body (step-by-step instructions)
3. For complex skills, add a `README.md` for detailed usage docs
4. Update `plugin.json` version if publishing
5. Test via `/gtools:skill-name` in Claude Code

See [`CLAUDE.md`](CLAUDE.md) for developer guide and skill structure details.

---

## License

MIT

---

## Support

For issues or feature requests, open an issue in the repository.
