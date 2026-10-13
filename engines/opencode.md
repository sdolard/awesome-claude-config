# opencode

## Where things go

| Catalogue item | In the project                                                                    |
| -------------- | --------------------------------------------------------------------------------- |
| Entry contract | `AGENTS.md`, discovered natively                                                  |
| Rule           | Any Markdown file, reached through an index named in `AGENTS.md`                  |
| Skill          | `.agents/skills/<name>/SKILL.md`; `.claude/skills/<name>/SKILL.md` is read too    |
| Subagent       | `.opencode/agent/<name>.md`                                                       |

## What differs

- **No path-based rule loading.** Route through the rules index from
  `AGENTS.md`, as on Codex. The `instructions` list of `opencode.json` can
  load more files at startup, but each one is paid on every session: prefer
  the index.
- **A skill reachable through both skill folders** (a physical folder and a
  link to it) must not be listed twice. Check the skill list once after
  linking.
- **Hooks are plugins**, under `.opencode/plugins/`. Same rule as everywhere:
  code that runs on the user's machine is proposed, not self-installed.
- **Permissions** (which files may be read or edited, which commands ask) are
  declared in `opencode.json`.

Checked: `AGENTS.md` discovery, `.opencode/agent/` and plugins are in daily
use in the reference project. Skill discovery from both folders is stated by
that project's configuration and was not re-observed while writing this note.
