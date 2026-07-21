# Analysis & Audit Methodology

> Conventions for any audit, transverse review, architectural diagnostic,
> or post-mortem where the reader must be able to challenge the reasoning
> before accepting the verdict.

## A diagram is mandatory, not decoration

Every audited/analysed zone should produce one or more **targeted,
detailed diagrams** (Mermaid or equivalent) that materialize the object
of the analysis. A prose-only verdict is opaque and hard to challenge; a
diagram exposes the structure of the reasoning so the reader can spot
what's wrong faster than by re-reading paragraphs.

- Pick the diagram type that fits the object: state diagrams for FSMs,
  flowcharts for pipelines/dependency chains, hierarchy diagrams for
  registries/layered architectures, a table for cross-matrices (tool ×
  state, package × consumer).
- Annotate explicitly: dead paths distinctly styled, branches never
  reached colored distinctly, live-vs-scaffolded ratio readable at a
  glance, edges labeled with counts (call sites, consumers, LOC) when
  relevant.
- When proposing a refactor, produce a **second diagram for the target
  state** alongside the current state, so the delta is visible.

**Quality gate**: if the zone is trivially flat and a diagram would add
nothing, say so explicitly and use a table instead. No filler diagrams.

## Producer/reviewer split for audits

Audits are produced directly by reading and grepping the actual code —
not delegated to a separate model/tool for the exploration phase, even
under time or cost pressure. A cross-model or cross-vendor review may
challenge the *finished* report, never build it. Delegating the
exploration makes the reviewer both producer and indirect reviewer of
its own work, defeating the point of an independent check.

## Canonical verdicts

Every audited zone should close on exactly one verdict from a fixed set,
e.g.:

| Verdict | Meaning |
|---|---|
| `over-engineered` | Superfluous abstraction, speculative scaffolding, removable dead code. |
| `borderline` | Mixed signal, depends on a product decision or a threshold not yet reached. |
| `justified` | Complexity proportionate to product complexity. Nothing to remove. |
| `accepted debt` | Known and documented under-engineering. |
| `leaky abstraction` | Neither over- nor under-engineered: the abstraction exists and is dimensioned correctly, but its invariant leaks at the edges (concrete, quantifiable leaks — imports, anti-patterns, call sites). |

Pick a single verdict per zone. Naming a fixed vocabulary avoids diluting
distinct failure modes into an undifferentiated "borderline."

## Debt acceptance is the user's call, never the agent's alone

When an audit identifies a gap that could reasonably be classified
`accepted debt` — left as-is without correction — the agent does **not**
make that call alone. It presents the verdict, the quantified cost of
the debt (current impact), and the quantified cost of the fix
(remediation effort), then **explicitly submits the choice** to accept
or reject the debt.

**Why**: accepting debt is a product/business decision, not a purely
technical one. It commits the project long-term (the debt stays until
refused), may impact other work's roadmap, and depends on signals the
agent doesn't see (current priorities, resources, strategic context).
Deciding alone amounts to imposing a trade-off on someone else's behalf.

**Anti-patterns to avoid**:

- Concluding an audit with "nothing to do, it's accepted debt" without
  asking for confirmation.
- Omitting a zone from a report because "the debt there is manageable" —
  the omission is an implicit, silent acceptance.
- Presenting a final "accept this debt" recommendation without exposing
  the quantified fix alternative.
- Deciding not to file a follow-up for an identified gap without
  recording that decision explicitly.

This narrows further for any debt whose failure mode is **directly
user-visible and undesired** in the product's core function (e.g., for a
conversational product, a loop or an ignored user answer) — that class of
finding should never be offered as `accepted debt` regardless of sample
size; propose a fix, or, if root cause is genuinely underspecified, a
non-behavioral first step (targeted telemetry to confirm frequency)
rather than closing the topic.

## Limits of static analysis

Static analysis (reading code, grepping, counting consumers) is enough
to validate reachability and structure. It is **not** enough for zones of
**dynamic dispatch**: plugin registries, event handlers, route handlers
where the selector is a runtime string, LLM tool selection. A statically
reachable branch may never actually execute in production; conversely, a
registered handler may never be invoked by the orchestrator.

For these zones, the static verdict is `justified` or `borderline`,
never `over-engineered` — removal requires runtime data (logs,
monitoring, telemetry). State this limit explicitly in the report. Never
infer removability from low test coverage alone — a lightly-tested path
may be heavily used in production.

## Post-audit auto-enforcement

Every architectural invariant an audit identifies should be materialized
as a **tooled rule** (a lint rule, a schema constraint, a type-level
guarantee, a CI gate) rather than as documentation alone, as soon as
technically possible.

**Why**: documentation alone drifts — a new contributor, human or agent,
won't read the rule at the right moment. A tooled rule fails at
commit/CI time and blocks the regression at the source. For each
invariant named in an audit report, explicitly list the tool that could
enforce it, or justify why none fits. The prose rule remains useful as
context ("why"), but should no longer carry the invariant alone once
tooling exists.

## ROI precondition before a multi-zone audit

Before launching a broad, multi-zone transverse audit, require that **at
least one executable action lead** be identifiable a priori — not after.
If the audit can only produce a map (not a list of actions), the ROI is
negative: a broad audit produces context that will be forgotten before
it's read.

When proposing an audit plan, list the **action hypotheses** per zone —
even approximate ones. If all zones only yield a "likely justified"
prediction, reduce scope to 1-2 zones rather than doing the full sweep. A
targeted audit with a probable action beats a broad audit without one.
This precondition applies to multi-zone audits only — a one-off review of
a single module doesn't need this gate.
