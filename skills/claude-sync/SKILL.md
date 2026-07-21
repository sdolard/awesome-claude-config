---
name: claude-sync
description: >
  Analyzes the Claude Code release notes since the last processed version and
  produces, in tmp/, a ready-to-execute plan to adapt the project config
  (.claude/settings.json, hooks, permissions, rules, agents, skills, CLAUDE.md)
  to the relevant novelties. Bootstraps the last N releases on the first run.
  Keywords: claude-sync, release notes, upgrade, settings, hooks, permissions,
  rules, catchup, drift, claude code config, changelog.
---

> Extracted from a production codebase — this skill audits/syncs your own
> .claude/ config, so it's largely stack-agnostic by nature.

# Skill: claude-sync

Identifies the delta of Claude Code release notes since the last run and
**produces a ready-to-execute plan** in `tmp/`. No auto-apply: the adaptations
touch sensitive zones (hooks, permissions, agents) that require human
arbitration.

**Principle**: the skill modifies **nothing** in `.claude/**` nor in
`CLAUDE.md`. Its only side-effect is writing a markdown plan into `tmp/`.
Applying the changes happens in a second session, and that application is what
updates `last-seen-version.txt` (the plan's last step).

**Today's date**: !`date +%Y-%m-%d`

**Argument**: $ARGUMENTS (bootstrap size, default 10 if absent and no state
exists)

---

## Execution flow (5 phases)

1. **Phase 0**: read the state (`last-seen-version.txt`) and the CLI's current
   version.
2. **Phase 1**: fetch the official `CHANGELOG.md` via WebFetch.
3. **Phase 2**: classify each delta bullet by category (settings, hook-event,
   permission, agent, skill, statusline, mcp, cli-flag, security, ignore).
4. **Phase 3**: cross-check with the project's existing config to produce
   concrete recommendations (target file, diff, priority).
5. **Phase 4**: write the plan to `tmp/claude-sync-<ISO8601>.md` and display a
   compact inline summary.

---

## Phase 0 — State & current version

1. Read `.claude/skills/claude-sync/last-seen-version.txt`.
   - If present → `LAST_SEEN = <trimmed content>`.
   - If absent → **bootstrap** mode, size = `$ARGUMENTS` or 10 by default.
2. Get the current version: `Bash(claude --version)` →
   `CURRENT = <first extracted X.Y.Z sequence>`.
3. Early-exit cases:
   - If `LAST_SEEN == CURRENT`: display
     `claude-sync: no new release since <CURRENT>, nothing to synchronize.` and
     **exit without writing a plan**.
   - If `claude --version` fails: display the error and exit.

Display inline:

```
claude-sync: LAST_SEEN=<…> CURRENT=<…> (delta mode | bootstrap mode N=…)
```

---

## Phase 1 — Fetch the CHANGELOG

WebFetch on:
`https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`

WebFetch prompt: "Extract the list of releases as (version, bullets) pairs. Keep
the original structure, do not rephrase."

Filter the result:

- **Delta mode**: keep only the versions `> LAST_SEEN` and `<= CURRENT`. Order
  from oldest to newest.
- **Bootstrap mode**: keep only the `N` most recent versions (`N = $ARGUMENTS`
  or 10).

If filtering produces 0 releases: display `claude-sync: no release in the delta`
and exit.

Display inline:

```
claude-sync: analyzed versions <X> → <Y> (N releases)
```

---

## Phase 2 — Bullet classification

For each bullet of each retained release, assign it to **one** category among:

| Category     | Hints in the bullet                                                                 | Potential targets in the project                                                       |
| ------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `settings`   | "Added X setting", "setting now persists", a JSON field name                        | `.claude/settings.json`, `.claude/settings.local.json`                                    |
| `hook-event` | "hook inputs now include", a lifecycle event name (PreToolUse, PostToolUse, etc.)   | `.claude/hooks/*/*.sh`, your Claude Code config-conventions rule, if you maintain one     |
| `permission` | "permission", "auto-approve", "blockedMarketplaces"                                 | `.claude/settings.json` `permissions` section, `.claude/settings.local.json`              |
| `agent`      | "agent", "subagent", "`--agent`", mention of `permissionMode` / agent frontmatter   | `.claude/agents/*.md`, your Claude Code config-conventions rule, if you maintain one      |
| `skill`      | "skill", "SKILL.md", "`/skills`", a new skill frontmatter field                     | `.claude/skills/*/SKILL.md`                                                               |
| `statusline` | "status line", "statusline", "stdin JSON", `effort.level`, `thinking.enabled`       | `.claude/statusline.sh`, your Claude Code config-conventions rule, if you maintain one    |
| `mcp`        | "MCP", "OAuth", `mcpServers`, headers, stdio/HTTP/SSE transport                     | `.claude/settings.json` (MCP servers), your own MCP server implementation (if any), CLAUDE.md |
| `cli-flag`   | Mention of a `--xxx` flag or a `CLAUDE_CODE_*` variable                             | Project scripts, CI workflow files, docs                                                  |
| `security`   | Explicit "security" mention, CVE-like fix                                           | To assess case by case, mentioned in the plan with a severity level                       |
| `ignore`     | UX/visual bug fix with no config surface (scroll, vim mode, paste, spinner, render) | "Skips" section of the plan, for traceability                                             |

**Arbitration rules**:

- A bullet belongs to **one** category only. In case of doubt between two,
  choose the one with the largest config surface and mark the bullet `AMBIGUOUS`
  in the plan.
- **Never** invent a change not present in the CHANGELOG. If a bullet is too
  vague to be actionable, place it in `ignore` with the reason
  `"too vague to be actionable"`.
- Bullets purely internal to Claude Code (paid plan limits, billing, telemetry
  with no hook) → `ignore`.

---

## Phase 3 — Cross-check with the existing config

For each **non-ignored** bullet, read the project's current state and produce a
recommendation. Use only `Read` / `Grep` / `Glob` — **no `Edit` or `Write`
outside the `tmp/` plan**.

| Category     | Mandatory checks                                                                                                                           |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `settings`   | `Read .claude/settings.json` + `Read .claude/settings.local.json`. Does the field exist? At what value? Is it compatible?                  |
| `hook-event` | `Glob .claude/hooks/*/*.sh`. Does a hook of this type exist? Would it benefit from the new field? Otherwise, would a new hook be relevant? |
| `permission` | `Read .claude/settings.json` `permissions.allow` section. Would a new type reduce the prompts?                                             |
| `agent`      | `Glob .claude/agents/*.md`. Does the new capability apply to an existing agent? Should a new one be created?                               |
| `skill`      | `Glob .claude/skills/*/SKILL.md`. Should a skill's frontmatter be updated (adding a newly supported field)?                                |
| `statusline` | `Read .claude/statusline.sh`. Would the new stdin field allow a more precise display?                                                      |
| `mcp`        | `Read .claude/settings.json` `mcpServers` section. Does the change affect an MCP server your project actually uses?                        |
| `cli-flag`   | `Grep` the new flag across scripts, CI workflows, docs. Would there be a legitimate use?                                                    |
| `security`   | Read the note carefully. If the project uses the affected feature, HIGH-priority recommendation.                                            |

**Already-documented guard (recommended, if you maintain such a rule)**: if
your project maintains a rule file that tracks adopted Claude Code novelties
version-by-version (worth adopting if you don't have one yet — e.g.
`.claude/rules/claude-code-config.md`), `Grep` it **first** for every
`hook-event`, `agent`, `statusline`, `mcp`, or `permission` bullet (and
`CLAUDE.md` for project-level conventions). If the feature is already
documented/integrated there, downgrade it to LOW or move it to `ignore` with
reason `"already tracked in <your rule file>"`. Any doc-update recommendation
targets that rule file / `CLAUDE.md`, never a freshly invented file. This
prevents every run from re-proposing already-adopted features. If you don't
maintain such a file, skip this guard — though tracking adopted novelties this
way is exactly what makes the guard possible, and is worth considering.

**Output of this phase**: for each retained bullet, a structured card with:

- **Source**: version + original bullet (literal quote, truncated if long).
- **Category** + priority level (HIGH / MEDIUM / LOW).
- **Target**: `<path>:<approximate line>` or `<path>` if no precise location.
- **Proposed diff**: a `diff` block with a few lines of context.
- **Project justification**: why it is useful to your project (or "marginal
  benefit" if applicable but low-priority).
- **Concrete action**: `Edit`, `Write`, or `Bash <command>`.

**Priority heuristic**:

- HIGH: an applicable security fix, a hook event that would bring a useful
  signal (e.g. `duration_ms`), a new permission type that would unblock
  recurring prompts, an MCP fix affecting a server in use.
- MEDIUM: a useful but non-critical new setting, an enriched statusline, a CLI
  flag usable in an existing script.
- LOW: a cosmetic improvement, a marginal feature, a doc to update to mention a
  novelty.

---

## Phase 4 — Plan generation

Create `tmp/claude-sync-<ISO8601>.md` (e.g.
`tmp/claude-sync-2026-04-24T10-15-00.md`). If the `tmp/` folder does not exist:
`Bash(mkdir -p tmp)`.

Mandatory plan format:

````markdown
# claude-sync plan — <ISO date>

## Analyzed range

- LAST_SEEN: `<version>` or `bootstrap N=<N>`
- CURRENT: `<version>`
- Analyzed releases: <N>

## Summary

| Priority | Category   | Proposed action                       | Target                          |
| -------- | ---------- | -------------------------------------- | -------------------------------- |
| HIGH     | settings   | Add `prUrlTemplate`                   | `.claude/settings.json`         |
| MEDIUM   | hook-event | Log `duration_ms` in PostToolUse      | `.claude/hooks/post-tool-use/…` |
| LOW      | cli-flag   | Document `--from-pr` for another VCS  | `docs/WORKFLOWS.md`             |

## Recommended changes

### [HIGH] `<path>` — <1-line summary>

- **Source**: release `<version>` — "<literal quote of the bullet>"
- **Proposed diff**:
  ```diff
    <context before>
  + <added line>
    <context after>
  ```
- **Project justification**: <why it is useful to your project>
- **Command to run**: `Edit <path>` (or `Write`, or `Bash <cmd>`)

[repeat for each recommendation, order HIGH → MEDIUM → LOW]

## AMBIGUOUS (for the user to arbitrate)

- `<version>` — "<bullet>" → classified `<cat>` but could also be `<other cat>`.
  Decision awaited: <option A> or <option B>.

## Skips (traceability — deliberately ignored bullets)

- `<version>` "<truncated bullet>" — <reason: UX fix, internal telemetry, etc.>
- […]

## Mandatory final step

After validating and applying the changes above, update the state:

```bash
echo "<CURRENT>" > .claude/skills/claude-sync/last-seen-version.txt
```

This command is the **last step** of the plan — to run only if all the retained
changes have indeed been applied. Otherwise, the next `claude-sync` run will
skip the non-applied releases.
````

Then display a compact inline summary:

```
Plan written: tmp/claude-sync-<timestamp>.md
  - Analyzed releases: N
  - HIGH: X / MEDIUM: Y / LOW: Z
  - AMBIGUOUS: A / tracked Skips: S

To execute: open a Claude Code session without plan mode and point it at this
file to apply the retained diffs. The plan's last step updates
last-seen-version.txt.
```

---

## Guardrails

- **No `Edit` nor `Write` outside `tmp/`**. The skill produces a plan, it does
  not apply it.
- **Do not update `last-seen-version.txt` in this skill**. It is the plan's last
  step, run only after a validated application.
- **Do not invent a bullet absent from the CHANGELOG**. Every recommendation
  must literally cite the source.
- **Do not rephrase the bullets** in the "Source" section: a literal quote
  (truncated to 200 characters max if necessary, with `…`).
- **Mermaid format**: if a flow deserves an illustration (a new lifecycle hook
  for example), inline in the `tmp/` plan, never in the console (most
  terminals do not render Mermaid).

---

## First run (bootstrap)

If `last-seen-version.txt` does not exist:

1. Read `$ARGUMENTS`; if absent or non-numeric → `N = 10`.
2. Bootstrap mode active → take the `N` most recent releases of the CHANGELOG,
   do not try to filter by `LAST_SEEN`.
3. The resulting plan carries the `bootstrap N=<N>` mention in the "Analyzed
   range" section.
4. The plan's last step creates the file
   (`echo "<CURRENT>" > .claude/skills/claude-sync/last-seen-version.txt`) — it
   does not need to exist beforehand.

---

## Complementarity

`claude-sync` is centered on **the Claude Code config only**. If you maintain a
separate skill for keeping your project's documentation in sync with the code
(a `sync-docs`-style skill, or your project's equivalent), keep it independent
from `claude-sync`: one handles the Claude Code config, the other handles
product docs — neither should invoke the other.
