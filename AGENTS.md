# Agent entry point

This repository is a **catalogue**, not a configuration to copy. It holds
project-neutral rules and skills for coding agents, distilled from a
production codebase. Whatever engine you are — Claude Code, Codex, opencode,
Antigravity — this file is your entry point here.

## What the user most likely wants

They pointed you at this repository to bring part of it into **their own
project**. Do that in four steps:

1. **Read before proposing.** Use [`rules/INDEX.md`](rules/INDEX.md) to find
   the rules that match the user's stated pain points, and the `skills/`
   folders for repeatable workflows. Skip what does not fit their stack.
2. **Pick the mechanism per item**, not one mechanism for everything:
   - a judgment-dependent convention → an instruction file the engine loads
     (a rule);
   - a repeatable multi-step workflow invoked on demand → a skill;
   - a deterministic invariant with no legitimate exception → tooling (a lint
     rule, a hook, a schema constraint), never prose a model can rationalize
     past.
3. **Read the note for the engine that will run in their project**, under
   [`engines/`](engines/): it says where each mechanism lives and what has no
   equivalent there. When the project uses several engines, follow
   [`engines/README.md`](engines/README.md) § One layout for every engine.
4. **Adapt, then propose.** Replace every `<placeholder>` and shell variable
   with the project's own values, rewrite examples to its stack, and show the
   user the resulting files before writing them. Anything that executes
   commands or changes what is silently allowed (hooks, permissions) needs
   their explicit agreement.

## Layout

| Path                 | Content                                                                     |
| -------------------- | --------------------------------------------------------------------------- |
| `rules/`             | One Markdown file per discipline; `rules/INDEX.md` routes a task to a rule  |
| `skills/<name>/`     | One workflow per folder, `SKILL.md` with `name` and `description` only      |
| `engines/`           | One integration note per engine                                             |
| `agents/`, `statusline/` | Claude Code mechanisms with no shared form (see `engines/claude.md`)    |
| `README.md`          | The frontend/UI methodology, plus the catalogue tables                      |
| `PROVENANCE.json`    | Lock of the generated files                                                 |

## Working on this repository itself

- A file starting with a `GENERATED FILE` comment is regenerated from a
  reference configuration and listed in `PROVENANCE.json`. **Do not edit it
  here**: the change would be overwritten, and the check fails on any
  difference. Report the needed change instead.
- Files without that comment predate the generation pipeline and are still
  written for Claude Code only. They are being regenerated one by one.
- Before proposing a change, run `node --test scripts/*.test.mjs` and
  `node scripts/check.mjs`. The check refuses machine paths, tracker
  identifiers, personal addresses and four-digit issue numbers anywhere in the
  repository.
