# Frontend/UI Engineering Guidelines — Portable Methodology

> **Integration note for a Claude Code instance reading this file**: this
> document is a generic methodology extracted from a production Next.js/React
> codebase, stripped of that project's product specifics. Do not copy it
> verbatim into `CLAUDE.md`. Instead:
>
> 1. Read each section below and decide which principles genuinely apply to
>    *this* repo's stack and current pain points — skip what doesn't fit.
> 2. **Don't default every principle to a Rule.** Triage each one by what
>    kind of constraint it actually is, and match it to the right Claude
>    Code mechanism:
>    - A **judgment-dependent convention** (naming, when to extract a
>      component, which mutation path to use) → a scoped **Rule** under
>      `.claude/rules/*.md`, `paths:`-scoped to the relevant directories, or
>      global (no `paths:`) for stack-wide conventions like naming/RSC
>      boundary.
>    - A **deterministic invariant with zero legitimate exceptions** (e.g.
>      "never hand-edit the generated primitives folder") → a **Hook**
>      (`.claude/settings.json` `PreToolUse`, blocking the edit outright) or
>      repo tooling (an ESLint rule, a schema constraint), not prose a model
>      could rationalize past under time pressure. See §1 below for the
>      concrete case this applies to.
>    - A **repeatable multi-step workflow** someone would want to invoke on
>      demand (e.g. "review this UI diff for motion-token/testid/RBAC-mirror
>      compliance") → a **Skill** (`.claude/skills/*/SKILL.md`).
>    - A **review persona** that must stay independent from whoever authored
>      the code (§12 below) → a dedicated, read-only **Agent**
>      (`.claude/agents/*.md`, tools restricted to Read/Grep/Glob — no Edit,
>      so it can only critique, never quietly rewrite).
>    - Session status telemetry (Statusline) has no natural fit for UI
>      constraints in this list — skip it unless a concrete need surfaces.
> 3. **Hooks execute arbitrary shell and change what actions are silently
>    blocked for every future session** — do not self-install one from this
>    doc. Propose the hook to your user explicitly and get their OK before
>    adding it to `settings.json`; this document is a set of suggestions to
>    evaluate, not a self-executing authorization to modify tool permissions.
> 4. Register each new Rule/Skill/Agent file in this repo's own index
>    (`.claude/rules/INDEX.md` or equivalent) if that pattern exists here, so
>    it stays discoverable rather than silently added.
> 5. Where a principle references "a contract test" or "an ESLint rule", that
>    is a pointer to *build* one for this repo — the guideline is worthless
>    without the enforcement, per the "tooled rule over prose" principle in
>    § 8 below (which itself carries a proportionality guard against
>    over-tooling a small repo — apply that same guard to config-mechanism
>    choices, not just to code-level lint rules).

---

## 1. Component layering: primitives vs domain design system

Two distinct layers, never conflated:

- **Primitive layer**: a low-level, unstyled-or-minimally-styled component
  library (shadcn/ui-style, installed via CLI rather than hand-written, or
  any equivalent headless-component approach). Note this is a genuine
  governance choice, not the only valid one: shadcn's own philosophy is that
  code is copied *into* your repo precisely so you can edit it freely.
  Locking the folder against direct edits (regenerate via CLI only) trades
  away that copy-and-own flexibility for update-mergeability and
  consistency — worth it in a large team where drift is the bigger risk,
  not automatically the right call in a small one. **If you do adopt the
  lock, enforce it as a Hook** (a `PreToolUse` block on the folder path),
  not as a Rule asking the model nicely not to edit it — this is exactly the
  "deterministic invariant, zero legitimate exceptions" case the
  integration note's mechanism-triage step (above) calls out.
- **Domain design system**: a second layer of higher-level components that
  compose the primitives into the patterns *this specific product* repeats
  (e.g. a KPI card, an empty-state block, a data table with loading/empty/
  sorted/paginated states). This layer lives in application code, not the
  primitive package.

**Heuristic for when to extract a domain component**: the moment the same
composition of primitives (e.g. `Card > CardHeader > CardTitle` with a
specific text/size pattern) is copy-pasted a third time across different
pages, extract it into the domain design system rather than continuing to
duplicate. Document the extracted component with a short usage snippet
(props, one working example) directly in a README colocated with the
component folder — this becomes the thing a reviewer points to instead of
re-explaining the pattern each time.

**Anti-pattern to block in review**: a new page reaching for raw primitives
to reassemble a pattern the design system already covers. Raw primitives stay
legitimate only for genuinely one-off layouts.

## 2. Motion/animation as a token system, not inline values

If the product has any non-trivial animation surface (transitions, loaders,
panel entrances), treat motion as design tokens with a single source of
truth, not as inline magic numbers scattered across components:

- One **pure, dependency-free token module** exporting duration/easing/
  stagger constants — pure so it can be imported into the smallest possible
  bundle (a loader script, a UMD build) without pulling in the rest of the
  app's dependency graph.
- **Duration scale** grounded in a perceptual budget, not arbitrary
  round numbers: micro-interactions fastest, standard transitions next,
  panel/resize slower, loaders slowest — a common target is keeping
  interactive UI transitions under ~400ms. Note this specific figure is a
  design-community convention (echoed in Material Design's motion
  guidance), not a strict derivation from the Doherty & Thadani (1982)
  system-response-time literature it's often attributed to — treat it as a
  reasonable default to tune, not a hard physiological limit.
- **Easing language** tied to physical metaphor, not raw cubic-bezier values
  sprinkled inline: an "entering" curve decelerates, an "exiting" curve
  accelerates, an "emphasized" curve for prominent panels. Avoid linear or
  steep ease-in-out for UI motion — the perceived quality comes from
  deceleration at the end of travel.
- **Respect `prefers-reduced-motion`** — treat it as mandatory even though
  its formal WCAG success criterion (2.3.3, Animation from Interactions) is
  Level AAA, i.e. above the Level AA baseline most compliance targets
  require. Gate all non-essential motion behind it as a matter of product
  quality, not just a compliance checkbox: both in CSS (a single global
  media-query block that new animations inherit automatically) and in
  JS-driven geometry changes (re-evaluate before every such change, so a
  mid-session OS-level toggle is honoured). Looping/auto-playing motion also
  falls under the separate, Level-A criterion 2.2.2 (Pause, Stop, Hide) —
  don't assume reduced-motion handling alone covers it.
- **Forbidden patterns**: `transition: all` (list explicit properties to
  avoid incidental layout/paint cost), hardcoded durations/easings in inline
  styles (defeats the single source of truth), permanent `will-change`
  (GPU memory cost), and animating content that reflows during streaming
  (e.g. incrementally-rendered text) — the jank is worse than no animation.
- **If tokens exist in two representations** (e.g. a TS module *and* CSS
  custom properties, because CSS can't import TS), pick one canonical source
  and lock the mirror with an automated contract test that fails on drift —
  never rely on "remember to update both" as the enforcement mechanism.

## 3. Stable selectors for E2E-critical interactive elements

Any interactive element (`button`, `input`, custom control) that a browser
E2E suite asserts against needs a **stable, documented selector contract**
independent of the visible label or CSS classes — visible copy changes
(i18n, marketing tweaks) should never break a test. Convention: a
`data-testid="<scope>-<role>"` kebab-case attribute (e.g. `chat-send`,
`search-input`), with companion `data-*` attributes for dynamic context
(index, id) when a test needs to disambiguate a list. Enforce it with a
lint rule flagging native interactive elements missing the attribute in the
scoped directory, rather than trusting reviewers to remember.

## 4. React Server Components boundary (if using Next.js App Router / RSC)

Default every component to a Server Component; add the client directive only
when the component genuinely needs client-side hooks, event handlers,
browser APIs, or a client context provider. Treat "pure data fetch + render"
components as Server Components even if adjacent code is client-heavy —
pushing the client boundary down the tree (rather than hoisting it up)
keeps the client bundle smaller and server rendering cheaper. Enforce
`exhaustive-deps` lint on hooks unconditionally; a missing dependency in a
client component is a stale-closure bug waiting to happen, not a style nit.

## 5. Server mutation architecture: pick one path deliberately

If the framework offers multiple mutation entry points (e.g. Next.js Server
Actions vs Route Handlers), pick one deliberately and document *why*, rather
than letting both patterns coexist ad hoc. Criteria that matter: does the
flow need streaming responses, custom middleware (CSRF, rate limiting, a
non-standard auth mode), or does a mutation library's assumptions clash with
either flow. This does not have to mean a single path for the whole app — many
codebases legitimately mix, e.g., Server Actions for simple form mutations
and Route Handlers for streaming/webhooks/non-standard auth. What matters is
per-surface *consistency with a documented criterion*, so a new call site
can tell which path applies by checking the criterion rather than by
guessing from nearby code or reintroducing a pattern that was deliberately
ruled out for that surface.

## 6. Role-based UI must mirror the authorization model exactly

If the product has RBAC, the UI layer must reflect it precisely, not
approximately:

- Read-only roles get their action buttons/controls hidden or disabled, not
  merely a backend 403 on submit — a visible-but-broken control is worse UX
  than no control. This is a UX layer on top of authorization, **never a
  substitute for it**: the backend guard/permission check remains the actual
  security boundary regardless of what the UI shows or hides. Treat any
  code path that relies on "the button isn't rendered" as the sole
  protection against an unauthorized action as a security bug.
- Centralize role-comparison helpers (`hasMinRole`, `isAboveRole`, escalation
  rules — "can only invite/promote to a role strictly below your own") in one
  shared module; never reimplement the comparison inline per page.
- Any invariant with system-wide safety implications (e.g. "there must always
  be at least one top-level admin") is enforced at the guard/permission layer,
  not left to individual page logic to remember.

## 7. Config editors must consume the same resolution path as runtime

If the product has an admin/config surface that edits behavior the running
app later reads (feature flags, ordered lists, per-tenant toggles), the
editor UI and the runtime consumer **must import the same resolution
function and the same ordering/default constants** — never a locally
redeclared parallel list. A config editor showing options in a different
order, or with different defaults, than what the runtime actually applies is
a silent-divergence bug class that typecheck and generic tests won't catch;
it needs its own explicit contract test asserting "admin display order
equals runtime resolution order."

Corollary: any state a system can end up in via a direct DB/API write made
*outside a migration or intentional backfill* (i.e. ad hoc seeding, manual
debugging inserts, hand-crafted demo data) should also be *producible
through the admin UI as it ships today*. If such a value can't be entered
through the real UI, treat the value itself as invalid rather than
special-casing it — this is what keeps dev/seed data honest as a rehearsal
of what a real user can actually reach, and it surfaces missing UI early
instead of after a user reports a stuck flow. Genuine schema migrations and
deliberate backfills are a different category and are exempt — this rule
targets accidental/undocumented state, not planned data operations.

## 8. Enforce invariants with tooling, not prose alone

Every UI invariant worth writing down as a rule is worth automating as soon
as it's technically feasible: an ESLint rule for a forbidden inline pattern,
a contract test for a token/config mirror, a schema constraint for a data
shape. Documentation alone drifts — a rule that only lives in a markdown
file will eventually be violated by someone (human or agent) who didn't
happen to read it at the right moment. The doc still carries the *why*; the
tooling carries the *what*, and blocks the regression at commit/CI time
instead of relying on review vigilance.

**Proportionality guard**: this cuts both ways. Before adding a new ESLint
rule or contract test, check whether an existing mechanism (a type, a
schema constraint, an architectural boundary already in place) already
guarantees the invariant — re-enforcing something the code structurally
already prevents is over-constraint, not rigor, and a small codebase can
drown in bespoke lint rules faster than it accrues real risk. If no tool
fits the invariant cleanly, say so explicitly and fall back to documentation
rather than forcing an awkward automation.

## 9. Naming conventions (adapt casing to your language, keep the categories)

| Type              | Convention             |
| ----------------- | ----------------------- |
| Components         | `PascalCase`            |
| Hooks               | `useX`                  |
| Utils/functions     | `camelCase`             |
| Types               | `PascalCase`            |
| Constants           | `SCREAMING_SNAKE_CASE`  |

## 10. Module boundary: barrel (index) files need a quantified threshold

If the language/bundler supports re-export barrel files, don't decide
per-folder by gut feel (this causes review friction and inconsistent import
styles within the same codebase). Pick a concrete, auditable threshold —
e.g. "a folder gets a barrel only once ≥3 external call sites import it
directly" — and grep-audit against it periodically. Exceptions worth
carrying over: folders that are themselves namespaces containing
sub-folders should *not* get a root barrel (the re-export surface becomes
too broad, defeats tree-shaking, and risks name collisions between
same-named siblings); test/internal files are never re-exported.

## 11. Test timing for UI: mostly test-after or visual, rarely test-first

Unlike deterministic business logic (where writing the test first pays off
in design feedback), UI/visual code rarely benefits from strict red-green
TDD — the intent is perceptual, and a test written against markup/CSS before
the visual shape has stabilized tends to test implementation detail, not
intent. Default to test-after (or visual regression / snapshot tooling) for
UI, reserving test-first for the deterministic logic that *drives* the UI
(a scoring function, a validation rule, a state-machine transition) rather
than the rendering itself.

## 12. Cross-perspective review on accessibility/public-contract UI changes

A reviewer that is also the author (human or AI) is structurally weaker at
catching what it missed the first time — LLM-as-judge research documents
this self-preference bias formally for AI judges (Zheng et al., 2023); the
analogous risk for a human re-reading their own diff is a plausible
extension of the same mechanism, not something that citation itself
measured. Rather than a vague "review more carefully" instruction, make it
a concrete gate: UI changes touching accessibility (focus order, ARIA
roles, contrast, reduced-motion), or changing a component's public
prop/contract consumed by other teams, require a second reviewer or a
different model/tool pass **before merge** — not as a courtesy step, but as
a named condition of "done" for that class of change. Changes without those
two properties (a purely internal one-off page tweak, say) don't need this
gate — reserve it for where a missed defect is expensive to notice later.

**Materialize this as an Agent, not just a Rule reminder**: a dedicated,
read-only subagent persona (Read/Grep/Glob only — no Edit/Write, so it can
critique but never quietly rewrite the diff it's reviewing) whose whole job
is this second look. A Rule can *state* the gate; only a distinct persona
with restricted tools structurally *guarantees* the reviewer isn't the same
context/bias as the author. If the checklist this agent runs (motion-token
compliance from §2, testid contract from §3, RBAC-mirror from §6) is stable
and repeatable, package it as an invocable **Skill** the agent follows,
rather than re-deriving the checklist from prose each time.

---

## Sources this was extracted from

A production Next.js 16 / React 19 / Tailwind CSS v4 / shadcn-ui codebase
with: a public embeddable widget (motion-token system, §2-3), an internal
admin portal with RBAC (§1, §6-7), and repo-wide TypeScript/testing
conventions (§8-11). Stack specifics (exact framework versions, package
names) were intentionally left out — replace the concrete mechanisms (ESLint
rule, contract test, CLI-based component generation) with whatever your own
stack's equivalent is; the *shape* of each guideline is what's meant to
transfer.

---

## Beyond UI: the rest of the config

This file covers the frontend/UI slice specifically. The rest of the
methodology extracted from the same production codebase — process and
engineering-discipline guidelines that aren't tied to any UI stack — lives
in a `.claude/`-shaped tree below, ready to drop into another project's own
`.claude/rules/`, `.claude/skills/`, `.claude/agents/`. The same integration
note above applies: read, decide what genuinely fits your repo's current
pain points, and re-tool each item into whichever Claude Code mechanism
(Rule / Hook / Skill / Agent) actually matches the kind of constraint it is.

### `rules/`

| File | What it covers |
| --- | --- |
| [`git-workflow.md`](rules/git-workflow.md) | Conventional Commits, atomic commits, squash-merge rationale, a commit-linter apostrophe gotcha, a narrow standing push/PR autonomy pattern. |
| [`code-quality.md`](rules/code-quality.md) | TypeScript strictness baseline, `satisfies` over `as`, exhaustive-switch on discriminated unions, branded ID types, a JSON `undefined`-stripping gotcha, a module-isolation gotcha, "fix all errors during check, not just yours." |
| [`test-strategy.md`](rules/test-strategy.md) | When to write a test relative to the code — test-first is conditional (Beck), not universal; a decision grid by code nature. |
| [`test-generation.md`](rules/test-generation.md) | Contract-first guardrail for LLM-generated tests: a 5-step workflow, forbidden written-to-pass patterns. |
| [`development.md`](rules/development.md) | Diagnostic discipline (measure before optimizing, pivot on contradiction) + the written-to-pass test anti-pattern catalogue. |
| [`mutation-testing.md`](rules/mutation-testing.md) | Coverage anti-patterns (Marick 1999), mutation score vs. line coverage, contract-first PR-review questions for tests. |
| [`measurement-cost.md`](rules/measurement-cost.md) | Dosing expensive LLM/CI validations — cheap-mode iteration vs. one expensive final measure, targeted CI re-runs, cache-hit pitfalls. |
| [`analysis-and-audit.md`](rules/analysis-and-audit.md) | Methodology for any audit/transverse review: mandatory diagrams, canonical verdicts, debt-acceptance-is-the-user's-call, limits of static analysis, ROI precondition. |
| [`session-focus.md`](rules/session-focus.md) | Scope-guardian discipline against session drift; cosmetic-vs-structural follow-up triage (Cunningham, Fowler). |
| [`architecture-review.md`](rules/architecture-review.md) | Cross-tier second-opinion mechanism (a different model tier reviews a plan/decision before it's final). Companion: [`agents/second-opinion.md`](agents/second-opinion.md). |
| [`promoted-diagrams.md`](rules/promoted-diagrams.md) | Ownership and update-obligation discipline for diagrams promoted into permanent documentation. |
| [`llm-configuration.md`](rules/llm-configuration.md) | Honor a model vendor's tuned defaults instead of overriding generation parameters without measurement. |
| [`prompt-engineering.md`](rules/prompt-engineering.md) | Prompt-engineering structure, techniques, and anti-patterns (contrastive framing, over-constraining). |

### `skills/`

| Folder | What it covers |
| --- | --- |
| [`review-local/`](skills/review-local/SKILL.md) | Multi-agent local code review: perspective-based fan-out, evidence-grounded anti-hallucination, risk-gated adversarial jury, an LLM-failure-mode compensation table. |
| [`functional-review/`](skills/functional-review/SKILL.md) | 8 lenses for reviewing business logic specifically ("is this the *right* logic"): Fagan, Decision Table, Boundary Value, and more. |
| [`start-ticket/`](skills/start-ticket/SKILL.md) | Disciplined ticket kickoff: Definition-of-Ready gates, duplicate detection, branch-vs-worktree decision, a BLUF briefing before planning. |
| [`github-issues/`](skills/github-issues/SKILL.md) | Epic/sub-issue methodology on a GitHub Projects-style board, including an epic-vs-milestone orphan-ticket check. |
| [`claude-audit-config/`](skills/claude-audit-config/SKILL.md) | Audits your own `.claude/` config against current Claude Code capabilities — settings, hooks, agents, rules, skills. |
| [`claude-sync/`](skills/claude-sync/SKILL.md) | Diffs your project's config against the Claude Code CHANGELOG since the last version you processed, produces a plan (never auto-applies). |
| [`meeting-summary/`](skills/meeting-summary/SKILL.md) | Turns a call/meeting transcript into an actionable summary (BLUF, Pyramid Principle, SMART, DACI, faithfulness-checked). |
| [`sync-docs/`](skills/sync-docs/SKILL.md) | Git-ref-driven documentation sync: finds what moved, writes a plan, waits for validation before applying. |

### `agents/`

| File | What it covers |
| --- | --- |
| [`second-opinion.md`](agents/second-opinion.md) | Read-only subagent persona for the cross-tier second-opinion mechanism above — critiques, never rewrites. |

### `statusline/`

| File | What it covers |
| --- | --- |
| [`statusline.sh`](statusline/statusline.sh) | Session telemetry status line (branch/worktree/PR, model, effort, context %, cost, 5h burn-rate) with responsive wrapping and a 256-color heat palette. Three segments are optional/companion-file-dependent and no-op gracefully if you don't build the mechanism they read. |
