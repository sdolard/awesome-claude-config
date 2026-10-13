# Codex

## Where things go

| Catalogue item | In the project                                                                          |
| -------------- | --------------------------------------------------------------------------------------- |
| Entry contract | `AGENTS.md`, discovered natively from the repository root and nested directories        |
| Rule           | Any Markdown file, reached through an index named in `AGENTS.md`                        |
| Skill          | `.agents/skills/<name>/SKILL.md`, invoked as `$<name>` or selected from its description |

## What differs

- **No path-based rule loading.** Put in `AGENTS.md` one instruction: before
  working on a task, read the rules index and open the rules that match the
  task and the paths touched. Keep `AGENTS.md` itself short — the project
  document has a size limit, and everything in it is paid at every session.
- **A rule that must apply inside one directory only** can live in a nested
  `AGENTS.md` in that directory.
- **No shared form for subagents, hooks or a status line.** Translate the
  intent instead: an independent reviewer becomes a separate read-only run; an
  invariant a hook would enforce becomes repository tooling (a lint rule, a
  commit hook) that holds whatever the engine.
- **Command policy and sandboxing** are configured under `.codex/`, not in the
  instruction files.

Checked: `AGENTS.md` discovery, index-routed rules and `.agents/skills`
discovery are in daily use in the reference project.
