# gtools — GitHub Workflow Automation for Claude Code

A Claude Code plugin providing specialized skills for GitHub workflow automation, branch management, and multi-agent task orchestration.

## Installation

### Prerequisites
- Claude Code (claude.ai/code, CLI, or desktop)
- Git
- GitHub CLI (`gh`) for GitHub-related skills

### Install the Plugin

1. In Claude Code, open **Settings** → **Plugins**
2. Click **Install from repository**
3. Paste: `https://github.com/yourusername/gtools` (or your local path)
4. Click **Install**

The plugin will be registered as `gtools:` and all skills will be available as `/gtools:skill-name`.

Alternatively, if using the CLI:
```bash
claude plugin install /path/to/gtools
```

### Verify Installation

In Claude Code, type `/gtools:` and you should see autocomplete suggestions for all 7 skills.

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
│   └── hooks.json                     # Pre/post-commit hooks
└── skills/
    ├── squash-branch/
    ├── resolve-comments/
    ├── list-unresolved-comments/
    ├── pre-commit-review/
    ├── post-push-review/
    ├── update_timesheets/
    │   └── README.md                  # Detailed usage
    └── team-lead/
        └── README.md                  # Workflow details
```

### Naming Convention

All skills use kebab-case names matching their directory names (e.g., `update-timesheets`, not `update_timesheets`).

### Dependencies

- **GitHub skills** require `gh` CLI with write access to your repository
- **BambooHR skill** requires credentials stored in `~/.timesheets_config.json` (persisted after first run)
- **Team-lead skill** requires Claude Code with Agent Teams support (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

---

## Hooks

The plugin registers two Claude Code hooks in `hooks/hooks.json`:

| Hook | Trigger | Action |
|------|---------|--------|
| **PreToolUse** | Before `git commit` | Reminds to run `pre-commit-review` skill |
| **PostToolUse** | After `git push` | Reminds to run `post-push-review` skill |

These can be disabled in Claude Code settings if desired.

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
