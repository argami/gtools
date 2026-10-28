<div align="center">

<img src="assets/gtools-banner.png" alt="gtools — Agentic development for real workflows" width="100%" />

# gtools

### AI-powered development workflows for Claude Code

**Orchestrate agents · Automate reviews · Streamline Git · Ship with confidence**

[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-8B5CF6?style=flat-square)](https://claude.ai/code)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-argami%2Fgtools-181717?style=flat-square&logo=github)](https://github.com/argami/gtools)

**[Get started](#quick-start) · [Skills](#at-a-glance) · [Contribute](#contributing)**

</div>

---

**gtools** is a collection of seven skills for [Claude Code](https://claude.ai/code). It brings Git and pull-request automation, iterative code reviews, multi-agent task orchestration, and timesheet management into your development workflow.

Designed to reduce repetitive coordination while keeping review gates and explicit approvals where they matter.

## At a glance

| Skill | What it does |
|:--|:--|
| [**team-lead**](skills/team-lead/README.md) | Coordinate two developers and a reviewer with task dependencies, worktrees, and linear merges. |
| [**pre-commit-review**](skills/pre-commit-review/SKILL.md) | Run a review-and-fix loop before allowing a commit. |
| [**post-push-review**](skills/post-push-review/SKILL.md) | Watch CI review results, fix reported issues, and push again. |
| [**squash-branch**](skills/squash-branch/README.md) | Consolidate branch commits into one after showing a plan and obtaining approval. |
| [**list-unresolved-comments**](skills/list-unresolved-comments/SKILL.md) | List unresolved review threads on the current pull request. |
| [**resolve-comments**](skills/resolve-comments/SKILL.md) | Resolve unresolved or outdated pull-request review threads in bulk. |
| [**update_timesheets**](skills/update_timesheets/README.md) | Calculate and submit BambooHR timesheet entries. |

> [!NOTE]
> The pre-commit and post-push hooks run in an active Claude Code workflow. They are not a replacement for your repository's CI policies or human approval requirements.

## Quick start

### Prerequisites

- [Claude Code](https://claude.ai/code) (CLI or desktop)
- [Git](https://git-scm.com/)
- [GitHub CLI (`gh`)](https://cli.github.com/) for GitHub-related skills

### Install

**Option A — Direct installation (no clone required)**

```bash
claude --plugin-url https://github.com/argami/gtools/archive/refs/heads/main.zip
```

**Option B — Personal plugin marketplace**

Run these commands inside Claude Code:

```text
/plugin marketplace add argami/gtools
/plugin install gtools
```

**Option C — Community marketplace (subject to approval)**

```text
/plugin install gtools@claude-community
```

**Option D — Local development**

```bash
claude --plugin-dir /path/to/gtools
```

**Verify:** Type `/gtools:` in Claude Code. Autocomplete should display the seven available skills.

## Configuration and dependencies

| Feature | Requirement |
|:--|:--|
| GitHub and PR skills | Authenticated `gh` CLI with appropriate repository permissions |
| Team orchestration | Claude Code Agent Teams enabled |
| Timesheets | BambooHR credentials saved to `~/.timesheets_config.json` after initial setup |
| TypeSafe integration | Optional `TYPESAFE_API_KEY` environment variable |
| Review hooks | Plugin installed and hooks enabled |

To enable Agent Teams for `team-lead`:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
claude --teammate-mode auto
```

### Optional: TypeSafe

Selected skills integrate with [TypeSafe](https://typesafe.ai) for calibrated semantic decisions rather than relying solely on keyword matching or inferred intent.

```bash
export TYPESAFE_API_KEY=your_key_here
```

| Skill | TypeSafe responsibility | Fallback without API key |
|:--|:--|:--|
| `update_timesheets` | Detect dry-run intent across phrasings and languages | Keyword matching |
| `squash-branch` | Classify commit-message conventions | Infer from Git history |
| `squash-branch` | Interpret user approval or rejection | Yes/no heuristic |
| `team-lead` | Parse reviewer verdicts | Match `APPROVED` / `CHANGES REQUESTED` |

**TypeSafe is optional:** all supported skills retain their fallback behavior.

## Contributing

Contributions and new skills are welcome.

1. Create `skills/<skill-name>/`.
2. Add a `SKILL.md` with frontmatter metadata and step-by-step instructions.
3. Add a detailed `README.md` for complex skills.
4. Update the version in `.claude-plugin/plugin.json` when publishing.
5. Test the skill via `/gtools:<skill-name>` in Claude Code.

See [CLAUDE.md](CLAUDE.md) for development conventions and skill structure.

## Support

Found an issue or have an idea? [Open a GitHub issue](https://github.com/argami/gtools/issues).

## License

Released under the **MIT License**.
