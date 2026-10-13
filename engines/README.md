# Engine integration notes

The catalogue is written once; each engine consumes it differently. One note
per engine says where each mechanism lives in a project and what has no
equivalent there.

| Mechanism                  | [Claude Code](claude.md)              | [Codex](codex.md)                  | [opencode](opencode.md)            | [Antigravity](antigravity.md)      |
| -------------------------- | ------------------------------------- | ---------------------------------- | ---------------------------------- | ---------------------------------- |
| Entry file                 | `CLAUDE.md` (can import `AGENTS.md`)  | `AGENTS.md`                        | `AGENTS.md`                        | `AGENTS.md` and `GEMINI.md`        |
| Rule loaded by file path   | Yes (`paths:` frontmatter)            | No — route through an index        | No — route through an index        | Yes (`.agents/rules/`, `trigger: glob`) |
| Skill folder               | `.claude/skills/`                     | `.agents/skills/`                  | `.agents/skills/`, `.claude/skills/` | `.agents/skills/`                |
| Subagent definitions       | `.claude/agents/`                     | No shared form                     | `.opencode/agent/`                 | No shared form                     |
| Hooks                      | `.claude/settings.json`               | No shared form                     | Plugins under `.opencode/plugins/` | No shared form                     |

## One layout for every engine

A project used with several engines needs each piece of content exactly once:

```text
AGENTS.md                      the contract every engine reads
CLAUDE.md                      one line: @AGENTS.md
<rules folder>/INDEX.md        which rule to read for which task
<rules folder>/*.md            the rules, as plain Markdown
.agents/skills/<name>/SKILL.md the skills, shared frontmatter only
.claude/skills/<name>          relative link to ../../.agents/skills/<name>
```

- `AGENTS.md` names the rules index and tells the agent to read the matching
  rule before working on a task. That one instruction is what replaces
  path-based loading on the engines that lack it.
- Claude Code and Antigravity can also load a rule by file path, each with
  its own folder and frontmatter. Path loading is an optimization on top of
  the index, never a replacement: Codex and opencode only have the index.
- A skill keeps `name` and `description` in its frontmatter. A field only one
  engine understands is added in that engine's copy or adapter, never in the
  shared file.

## How these notes were checked

Each note ends with a "Checked" line stating what was observed on a real
command-line session and what is taken from the engine's documentation
without having been observed. Engines move fast: re-check before relying on a
detail.
