# Antigravity

## Where things go

| Catalogue item | In the project                                                                     |
| -------------- | ---------------------------------------------------------------------------------- |
| Entry contract | `AGENTS.md` and `GEMINI.md`, both loaded at startup                                |
| Rule           | `.agents/rules/<name>.md` with activation frontmatter, or any file reached through an index |
| Skill          | `.agents/skills/<name>/SKILL.md`, listed by name and loaded when its topic comes up |

## What differs

- **Two entry files are read.** Keep the shared contract in `AGENTS.md`. A
  `GEMINI.md` is needed only for instructions specific to this engine; when it
  exists, a line reading `@./AGENTS.md` imports the shared contract for tools
  of the same family that read `GEMINI.md` alone.
- **Rules load by path, with their own frontmatter.** A file directly under
  `.agents/rules/` declares a `trigger`: `always_on`, `glob` (with a `globs`
  list, activated when the agent touches a matching file), `model_decision`
  (with a `description`) or `manual`. The catalogue's rules carry no
  frontmatter: add it in the project's copy. Routing through the rules index
  from `AGENTS.md` also works, and is the form shared with Codex and opencode.
- **Mind the size limits.** A single rule file is truncated past 24,000 bytes,
  and the always-active rules share one token budget: scope a rule with `glob`
  rather than leaving it always on.
- **Skills are discovered from `.agents/skills/`**, alongside the engine's
  built-in ones. Only the skill's name and description are in context at
  startup; the body is read when the skill is used. A precise `description` is
  therefore what makes the skill reachable.
- **No shared form for subagent definitions, hooks or a status line.**

Checked: observed on the command-line client with marker files — the content
of `AGENTS.md` and of `GEMINI.md` was available at startup without any file
read, and a skill placed under `.agents/skills/` appeared in the skill list
while its body stayed unloaded. The `.agents/rules/` triggers and the size
limits are taken from the engine's documentation and were not observed.
