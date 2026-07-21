---
name: claude-audit-config
description: >
  Exhaustive audit of your Claude Code configuration against the official docs
  of the latest version: settings, permissions, hooks, agents, rules, skills,
  mcp, statusline, output-styles, memory. Detects non-conformities, staleness,
  over-engineering, cross-file inconsistencies; produces a correct / missing /
  incorrect table per zone. Keywords: audit, config, settings, hooks, agents,
  rules, skills, mcp, output-styles, statusline, permissions, conformance,
  over-engineering, obsolete, drift, best practices.
---

> Extracted from a production codebase — this skill audits/syncs your own
> .claude/ config, so it's largely stack-agnostic by nature.

# Exhaustive audit of the Claude Code configuration

Confronts every config surface (`.claude/**` + `CLAUDE.md` + `.mcp.json`) with
the **official spec of the latest version**, and produces, per zone, a
**correctly done / missing / incorrect** table + a verdict.

## Guiding principle (to respect without exception)

**Never hardcode the list of valid fields / keys / events.** They evolve at
every release. The only source of truth is the **spec fetched in Phase 1**. The
recall tables in `checklists.md` are memory aids to **cross-check** against the
spec — in case of divergence, the spec prevails.

Corollary: the checklist **asks questions** ("is this field present in the
fetched spec?"), it **does not assert answers** ("this field is not supported").
**Never remove a field on the sole grounds that it is missing from this file** —
check the spec first. An audit that deletes valid config based on a stale belief
is worse than no audit.

**Boundary with `claude-sync`**: `claude-sync` starts from the CHANGELOG and
lists novelties per version (the "temporal drift" axis). This skill starts from
the **reference spec** and checks conformance + over-engineering + actual usage
(the "current state" axis). The two are complementary; do not duplicate the
work of `claude-sync` (do not re-parse the changelog here beyond spotting
unadopted novelties).

## Phase 0: Argument Parsing

Supports optional arguments, e.g. `[--fix|--epic|--section=settings,hooks,agents,rules,skills,mcp,statusline,output-styles,memory]`:

- `--fix`: apply the **safe AND spec-confirmed** corrections (Phase 6)
  non-interactively; the rows marked "after confirmation" / `REMOVE` still
  prompt (`AskUserQuestion`). Never fix debt or a product decision.
- `--epic`: materialise the audit as tracked issues in your project's issue
  tracker — e.g. one epic + one sub-issue per zone on GitHub, via whatever
  issue-tracking skill/workflow your project already has. Skip this flag
  entirely if you don't track audits as issues.
- `--section=X,Y`: audit only the listed zones (`settings`, `hooks`, `agents`,
  `rules`, `skills`, `mcp`, `statusline`, `output-styles`, `memory`).
- No argument: full audit.

## Phase 1: Fetch Latest Spec (REFERENCE — 8 surfaces)

Run **the WebFetch calls in parallel** (a single message). One page per surface
— do not settle for 2 pages, otherwise the non-fetched surfaces fall back on
stale knowledge (root cause of this skill's drift before it was reworked).

1. `https://code.claude.com/docs/en/skills` — skills frontmatter +
   `skillOverrides`/budget
2. `https://code.claude.com/docs/en/sub-agents` — agents frontmatter
3. `https://code.claude.com/docs/en/hooks` — events, types, matchers, I/O schema
4. `https://code.claude.com/docs/en/settings` — top-level keys +
   `permissions`/`autoMode`/`sandbox`/`worktree`/`statusLine`
5. `https://code.claude.com/docs/en/memory` — CLAUDE.md, `@import`,
   `.claude/rules` + `paths`, auto-memory
6. `https://code.claude.com/docs/en/statusline` — `statusLine`
   (`refreshInterval` unit), JSON stdin
7. `https://code.claude.com/docs/en/output-styles` — output-style frontmatter,
   `keep-coding-instructions`
8. `https://code.claude.com/docs/en/mcp` — `.mcp.json`, `alwaysLoad`, Tool
   Search, transports

The `docs.claude.com/en/docs/claude-code/*` pages redirect (301) to
`code.claude.com/docs/en/*` — use the `code.claude.com` form directly.

**Extract and explicitly remember, per surface**:

- the **exhaustive list** of valid fields/keys/events + their
  values/constraints;
- the **deprecated** fields → flag legacy usages;
- the **novelties** not adopted → "Opportunities" section.

**Fallback**: if a fetch fails, DO NOT audit the conformance of that surface
from built-in knowledge (risk of a destructive false positive). Mark the zone
`SPEC UNAVAILABLE — conformance not verified` and continue the other axes
(usage, internal consistency) only.

## Phase 2: Discover & Read All Config

### 2a — Discovery (Glob in parallel)

```
Glob(".claude/agents/*.md")
Glob(".claude/rules/*.md")
Glob(".claude/skills/*/SKILL.md")
Glob(".claude/skills/**/*.md")          # companion files
Glob(".claude/hooks/**/*.sh")
Glob(".claude/output-styles/*.md")
```

The auto-memory store lives **outside** the project root, where `Glob`
(project-scoped, no `~` expansion) does not reach — discover it with Bash:

```bash
ls "$HOME/.claude/projects/${CLAUDE_PROJECT_DIR//\//-}/memory/"*.md 2>/dev/null
```

### 2b — Read (group 6-8 files per message)

Fixed locations: `.claude/settings.json`, `.claude/settings.local.json`,
`.mcp.json`, `.claude/statusline.sh`, `CLAUDE.md`, `~/.claude/settings.json`,
`.claudeignore` (if it exists — otherwise note it is absent; the modern
exclusion mechanism is `claudeMdExcludes` / `respectGitignore`, to confront with
the memory/settings spec).

Dynamic files: everything discovered in 2a.

## Phase 2.5: Usage measurement (skills & agents)

The **usage-driven** axis — a skill/agent at 0 invocations over a sufficient
window is a candidate for removal/promotion/rewrite. **Keep as-is: this is the
strength of this skill, complementary to static analysis.**

### Sources (by priority)

1. **Hook logs** (primary, if configured): if your project logs `Skill`/`Agent`
   tool calls via a `PreToolUse` hook into a file (e.g. `tmp/skill-usage.log`,
   `tmp/agent-usage.log`), read it first — reliable if the oldest date is
   ≥ 30 d (`head -1 ... | cut -f1`). If no such hook exists, skip straight to
   source 2.
2. **JSONL transcripts** (retroactive fallback, always available). Derive the
   project slug portably — do **not** hardcode it, it changes if the repo path
   moves:

   ```bash
   slug="${CLAUDE_PROJECT_DIR//\//-}"   # /Users/you/Dev/MyProject -> -Users-you-Dev-MyProject
   PROJ="$HOME/.claude/projects/$slug"
   # NB: the greps rely on `"name":"Skill"` preceding `"skill":"…"` in the
   # serialised tool call (true today). A zero count must be cross-checked
   # against the hook logs, never read as "unused" at face value (a
   # false-positive REMOVE is the destructive failure mode this skill guards).
   find "$PROJ" -name "*.jsonl" -mtime -90 -print0 \
     | xargs -0 grep -hoE '"name":"Skill"[^}]*"skill":"[a-z0-9_-]+"' \
     | grep -oE '"skill":"[a-z0-9_-]+"' | sort | uniq -c | sort -rn
   find "$PROJ" -name "*.jsonl" -mtime -90 -print0 \
     | xargs -0 grep -hoE '"subagent_type":"[a-z0-9_-]+"' | sort | uniq -c | sort -rn
   find "$PROJ" -name "*.jsonl" -mtime -90 -print0 \
     | xargs -0 grep -hoE '<command-name>/[a-z0-9_-]+' | sort | uniq -c | sort -rn
   ```

### Usage verdicts

- `auto + slash = 0` AND window ≥ 30 d → candidate `REMOVE` or
  `description-rewrite`. Distinguish: `disable-model-invocation: true` /
  `user-invocable: false` → unreachable in auto (verify it is deliberate); vague
  description → rewrite **before** concluding removal.
- `auto = 0` but `slash > 0` → used by users only; assess whether the
  description would benefit from matching for auto-invocation.
- `denied > 0` but `auto + slash = 0` → wrongly throttled by `skillOverrides` /
  permissions → recommend unthrottling.
- Window < 30 d → **do not conclude**; mark
  `insufficient data — re-audit on <date+30d>`.

Output: a `Skill/Agent | auto | slash | denied | static verdict | usage verdict`
table, integrated into the report (Phase 5). The final verdict crosses static ×
usage.

## Phase 3: Analysis per zone

Run the zones **IN PARALLEL** (a single message). For each zone, load the
corresponding checklist from `checklists.md`.

**Transverse axis** — for each element: (1) conformant to the fetched spec? (2)
actually used? (3) duplicates a built-in? (4) complexity proportionate? (5)
token cost? (6) legacy pattern / deprecated field?

**Canonical verdicts** — one per zone, pick exactly one:

| Verdict              | Meaning                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| `over-engineered`     | Superfluous abstraction, speculative scaffolding, removable dead code.                              |
| `borderline`          | Mixed signal, depends on a product decision or a threshold not yet reached.                         |
| `justified`           | Complexity proportionate to actual need. Nothing to remove.                                         |
| `accepted debt`       | Known and documented under-engineering — a conscious trade-off, not an oversight.                   |
| `leaky abstraction`   | The abstraction exists and is dimensioned, but its invariant leaks at the edges (partial coverage). |

(If your project already has its own audit/analysis-conventions doc, cite it
here instead of duplicating this table.) Per-finding severity
(CRITICAL/HIGH/MEDIUM/LOW/REMOVE) remains useful **within** a zone.

### Zone 1: Settings & Permissions (checklists §1)

- **Validate keys vs `$schema`**: does each key of `settings.json` /
  `settings.local.json` exist in the fetched settings spec? An unknown key = a
  silent no-op (e.g. historic: `skillListingMaxDescChars` → real key
  `maxSkillDescriptionChars`).
- Cross-file duplicates; `enableAllProjectMcpServers` vs
  `enabledMcpjsonServers`.
- Permission anti-patterns (`Bash(find/grep:*)` → Glob/Grep); a locally
  pre-approved build/test command that doesn't match how the project actually
  invokes it (e.g. pre-approving `Bash(npm test:*)` when the project always
  runs tests through a container wrapper like `docker exec ... npm test`).
- `skillOverrides`: does each key designate an **existing** skill (project or
  bundled)? Dead entries (e.g. a renamed bundled one) → remove.
- `autoMode` (top-level) / `worktree` / `sandbox`: structure conformant to the
  spec.
- WebFetch domains / `Skill(name)`: still relevant and existing?

### Zone 2: Hooks (checklists §2)

- Is each configured event in the **fetched events list**? (do not presume a
  deprecation — confirm via spec).
- Valid matchers for the event (e.g. `SessionStart`:
  `startup/resume/clear/compact`).
- Allowed hook types (`command/http/mcp_tool/prompt/agent`).
- Output format (`hookSpecificOutput`, `additionalContext`, `updatedToolOutput`,
  `permissionDecision`…) consistent with the event.
- Useful unadopted events (to derive from the spec, e.g. `PostToolUseFailure`,
  `InstructionsLoaded`, `SessionEnd`, `SubagentStart/Stop`).
- Scripts: robustness, error handling, timeouts (in **seconds**), degraded case
  when a dependency the hook shells out to (Docker, a CLI) is unavailable.

### Zone 3: Agents (checklists §3)

- Frontmatter cross-checked with the sub-agents spec (fields AND values, e.g.
  `memory: user|project|local`, `model` default `inherit`).
- Tools ↔ role consistency; read-only agents without `disallowedTools`.
- Useful unadopted fields (`color`, `isolation`, `effort`, `permissionMode`).
- Overlap between agents with similar responsibilities, or an agent that
  duplicates a Claude Code built-in.
- `memory` scope: `user` (machine-local) vs `project` (git-shared) — a choice to
  **submit to the user** if the learnings are repo-specific.

### Zone 4: Rules (checklists §4)

- `.claude/rules/*.md` + `paths:` is a **native** mechanism (confirm via the
  memory spec) — do not treat it as suspect.
- Rules without `paths:` = always loaded (CLAUDE.md priority) → context budget.
- `INDEX.md` is **not** a native loader: it is a human index (its `paths:` only
  loads it when editing the rules). Do not rely on it for loading.
- Redundancy with CLAUDE.md / other rules; rules > 200 lines → break down.

### Zone 5: Skills (checklists §5)

- **Cross-check the frontmatter with the skills spec** — `allowed-tools`,
  `paths`, `context`, `agent`, `when_to_use`, `effort`, `hooks`, `shell`,
  `arguments` are **valid** fields (do NOT remove them: this skill's historic
  error). Only remove a field if it is **absent from the fetched spec**.
- `SKILL.md` size < 500 lines (doc tip); concise body (recurring cost).
- Description + `when_to_use` ≤ 1,536 characters (real cap).
- Invocation-control consistency (`disable-model-invocation` /
  `user-invocable`).
- Companion files referenced from the body.

### Zone 6: MCP (checklists §6)

- `.mcp.json` structure, `type` + transports, `${VAR:-default}` expansion, no
  hardcoded credentials (field-level detail §6).
- **`alwaysLoad`** is the verdict-bearing flag: enabling it broadly neutralises
  Tool Search and blocks startup → recommend removal beyond the few every-turn
  tools (user decision).

### Zone 7: Statusline (checklists §7)

- `statusLine`: `type`/`command`/`refreshInterval` (**seconds**, min
  1)/`padding`.
- Script: dependencies (`jq`, `git`), robustness, JSON stdin reading.

### Zone 8: Output styles (checklists §8)

- Frontmatter conformance + `outputStyle` (settings) → existing `name`.
- **Verdict trap**: a style claiming to "keep the coding behaviour" without
  `keep-coding-instructions: true` → `leaky abstraction` (field-level detail
  §8).

### Zone 9: Memory (checklists §9)

- `CLAUDE.md` / `MEMORY.md` size caps + staleness / duplication (detail §9).
- CLAUDE.md slimming is a **user decision**, not an auto-fix.
- `.claude/commands/` absent = OK if the project has merged commands into
  skills (verify that's actually the convention before flagging an absence).

## Phase 4: Cross-File Dependencies (sequential)

- Agent `skills:` → existing skills; Settings `Skill(X)` → skill X exists.
- Hook scripts (settings.json) → existing and executable `.sh` files.
- Rule `paths:` → patterns matching existing files.
- `skillOverrides` / `outputStyle` → existing targets.
- Orphans (unreferenced scripts); phantom references (settings → non-existent
  file).

## Phase 5: Report Generation

Create `tmp/claude-audit-config-{YYYY-MM-DD-HHmm}.md` (or your project's
equivalent scratch/reports directory):

- **One table per zone**:
  `Correctly done | Missing (opportunity) | Incorrect / non-conformant` — each
  "incorrect/missing" row **cites the doc source** (URL + field/key name).
- **One Mermaid diagram** per zone when the topology clarifies it (otherwise a
  table + a sentence justifying the absence). Diagrams belong in the report
  file, never inline in the conversation (most terminals don't render Mermaid).
- **Canonical verdict** per zone + per-finding severity.
- **Overall synthesis diagram** of `.claude/**` (status per node).
- An **Opportunities** section (unadopted novelties, derived from the spec).
- A **User decisions** section: any gap classifiable as `accepted debt` or any
  product decision (e.g. `memory: user` vs `project`, CLAUDE.md slimming,
  `alwaysLoad`) is **submitted to the user**, never decided unilaterally.

If `--epic`: create an epic + one sub-issue per zone (body = the zone section)
using your project's issue-tracking skill/workflow, status `Done`; fix
follow-ups get their own issue, status `Todo`. Skip this section entirely if
you don't track audits as issues.

Display the report path + a summary of the findings.

## Phase 6: Auto-Fix (if `--fix`)

Apply **only** safe, reversible corrections **confirmed against the fetched
spec**. Two tiers: the unambiguous rows are applied directly; the rows tagged
"after confirmation" (and any `REMOVE`) prompt the user first — `--fix` is not a
blanket bypass. When in doubt → do not fix, leave it as a finding.

| Fix (allowed)                                                               | Condition                                                |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Settings duplicates                                                         | Remove from the lower-priority file                      |
| Unknown settings key (absent from `$schema`)                                | Rename to the real key OR remove, **after confirmation** |
| `skillOverrides` dead entry                                                 | Remove if the target skill does not exist                |
| Missing `disallowedTools` (read-only agent)                                 | Add                                                      |
| Missing `keep-coding-instructions` (output-style that wants to keep coding) | Add `true`                                               |
| Phantom reference (non-existent path)                                       | Fix / report                                             |

**Forbidden in auto-fix**:

- Removing a frontmatter field **present in the spec** (e.g. NEVER remove
  `allowed-tools` or `paths` from a skill — these are valid fields).
- Any decision that is a **debt** or a **product choice** (`memory` scope,
  `alwaysLoad`, CLAUDE.md size) → ask the user, no auto-fix.
- Removing a `REMOVE` element → mandatory **user confirmation**.

For each fix: display a before/after diff.
