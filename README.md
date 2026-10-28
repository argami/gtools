# gtools — AI Skills for Claude Code

A collection of AI-powered skills for Claude Code: automate git and PR workflows, manage code reviews, submit timesheets, and orchestrate multi-agent development tasks.

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

| Skill | Description |
|-------|-------------|
| [**squash-branch**](skills/squash-branch/README.md) | Consolidate all commits on the current branch into one with an auto-generated commit message. |
| [**list-unresolved-comments**](skills/list-unresolved-comments/SKILL.md) | Fetch and display all unresolved review threads on the current PR. |
| [**resolve-comments**](skills/resolve-comments/SKILL.md) | Bulk resolve unresolved (or outdated) review threads on a PR. |
| [**pre-commit-review**](skills/pre-commit-review/SKILL.md) | Run code-review before every commit, iterate fixing issues. Auto-triggered by hook. |
| [**post-push-review**](skills/post-push-review/SKILL.md) | Watch the code-review CI after push, auto-fix PR comments, re-push until clean. Auto-triggered by hook. |
| [**update_timesheets**](skills/update_timesheets/README.md) | Submit BambooHR timesheet entries with automatic shift calculation. |
| [**team-lead**](skills/team-lead/README.md) | Orchestrate multi-agent task execution with Developer-A, Developer-B, and Reviewer. |

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

gtools registers two Claude Code hooks that fire automatically — no manual invocation needed. They are active whenever the plugin is installed.

### Pre-commit — code review gate

**Trigger:** any `git commit` (or `rtk git commit`) Bash call.

The hook checks for an approval marker at `/tmp/gtools-review-<sha256-hash>` (hash of project dir + staged diff). If absent, the commit is **blocked** and Claude is instructed to run `/gtools:pre-commit-review`, which:

1. Runs the `code-review` skill on the staged changes (if installed)
2. Iterates fixing any reported issues
3. Creates the approval marker in a separate Bash call, then retries the commit

The two-call pattern is required: the hook fires at the *tool-call boundary*, so the marker must exist before `git commit` runs.

### Post-push — CI watch loop

**Trigger:** any `git push` (or `rtk git push`) Bash call.

After a push, the hook injects context prompting Claude to run `/gtools:post-push-review`, which watches the code-review GitHub Action, applies fixes, commits, and re-pushes until the Action passes.

### Disabling

Hook definitions live in [`hooks/hooks.json`](hooks/hooks.json) and can be disabled in Claude Code settings.

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
