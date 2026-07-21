# Promoted Diagrams — Ownership & Update Obligation

> Extracted from a production codebase — concrete file paths and doc names
> were replaced with generic placeholders (`<...>`). Adapt the ownership
> table to your own architecture docs and path-scoping mechanism.

Some diagrams (flowcharts, state diagrams, an architecture map) get promoted
from a session's throwaway working files into permanent documentation. Unlike
prose, a diagram lies **silently** when the code it describes moves — nothing
re-renders it, and nothing fails loudly when it drifts. This rule exists so
whoever (human or agent) edits one of the source files sees the update
obligation *at edit time*, rather than relying on someone remembering to check
later.

## Ownership table (source → diagram)

Keep an explicit table mapping source files/directories to the diagram(s)
that document their behavior. Example shape (replace with your own paths):

| Source | Diagram |
|---|---|
| `<core orchestration module>/**` | `<architecture doc>` §`<state-machine section>` |
| `<classification / ML module>/**` | `<models doc>` (classifier section) |
| `<resilience / fallback module>/**` | `<architecture doc>` §`<resilience section>` |
| `<plugin / module registry>/**`, top-level manifest files (new module added) | `<architecture-map files>` + `<architecture doc>` §`<system overview>` |

## Update obligation (verifiable, not a soft reminder)

If a change modifies a precedence chain, a guard condition, or a
fallback/resilience branch on one of the sources above, update the owning
diagram in the **same change** — or state explicitly in the change
description why not. A vague "keep docs in mind" reminder gets ignored; a
checkable obligation doesn't.

**Trigger = exported/observable behavior change, not any diff.** A rename, a
comment edit, or an internal refactor with no observable behavior change does
not require a diagram update. Firing on every touch would make this rule
noise that gets tuned out.

## No line numbers in promoted diagram labels

A diagram promoted to permanent docs (as opposed to a throwaway session file)
should reference **function/component names**, never line numbers, in node
labels. Line numbers drift on the next unrelated edit; the diagram then lies
about where to look.

## Findings vs. architecture — don't bake review critique into permanent docs

A known limitation surfaced by a review (a code review, a cross-model review,
a manual critique) — e.g. "this fallback is global, not per-dependency" —
belongs in **prose** under the diagram, with a tracking reference, not as a
colored/flagged node inside the diagram itself. The diagram describes the
stable mechanism; coloring a finding into it freezes a critique-in-progress as
if it were permanent architecture, and the color silently lies the moment the
finding gets fixed.

## Source-of-truth header

Every promoted diagram carries a one-line header listing its source files and
the update condition, e.g.:

```text
Source of truth: <fileA>, <fileB> — update when their exported behavior
changes.
```

This is the mirror of the ownership table above (code → diagram there, vs.
diagram → code here) and gives any periodic doc-refresh process a
deterministic anchor to diff against, instead of guessing scope.

## Complementary to, not a substitute for, a periodic doc-refresh sweep

This rule fires **at edit time**, in the context of whoever is touching a
source file — reliable when discipline at commit time is otherwise fragile. A
periodic **catch-up sweep** (a scheduled doc-audit skill or ritual) is still
needed for drift accumulated outside a single change, or missed here. Neither
replaces the other.

## Deliberately not enforced by a CI/pre-commit co-change hook

A pre-commit or CI check that blocks "diff touches `<source file>` without
touching `<diagram doc>`" was considered and rejected: the false-positive
rate is high (most edits to these files are refactors with no behavior
change), and an unenforced warning that fires constantly becomes noise that
gets ignored. Revisit only after real drift is actually observed in practice
— don't build the guard preemptively.
