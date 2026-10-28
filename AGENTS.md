# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**gtools** is a Claude Code plugin providing GitHub workflow automation skills. It extends Claude Code with specialized slash commands for managing PR workflows, branch operations, and timesheet management.

The plugin is published as a Claude Code plugin and installed as `gtools:` prefixed skills. Each skill is self-contained in its own directory under `skills/`, defined by a `SKILL.md` file (frontmatter + markdown documentation).

## Plugin Architecture

```
gtools/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata (name, version, author)
├── skills/                   # Each skill in its own directory
│   ├── squash-branch/
│   ├── resolve-comments/
│   ├── list-unresolved-comments/
│   ├── post-push-review/
│   ├── pre-commit-review/
│   ├── update_timesheets/
│   └── team-lead/
└── hooks/
    └── hooks.json           # Pre/post-tool-use hooks for triggering skills
```

### Skills

Each skill is a prompt template defined in a `SKILL.md` file with:
- **Frontmatter** (`---` delimited): metadata including `name`, `description`, `when_to_use`, optional `arguments` array, and `argument-hint`
- **Markdown body**: detailed step-by-step workflow/implementation instructions

Available skills:

1. **squash-branch** — consolidate all commits since a base branch into one, with auto-generated message
2. **resolve-comments** — bulk resolve unresolved review threads on a PR via GitHub GraphQL
3. **list-unresolved-comments** — fetch and display unresolved review threads
4. **post-push-review** — watch the code-review GitHub Action after push, fix issues, re-push until clean
5. **pre-commit-review** — run code-review skill before committing, iterate until issues resolved
6. **update_timesheets** — submit BambooHR timesheet entries with date parsing and shift calculation
7. **team-lead** — orchestrate multi-developer task execution with Agent Teams (Lead + 2 Devs + Reviewer)

### Hooks

Two hooks are defined in `hooks/hooks.json`:

- **PreToolUse (git commit)**: **blocks** the commit until pre-commit-review creates an approval marker
- **PostToolUse (git push)**: reminds user to run post-push-review skill after pushing

## Skill Development

When adding or modifying skills:

1. Create a new directory under `skills/<skill-name>/` if it doesn't exist
2. Write a `SKILL.md` file with:
   - Frontmatter: `name`, `description`, `when_to_use`, optional `arguments` (array of {name, description, required})
   - Markdown body: step-by-step instructions (numbered, detailed, actionable)
   - Skills are executable plans/prompts, not code — they describe what the agent should do
3. Update `plugin.json` version if publishing

### Naming Conventions

- Skill names use kebab-case: `skill-name` (hyphens, lowercase)
- GitHub thread-related skills: `list-unresolved-comments` (not `gh-unresolved-threads`), `resolve-comments` (not `gh-resolve-threads`)
- Directories match skill names: `skills/list-unresolved-comments/SKILL.md`

## Common Development Tasks

### Testing a skill locally

Skills are invoked by users via slash commands (e.g., `/gtools:squash-branch`). To test during development:

1. Edit the `SKILL.md` to refine the workflow
2. Have a user invoke `/gtools:skill-name [args]` in Claude Code
3. The agent follows the numbered steps in the markdown body
4. Iterate based on feedback

### Updating plugin.json

Bump version when:
- Adding new skills
- Fixing critical bugs in existing skills
- Changing skill behavior in non-backward-compatible ways

Format: `major.minor.patch` semantic versioning.

### Publishing

Currently, skills are discovered by Claude Code's plugin system when installed via the repo path or registry. Ensure all SKILL.md files are present and valid before publishing.

## Key Implementation Details

### GitHub API Integration

Skills that interact with GitHub (`resolve-comments`, `list-unresolved-comments`, `post-push-review`) use the `gh` CLI with GraphQL:

- Queries fetch PR thread metadata (id, isResolved, isOutdated, path, line, comments)
- Mutations (resolveReviewThread) use thread node IDs (start with PR_)
- All queries use `gh api graphql --paginate` for multi-page results

### Git Workflow

- `squash-branch`: uses `git reset --soft` + `git commit` with heredoc message
- `post-push-review` + `team-lead`: use rebase-based workflows (no merge commits) for linear history
- All branch operations in `team-lead` use `--ff-only` merges to maintain linearity

### BambooHR Timesheet API

- `update_timesheets` skill submits entries to `POST https://<BAMBOOHR_DOMAIN>.bamboohr.com/timesheet/clock/entries`
- Credentials: PHPSESSID (cookie), x-csrf-token (header), employee_id (payload)
- Shift schedule: Mon–Thu 9–1, 2–6:30; Friday 9–3; weekends skipped
- Credentials cached in `~/.timesheets_config.json` for future runs

### Agent Teams (team-lead)

The `team-lead` skill spawns a multi-agent orchestration:
- **Lead**: you (the agent running the skill) — orchestrates task assignment, merging, state tracking
- **Developer-A**: implements tasks, commits, reports "TASK DONE"
- **Developer-B**: parallel developer with same responsibilities
- **Reviewer**: applies review checklist, reports verdict

Git workflow uses:
- Persistent git worktrees per developer (or shared checkout if `no-worktrees` flag passed)
- Rebase-only, no merge commits (linear history per design)
- Merge serialization: only one ff-only merge to base at a time
- Progress file (`progress.md` colocated with tasks.md) tracks state for resumability

## Project Status

- Initial plugin structure with 7 skills
- All skills use GraphQL for GitHub operations where needed
- BambooHR integration for timesheet automation
- Multi-agent orchestration for complex task workflows

No active CI/CD, tests, or build process — this is a prompt/workflow plugin, not a compiled application.
