---
name: sync-docs
description: >
  Sync your project's docs from a GIT REFERENCE (commit-range driven):
  analyzes the commits since a ref, proposes an update/delete/create plan in
  a scratch file, waits for validation, then applies it. Covers docs/,
  CLAUDE.md (or equivalent), .claude/rules/, .claude/skills/, and README
  files across the repo. Keywords: sync docs, commit drift, since ref, commit
  range, README, CLAUDE.md, rules, skill doc. Apply when reconciling docs
  with a specific commit range or git ref. For a broad, non-git-ref-driven
  sweep instead, see § Complementarity below.
argument-hint: "[<git-ref> | HEAD~N | <sha1>..<sha2>]"
allowed-tools:
  Read, Grep, Glob, Edit, Write, Bash(git log*, git show*, git diff*, git
  rev-parse*, git merge-base*, git cat-file*, git rm*, date*, ls*, mkdir*)
---

> Extracted from a production codebase — adapt output paths, the "sensitive
> tables" list (§ checklist.md), and the language convention to your own
> project.

# Skill: sync-docs

Synchronizes the documentation with the actual code state from a git
reference. Unlike a broad periodic sweep (see § Complementarity), `sync-docs`
is **surgical**: it starts from the given commits, analyzes only what moved,
and proposes a validated plan before any write.

**Today's date**: !`date +%Y-%m-%d`

**Scope (argument)**: $ARGUMENTS

**Output language**: adapt to your project's own convention (this skill file
itself stays English-only if that is your Claude Code config convention).

---

## Execution flow (5 phases)

1. **Phase 0**: resolve the git reference → `BASE_REF`, `HEAD_REF`.
2. **Phase 1**: inventory the delta (files, symbols, routes, schemas, tools,
   scripts).
3. **Phase 2**: cross-check with the existing docs (dynamic discovery +
   grep).
4. **Phase 3**: write the plan to a scratch file (e.g. `tmp/sync-docs-<timestamp>.md`),
   ask for validation.
5. **Phase 4**: apply (Edit for existing files, Write for creations, `git rm`
   for deletions).
6. **Phase 5**: verify via [`checklist.md`](checklist.md).

---

## Phase 0 — Git reference resolution

### 0.a — Persistent state file (autonomy)

The skill memorizes the commit synced during the last run in:

```
.claude/skills/sync-docs/last-sync-commit.txt
```

**Format**: a single long SHA1 (40 hex), followed by a newline. No comments,
no additional metadata. This file is **committed in the repo**: it is part of
the skill and must be shared between machines / developers.

### 0.b — Parsing `$ARGUMENTS`

Parse `$ARGUMENTS` according to this table:

| Argument received         | Resolution                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ |
| _(empty)_                  | `BASE_REF` = contents of `last-sync-commit.txt` (cf. 0.c); `HEAD_REF` = `HEAD`.                              |
| `HEAD~N` (e.g. `HEAD~10`)  | `BASE_REF` = `git rev-parse HEAD~N`; `HEAD_REF` = `HEAD`.                                                    |
| `<sha>` (e.g. `a7ecf37`)   | `BASE_REF` = `git rev-parse <sha>`; `HEAD_REF` = `HEAD`.                                                     |
| `<tag>` (e.g. `v1.2.0`)    | `BASE_REF` = `git rev-parse <tag>`; `HEAD_REF` = `HEAD`.                                                     |
| `<ref1>..<ref2>`           | Explicit range: `BASE_REF` = `<ref1>`, `HEAD_REF` = `<ref2>`. Validate via `git rev-parse` on both sides.    |

### 0.c — Reading / bootstrapping the state file (the `_(empty)_` case)

Strict algorithm:

1. **Read** `.claude/skills/sync-docs/last-sync-commit.txt` via `Read`.
2. **If the file is absent or empty** (first run after installation):
   - Bootstrap: `BASE_REF` =
     `git log -1 --format=%H -- <your docs paths, e.g. docs/ CLAUDE.md .claude/rules/ .claude/skills/>`.
   - Announce it explicitly to the user:
     `Bootstrap (last-sync-commit.txt absent) — inferred base: <short sha>`.
3. **If the SHA is no longer reachable** (e.g. deleted branch, force-push,
   rebase) — check via `git cat-file -e <sha>^{commit}`:
   - Fallback: same bootstrap command as above.
   - Announce it to the user:
     `SHA <short sha> not found (rebase/force-push?) — bootstrap fallback: <new short sha>`.
4. **Otherwise**: `BASE_REF` = the SHA read (trim spaces/newline).

Writing the file happens in **the final Phase 4** (cf. 4.e) — only after the
validated plan has been successfully applied.

### 0.d — User output

If `BASE_REF` == `HEAD_REF`, stop: nothing to synchronize. Display the
message and exit cleanly.

Otherwise, display to the user:

```
Analyzed range: <BASE_REF_SHORT>..<HEAD_REF_SHORT>
BASE_REF source: <state-file | bootstrap | explicit argument>
Commits: <N>
```

---

## Phase 1 — Delta inventory

### 1.a — Quantitative inventory

Mandatory commands:

```bash
git log --oneline BASE_REF..HEAD_REF
git diff --name-status BASE_REF..HEAD_REF
git diff --stat BASE_REF..HEAD_REF
```

### 1.b — MANDATORY reading of the content of each non-trivial commit

**Never settle for the commit messages** — they describe the intent, not the
actual change. A commit like `perf(test): maxWorkers 50%` lets you guess that
a value changes, but only the diff reveals what the old value actually was
and what scope the new value applies to. Without that data, a doc/rule citing
the old value stays stale without anyone noticing.

For each commit of the range that is not trivially ignorable (see the filter
below), run:

```bash
git show <sha>
```

**Commits ignorable without reading the diff** (strict filter):

- Pure `docs(…)` whose diff touches **only** `.md` files — the doc is already
  consistent with itself.
- Merges without conflict resolution (`Merge pull request #…`).
- `chore: trigger deploy` / trivial reverts with no code impact.

**Commits mandatorily read at the diff**:

- `feat(…)`, `fix(…)`, `refactor(…)`, `perf(…)`, `ci(…)`, `build(…)`,
  `chore(…)` that touch code or config (not only `.md`).
- Any commit that modifies `package.json`, `*.config.*`, `*.yml`/`*.yaml`,
  `Dockerfile`, infra-as-code files, `.github/workflows/**`.

Typical pitfall class only detectable at the diff (illustrative, not
exhaustive — adapt to your own stack):

| Actual change                                    | Commit message                                          | What becomes stale                       |
| -------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------- |
| A numeric config constant changes value            | A message describing intent, not the old/new values     | Rules/docs citing the numeric value         |
| A CLI flag's value type changes (int → percentage) | Same class of understated commit message                | Command tables in docs/skills              |
| A container/service is renamed                     | `fix(infra): rename X to Y`                              | Shell commands, diagrams                    |
| A dependency/tool version bumps                    | `chore(deps): bump X vN → vM`                            | README prerequisites, architecture docs     |
| A transport changes (TCP → Unix socket, etc.)       | A message naming the mechanism, not both endpoints        | Network diagrams, health-check commands     |

### 1.c — Classify the modified files by type

Classify the modified files by the categories that matter for **your**
project (schemas, API routes, tools/plugins, scripts, infra config, system
prompts, third-party integrations, Claude Code config, dependencies…). If you
maintain a project-specific routing reference (mapping code areas → doc
families), consult it here as a complement — see § Phase 2.c.

### 1.d — Extract the modified symbols from the diffs

From the `git show` read in 1.b, produce an **explicit list of symbols to
grep in Phase 2.b**. A symbol is any token that can appear literally in a
doc:

- **Config constants**: e.g. a numeric setting, a boolean flag value.
- **Versions**: e.g. a language runtime version, a framework version.
- **Container / service names**.
- **Volume / network names**.
- **CLI flags / env vars**.
- **Renamed or moved paths**.
- **URLs / endpoints**.

For each symbol of the "before" column, grep **the old value** in the `.md`
files (Phase 2.b). Any occurrence is a near-certain drift.

### 1.e — Read the current code state

For each significant diff, read **the current code state** (not just the
diff — the truth is what exists now). Note the symbols, export names,
signatures. Useful to write the new value in the doc without picking the
wrong intermediate version.

---

## Phase 2 — Cross-check with the existing documentation

**Source of truth = dynamic discovery**, not a frozen catalogue. The project
evolves: docs appear, disappear, move. The strategy is three-layered:

### 2.a — Dynamic inventory (source of truth)

List the **present state** of the repo before any routing:

```
Glob: **/*.md
  exclude: node_modules, .next, dist, build, coverage, tmp/
```

Then sub-categorize the result by known zone (adapt to your repo's layout):
top-level docs folder, top-level config file (`CLAUDE.md` or equivalent) plus
any per-package copies, `.claude/rules/*.md`, `.claude/skills/*/SKILL.md` (+
colocated assets), every `README.md` across the repo, any other root-level
`.md` (CHANGELOG, CONTRIBUTING, ADR, etc.).

This dynamic list is **the official registry** for this run. Never assume a
path exists or does not exist without having seen it in this Glob.

### 2.b — Grep resonance (factual detection of references)

Consume the list of symbols produced in **Phase 1.d** (not a list re-guessed
from the commit messages). For each symbol — in particular the **old values**
of constants/versions/names — do a `Grep` over all the `.md` files listed in
2.a:

```
Grep: <old value of the symbol> in {list of .md from 2.a}
```

Mnemonic rule: **grep what becomes false, not what becomes true**. Grepping
the new value proves nothing; grepping the old value finds exactly the docs
to update.

Any match is a **factual** doc candidate (proven by grep). It is the most
robust method: it does not depend on a hardcoded mapping.

### 2.c — Per-category routing heuristic (optional companion file)

If your project maintains a routing reference (a doc mapping code category →
doc family — e.g. "a new LLM provider → the models doc family"), consult it
as a **complement**, not a substitute, for cases the grep in 2.b cannot catch
(a genuinely new theme with no prior mention in any doc).

**Priority rule**:

1. If a path listed in that routing reference no longer exists (absent from
   2.a), **flag it as a warning** in the plan (`"routing reference points to
   X, absent from the repo — stale entry, do not fail"`) but do not block.
2. If the grep (2.b) finds a doc **not listed** in the routing reference, it
   is **a priority** — handle it normally.
3. The routing reference is never used as proof that a doc exists or should
   exist.

If you don't maintain such a reference, skip this sub-step entirely — Phase
2.a + 2.b alone are sufficient to run the skill.

Classify each doc candidate as:

- **UPDATE**: the doc contains info that is factually false relative to the
  current code state (e.g. a renamed script, a removed tool, a replaced
  dependency).
- **DELETE**: the doc entirely describes a removed feature/module. Not a
  strike-through, a clean deletion (`git rm`). Explicit justification:
  `"feature X removed in commit <sha>"`.
- **CREATE**: a new module/feature of significance (a new integration, a new
  public API, a new skill/rule) with no corresponding doc. Do not create a
  doc for a small internal rework.
- **SKIP**: the doc is potentially concerned but has no real drift. **List it
  explicitly in the plan** to remove any ambiguity.

**Claude Code config** (always check, independently of any routing
reference):

- A commit introduces a recurring convention → propose updating the relevant
  `.claude/rules/<domain>.md` rule.
- A commit introduces a reproducible workflow → propose a **new skill** (or
  an update of an existing skill).
- A commit modifies hooks / settings → check your Claude Code config rule and
  top-level config file.

**Golden rule**: do not invent changes. If a commit justifies no doc update,
say so explicitly in the Skips section.

---

## Phase 3 — Materialised plan + user validation

Create a scratch plan file (e.g. `tmp/sync-docs-<ISO8601>.md`, or wherever
your project keeps ephemeral working files).

**The complete plan template + the compact inline summary to display** are in
[`plan-template.md`](plan-template.md). Load this file when writing the plan.

**Explicitly wait for the user's arbitration.** Never move to Phase 4 without
explicit feedback.

---

## Phase 4 — Controlled application

Strict constraints:

- **Existing files**: `Edit` only (targeted diff). **NEVER `Write` on an
  existing file** — a full overwrite can break hot-reload tooling watching
  the file and erases the semantic history a diff otherwise preserves.
- **New files (CREATE)**: `Write`.
- **Deletions (DELETE)**: `Bash(git rm <path>)` to trace the deletion in the
  git history.

### 4.a-d — Application order

Application order (critical to avoid transient inconsistencies):

1. **DELETEs** (delete the stale docs first, before editing the upstream
   referrers).
2. **UPDATEs** (incremental updates).
3. **CREATEs** (new files).
4. **Claude Code config** (top-level config file, rules, skills — last, to
   reflect the stabilised state).

If the user validated **partially**, apply only the items they listed. Infer
nothing.

For each doc touched, if the doc contains a "Last updated" field or
equivalent, set it to today's date.

### 4.e — Updating the state file (autonomy)

**Mandatory end-of-Phase-4 step**, regardless of the scope of the validation
(full or partial) — as long as at least one operation was applied:

1. Resolve the long SHA1 of `HEAD_REF`: `git rev-parse <HEAD_REF>` →
   `<NEW_SHA>` (40 hex).
2. Write that SHA to `.claude/skills/sync-docs/last-sync-commit.txt` via
   `Write` (a single SHA, followed by a newline; no other content).
3. Include this file in the final diff visible to the user — it must be
   committed with the doc changes in the **same commit**, so the next run
   starts from the right point.

**Cases where the state file is NOT written**:

- The user refused / cancelled in Phase 3 (nothing was applied).
- No operation of the plan was applied (empty partial validation).
- The range was passed as an explicit argument (`HEAD~10`, `<sha>..<sha>`, an
  arbitrary range) **and** does not end on `HEAD`. In that case, updating the
  state file would mislead the user on the next no-arg run: only write if
  `HEAD_REF` matches `git rev-parse HEAD`.

Announce to the user in the final report:

```
Sync state updated: last-sync-commit.txt → <short sha>
```

---

## Phase 5 — Verification

Walk through [`checklist.md`](checklist.md). If an item fails: fix it and
re-verify. Do not mark the skill as done while an item fails.

Main commands (adapt to your own project's check entry point):

```bash
<your project's lint/typecheck/build command, e.g. pnpm check>
git diff --name-status BASE_REF..HEAD
git status
```

Final report (inline, markdown):

```markdown
## sync-docs — run complete

| File      | Action | Reason            |
| --------- | ------ | ------------------ |
| docs/X.md | UPDATE | <commit / symbol>  |
| docs/Y.md | DELETE | <removed feature>  |
| docs/Z.md | CREATE | <new module>       |

- Range: `BASE_REF..HEAD_REF` (<N> commits)
- Archived plan: `tmp/sync-docs-<timestamp>.md`
- Check command: OK
- Internal links: OK
- `last-sync-commit.txt`: <short sha before> → <short sha after>, or
  `unchanged` if condition 4.e is not met.
```

---

## Guardrails

- **Do not rewrite for the sake of it**: if no info is factually false, touch
  nothing (even if the phrasing could be more elegant).
- **Create nothing outside the validated plan**: any creation outside the
  approved plan is a bug of the skill, not an initiative.
- **Never touch a parallel broad-sweep skill's own files**, if your project
  has one (cf. § Complementarity) — the two mechanisms coexist, they don't
  share state.
- **Respect your project's diagram convention** (e.g. "diagrams belong inline
  in the delivered doc, not in scratch/decision files") if one exists.
- **Language**: match your project's documentation-language convention.

---

## Complementarity with a broad periodic sweep

Some projects also run a broader, non-git-ref-driven refresh — a periodic
sweep across a fixed set of docs, applied without per-item validation (useful
for things like live pricing tables or generated reference docs). If you have
one, the two mechanisms are complementary, not redundant:

| Mechanism             | Trigger         | Scope                          | Validation | Operations             |
| ----------------------- | ----------------- | --------------------------------- | ------------ | ------------------------- |
| broad periodic sweep    | Periodic          | Broad (fixed doc set)             | No           | Update only               |
| `sync-docs` (this skill) | After N commits  | Narrow (targeted on the delta)    | Yes (plan)   | Update / Delete / Create |

`sync-docs` never calls the other one. If you don't have a broad-sweep
mechanism, ignore this section — `sync-docs` stands on its own.
