# Audit checklists — Detailed reference

Companion file of `SKILL.md`. Loaded by zone via progressive disclosure.

> **Guiding reminder**: the field/key/event tables below are **memory aids**,
> not the source of truth. The truth is the **spec fetched in Phase 1**. In case
> of divergence, the spec prevails. **Never remove a field on the sole grounds
> that it is missing here** — check the spec first. The checklist asks
> questions, it does not assert answers.

> **Section numbering**: §1–§9 map one-to-one to SKILL.md Zones 1–9 (same
> order); §10–§11 are the transverse checks (cross-file, over-engineering) run
> in Phase 4 and the transverse axis.

---

## §1 Settings & Permissions

### 1.0 Validate keys vs `$schema` (priority)

- [ ] For each key of `settings.json` / `settings.local.json`: is it listed in
      the fetched settings spec (Phase 1)? An unknown key is a **silent no-op**.
- [ ] Known cases to check: `maxSkillDescriptionChars` (NOT
      `skillListingMaxDescChars`); `skillListingBudgetFraction`; `outputStyle`;
      `statusLine`; `worktree`; `sandbox`; `autoMode` (top-level).
- [ ] Deprecated keys present? (e.g. `includeCoAuthoredBy` → `attribution`;
      `voiceEnabled` → `voice.enabled`).

### 1.1 Cross-file duplicates

- [ ] Identical permissions in both files → remove from the local one.
- [ ] `enableAllProjectMcpServers: true` (local) makes `enabledMcpjsonServers`
      redundant.

### 1.2 Permission anti-patterns

- [ ] `Bash(find:*)` → Glob; `Bash(grep:*)` → Grep.
- [ ] A build/test command pre-approved for local invocation but not for how
      the project actually runs it — e.g. `Bash(npm test:*)` pre-approved when
      the project always runs tests through a container wrapper
      (`docker exec ... npm test`), so the pre-approval never actually matches.

### 1.3 Permissions to question

- [ ] `Bash(curl:*)` (WebFetch exists), `Bash(source:*)`, `Bash(python3:*)`,
      `Bash(psql:*)`, `Bash(npx:*)` → actually needed? pre-approval justified?

### 1.4 `skillOverrides`

- [ ] Each key designates an **existing** skill (project or bundled). Dead entry
      (renamed/removed bundled one) → remove. Verify via `/skills` or the spec.
- [ ] Valid values: `on` / `name-only` / `user-invocable-only` / `off`.

### 1.5 `autoMode` / `worktree` / `sandbox`

- [ ] `autoMode` is a **top-level** key
      `{environment?, allow, soft_deny, hard_deny}` (NOT under
      `permissions`); `$defaults` supported.
- [ ] `worktree.baseRef`: value conformant to the spec (`fresh` / `head`…).
- [ ] `sandbox.network`/`filesystem`: conformant structure.

### 1.6 WebFetch domains & Skill permissions & MCP

- [ ] Each `WebFetch(domain:...)` still useful.
- [ ] Each `Skill(name)` matches an existing skill; user-invocable skills absent
      from permissions → add if needed.
- [ ] `.mcp.json`: no hardcoded credentials (detail §6).

---

## §2 Hooks

### 2.1 Supported events (cross-check with the Phase 1 spec)

- [ ] Is each configured event in the **fetched list**? Do not presume a
      deprecation — confirm.
- [ ] Reference (to cross-check, not fixed): `SessionStart`, `Setup`,
      `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`,
      `PermissionRequest`, `PermissionDenied`, `PostToolUse`,
      `PostToolUseFailure`, `PostToolBatch`, `Notification`, `SubagentStart`,
      `SubagentStop`, `Stop`, `StopFailure`, `PreCompact`, `PostCompact`,
      `SessionEnd`, `InstructionsLoaded`, `ConfigChange`, `FileChanged`…
- [ ] Valid matcher for the event (e.g. `SessionStart`:
      `startup/resume/clear/compact` — a `startup|resume` matcher misses
      `/clear` and `/compact`).

### 2.2 Unadopted events / types (opportunities)

- [ ] `PostToolUseFailure` (log tool failures), `InstructionsLoaded` (debug rule
      loading), `SessionEnd` (end-of-session cleanup vs `Stop` which fires every
      turn), `SubagentStart/Stop`.
- [ ] Types `mcp_tool` / `prompt` / `agent` (beyond `command`/`http`).

### 2.3 Output format

- [ ] Fields consistent with the event: `hookSpecificOutput`,
      `permissionDecision` (PreToolUse), `decision.behavior`
      (PermissionRequest), `additionalContext`, `updatedToolOutput`
      (PostToolUse), `terminalSequence`.
- [ ] Exit codes: 0 = success (stdout JSON parsed); 2 = block; other = warning.

### 2.4 Individual scripts & robustness

- [ ] Shebang, error handling, consistent `timeout` in **seconds** (longer if
      the hook shells out to a container), degraded case handled when a
      dependency the hook relies on is unavailable.
- [ ] Any auto-formatting hook (PostToolUse on Edit/Write): cost/latency
      proportional to what it actually buys, especially if it shells out to a
      container or a slow formatter.

---

## §3 Agents

### 3.1 Frontmatter — cross-check with the fetched sub-agents spec

| Field                       | Notes (to confirm via spec)                                         |
| ---------------------------- | --------------------------------------------------------------------- |
| `name`, `description`       | Required                                                             |
| `tools` / `disallowedTools` | `disallowedTools` applied before `tools`                            |
| `model`                     | `sonnet`/`opus`/`haiku`/full ID/`inherit` — **default `inherit`**   |
| `maxTurns`                  | Max turns                                                            |
| `skills`                    | Preload skill content                                                |
| `mcpServers`                | Inline or reference                                                  |
| `hooks`                     | Agent lifecycle                                                      |
| `memory`                    | **`user` / `project` / `local`** (not `agent`/`none`)               |
| `permissionMode`            | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan` |
| `isolation`                 | `worktree`                                                           |
| `effort`                    | `low`…`max`                                                          |
| `background`                | `true` if long-running                                               |
| `color`                     | `red`/`blue`/`green`/`yellow`/`purple`/`orange`/`pink`/`cyan`       |
| `initialPrompt`             | Auto first turn if the agent = main session                          |

### 3.2 Tools ↔ role consistency

- [ ] An agent that "fixes" without `Edit` → fix the description or the tools.
- [ ] A read-only agent without `disallowedTools: Edit, Write` → add it.

### 3.3 Overlap, usefulness, model

- [ ] Overlap between agents with similar responsibilities, or an agent vs a
      Claude Code built-in capability (e.g. `/review`).
- [ ] Actual usage (Phase 2.5).
- [ ] `model` suited to cost/complexity; a cheaper tier for simple ones.

### 3.4 Memory scope (user decision)

- [ ] `memory: user` (machine-local, not shared) vs `project` (git-shared). If
      learnings are repo-specific → propose `project`. **Submit to the user, do
      not decide.**

---

## §4 Rules

### 4.1 Native mechanism (confirm via the memory spec)

- [ ] `.claude/rules/*.md` + `paths:` frontmatter is **native** (path-scoped).
      Do not treat it as a suspect invention.
- [ ] Rules without `paths:` = **always** loaded (CLAUDE.md priority) →
      permanent context cost.

### 4.2 `INDEX.md`

- [ ] It is **not** a native loader. Its `paths: .claude/rules/**` only loads it
      when editing the rules. It is a human index — do not rely on it for actual
      loading. Verify it is not misleading.
- [ ] Stale references; all listed rules exist and vice versa.

### 4.3 `paths:` & content

- [ ] Glob patterns matching existing files; brace expansion `{ts,tsx}`
      supported.
- [ ] Redundancy with CLAUDE.md / other rules.
- [ ] Rules > 200 lines → break down; global rules → check conciseness.

---

## §5 Skills

### 5.1 Valid frontmatter — cross-check with the fetched skills spec

> `allowed-tools` AND `paths` **ARE supported** for skills. Never remove them
> on a stale assumption they aren't — confirm against the fetched spec first.

| Field                        | Supported | Notes                                                     |
| ------------------------------ | ----------- | ------------------------------------------------------------ |
| `name`, `description`        | Yes       | `description` ≤ 1,536 chars (with `when_to_use`)          |
| `when_to_use`                | Yes       | Trigger phrases; counts toward the 1,536 cap              |
| `argument-hint`, `arguments` | Yes       | `arguments` = named positionals                            |
| `disable-model-invocation`   | Yes       | `true` = pure manual invocation                            |
| `user-invocable`             | Yes       | `false` = hidden from the `/` menu                         |
| `allowed-tools`              | **Yes**   | Tool pre-approval while the skill is active                |
| `model`                      | Yes       | + `inherit`                                                 |
| `effort`                     | Yes       | `low`…`max`                                                 |
| `context`                    | Yes       | `fork`                                                       |
| `agent`                      | Yes       | agent type if `context: fork` (default `general-purpose`)  |
| `hooks`                      | Yes       | skill-scoped hooks                                          |
| `paths`                      | **Yes**   | globs limiting activation (same format as rules)            |
| `shell`                      | Yes       | `bash` (default) / `powershell`                             |

- [ ] Any field **absent from the fetched spec** → report it (and only then
      consider removal).

### 5.2 Size & conciseness

- [ ] `SKILL.md` < 500 lines (doc tip); beyond → progressive disclosure
      (companion files).
- [ ] Concise body: it stays in context after invocation (recurring cost).

### 5.3 Description & matching

- [ ] Relevant keywords (grep the code for what the skill is meant to catch);
      not too generic; "Apply when" or `when_to_use` present for matching.

### 5.4 Invocation & usage

- [ ] `disable-model-invocation` / `user-invocable` consistent with the intent.
- [ ] Actual usage (Phase 2.5); skills < 30 lines → do they warrant a skill?

### 5.5 Companion files

- [ ] Large skills → annexes referenced from the body, loaded on demand.

---

## §6 MCP (`.mcp.json`)

- [ ] `mcpServers`; `type` (`stdio` / `http` / `streamable-http` / `sse`
      **deprecated**); `command`/`args`/`env` (stdio) or `url`/`headers` (http).
- [ ] **`alwaysLoad`** (valid v2.1.121+): to **question**. Enabling it on many
      servers loads all tools at startup, **neutralises Tool Search** (which
      defers by default), and **blocks startup** until connection (cap 5
      s/server). Reserve it for a small number of tools used every turn.
      Otherwise → recommend removal (user decision).
- [ ] `${VAR:-default}` expansion in `command`/`args`/`url`/`headers` (cwd
      robustness; `${CLAUDE_PROJECT_DIR:-.}`).
- [ ] No hardcoded credentials. Per-server `timeout` (ms) if needed.
- [ ] Scope: `.mcp.json` = project (versioned, shared).

---

## §7 Statusline (`.claude/statusline.sh` + `statusLine`)

- [ ] `statusLine`: `type: command` / `command` / `refreshInterval` (**in
      seconds**, min 1) / `padding`.
- [ ] Script: dependencies (`jq`, `git`), robustness, reading the session JSON
      on stdin (`cost.*`, `rate_limits.*`, model, git).
- [ ] Best-effort side-effects (e.g. a burn-rate snapshot) non-blocking.

---

## §8 Output styles (`.claude/output-styles/*.md`)

- [ ] Frontmatter: `name` / `description` / `keep-coding-instructions` /
      `force-for-plugin`.
- [ ] **Major trap**: without `keep-coding-instructions: true`, a custom style
      **removes** the built-in SWE instructions (scope, comments, verify). If
      the body claims to "keep the coding behaviour" without this field →
      `leaky abstraction` → fix by adding the field.
- [ ] `outputStyle` (settings) references an existing `name` (built-in:
      `Default` / `Proactive` / `Explanatory` / `Learning`, or custom).

---

## §9 Memory & CLAUDE.md

### 9.1 CLAUDE.md

- [ ] ≤ 200 lines (doc target); beyond → migrate the detail to path-scoped rules
      / skills. **Slimming decision = user.**
- [ ] `@import` (`@path`): possible organisation (but loads at launch, no
      context gain).
- [ ] `.claude/commands/` absent = OK if the project's convention is to merge
      commands into skills instead.
- [ ] `claudeMdExcludes`: relevant in a multi-team monorepo.

### 9.2 Auto-memory

- [ ] `MEMORY.md` ≤ 200 lines / 25 KB; no session-specific content.
- [ ] Listed files exist; nothing stale nor contradicting CLAUDE.md / rules.
- [ ] Project-specific feedback sitting in `~/.claude/.../memory/` that is
      actually a durable project convention, not a private session note — that
      content belongs in a versioned `.claude/rules/` file instead.

---

## §10 Cross-File Dependencies

- [ ] Agent `skills:` → skill exists; Settings `Skill(X)` → skill exists.
- [ ] Hook scripts (settings.json) → existing and executable `.sh` files.
- [ ] Rule `paths:` → patterns matching existing files.
- [ ] `skillOverrides` / `outputStyle` → existing targets.
- [ ] Orphans (unreferenced scripts); phantom references.

---

## §11 Over-Engineering — 5 Universal Questions

To apply to each element:

1. **Conformant to the spec?** (if not: incorrect, to fix — not REMOVE by
   default).
2. **Actually used?** (Phase 2.5; no trace → REMOVE candidate).
3. **Duplicates a built-in?** (native capability → REMOVE/SIMPLIFY).
4. **Complexity proportionate?** (lines vs usage frequency).
5. **Token cost?** (always-on: global rules, CLAUDE.md, skill descriptions).
