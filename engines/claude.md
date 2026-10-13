# Claude Code

## Where things go

| Catalogue item | In the project                                                                                 |
| -------------- | ---------------------------------------------------------------------------------------------- |
| Entry contract | `CLAUDE.md`. Keep shared content in `AGENTS.md` and import it with a line reading `@AGENTS.md` |
| Rule           | `.claude/rules/<name>.md`                                                                      |
| Skill          | `.claude/skills/<name>/SKILL.md`, invoked as `/<name>` or selected from its `description`      |
| Subagent       | `.claude/agents/<name>.md` (see [`agents/`](../agents/))                                       |
| Status line    | A script referenced from `.claude/settings.json` (see [`statusline/`](../statusline/))         |

## What only this engine has

- **Path-scoped rules.** A `paths:` list in a rule's frontmatter loads the
  rule when a matching file is read or edited; a rule without it loads at
  startup. Scope a rule to the directories it governs, and keep global only
  what applies to every session, because startup content is paid on each one.
- **Skill frontmatter extensions** such as tool allow-lists, a model or an
  effort level. Add them in the project's copy of a skill; the catalogue's
  skills carry `name` and `description` only.
- **Hooks**, declared in `.claude/settings.json`. A hook runs shell commands
  and changes what is silently blocked or allowed: propose it to the user,
  never self-install one.
- **Subagents and the status line.** The files under `agents/` and
  `statusline/` in this repository are Claude Code artifacts with no shared
  form on the other engines.

## Sharing with other engines

Keep the physical skill under `.agents/skills/<name>/` and make
`.claude/skills/<name>` a relative link to it, so one file serves every
engine.

Checked: the `@AGENTS.md` import, path-scoped rules, linked skill folders,
subagents, hooks and the status line are in daily use in the reference
project.
