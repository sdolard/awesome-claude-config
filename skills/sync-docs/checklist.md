# checklist — Post-application verification

> Extracted from a production codebase — the "sensitive tables" and command
> sections below are illustrative; replace them with your own project's
> cross-referenced tables and check command.

Factual checklist walked through in Phase 5 of `SKILL.md`. Each item is
binary (OK / KO). On a KO: fix it and re-verify before handing back control.

## Build & types integrity

- [ ] Your project's check command (lint/typecheck/build) returns 0.
- [ ] No `.md` file contains broken YAML front-matter (preserve the
      opening/closing `---` if present).

## Internal-link integrity

- [ ] All markdown links `[text](path.md)` point to an existing file.
- [ ] All links `[text](path.md#anchor)` — the anchor exists in the target
      (matching heading).
- [ ] No deleted path (DELETE) is still referenced elsewhere without an
      update (grep the deleted paths across the whole repo).

## Non-regression on stale symbols (Phase 1.d)

For each symbol listed in the "old values" list produced in Phase 1.d of the
SKILL, re-run a final grep:

- [ ] No old config-constant value survives in a `.md` (outside historical
      contexts explicitly framed by "previously" / "old approach").
- [ ] No old version survives in a README or an architecture doc as an
      active version.
- [ ] No old renamed container / service / volume name survives in a
      documented command (outside a diagram legend / post-mortem).
- [ ] No old renamed path survives in operational instructions.

## Date consistency

- [ ] Each touched doc has its "Last updated" field (or equivalent) aligned
      with today's date (if the field already existed).
- [ ] No future date is introduced (typo).

## Consistency of sensitive tables (project-specific — adapt this section)

List here the doc ↔ code pairs in **your** project that are known to drift
silently and deserve an explicit cross-check every run. Examples from a
production instance of this skill, to illustrate the pattern:

- A skill/doc listing runnable scripts, cross-checked against the actual
  executable scripts on disk.
- A setup doc's "required/optional env variables" section, cross-checked
  against the `.env.example` file.
- A tool-reference doc, cross-checked against the actual tool/plugin
  registry in code (same count, same names).
- A supported-models/providers doc, cross-checked against the actual
  provider/model registry in code.
- A CI/build-pipeline README's command list, cross-checked against the
  actual exported pipeline functions.

Replace this list with your own project's equivalents; delete the ones that
don't apply.

## Claude Code config

- [ ] Each touched `.claude/skills/*/SKILL.md` has a valid frontmatter
      (`name` + `description` at minimum).
- [ ] Each touched `.claude/rules/*.md` stays loadable (no broken syntax).
- [ ] No orphan skill or rule (referenced in the top-level config file but
      deleted).

## Git trace

- [ ] `git status` shows only the files planned in the validated plan.
- [ ] No file staged outside the plan's scope.
- [ ] The DELETEs appear in `git status` as `deleted:` (via `git rm`, not a
      plain `rm`).

## Archived plan

- [ ] The scratch plan file (e.g. `tmp/sync-docs-<timestamp>.md`) exists and
      reflects exactly what was applied (or documents the partial
      arbitrations if validation was partial).
- [ ] No stale scratch plan files older than a reasonable window (e.g. 7
      days) are left around (opportunistic cleanup, without breaking a plan
      in progress).

## Language and style

- [ ] Every new section matches your project's documentation-language
      convention.
- [ ] No emojis added unless explicitly requested by the user.
- [ ] No "removed for X" or "added for Y" comments in the docs — the trace
      is in the commit, not in the text.

## Non-regression on a parallel broad-sweep mechanism (if you have one)

- [ ] No file belonging to a parallel broad-sweep skill/mechanism was
      modified (the two must coexist intact — cf. `SKILL.md` §
      Complementarity).
