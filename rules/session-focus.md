<!-- GENERATED FILE: do not edit by hand. Regenerated from a reference configuration; see PROVENANCE.json. -->

# Session Focus & Follow-up Triage

Guardrail against scope drift within a session, and against the follow-up
backlog turning into an anxiety-inducing pile. It governs how the agent behaves
on every session, regardless of the files touched.

Context this addresses: a common working-mode risk is dispersion — starting on
one objective and drifting, follow-up after follow-up, into tests,
architecture, agent configuration, an unrelated bug. A coding agent is an
**amplifier of that drift**: being exhaustive and eager to help, it surfaces
every imperfection and offers a follow-up for each, which inflates both the
urge to fix now and the fear that not fixing degrades the codebase. This rule
turns that bias into a guardrail.

## Scope guardian

The agent holds the session objective and protects it.

**How to apply**:

- Treat the first concrete objective of a session as the cap. When the user (or
  the agent itself) starts pulling toward an unrelated subject, **name the
  drift explicitly and ask for confirmation before changing course** — do not
  silently follow the digression.
- If the user states a session objective ("this session = fix X, nothing
  else"), enforce it actively: a request that falls outside it gets a "this is
  off the session objective — switch cap, or capture for later?" rather than
  immediate execution.
- The branch name is a drift detector: editing files unrelated to the current
  branch's subject (a bug-fix branch, but the edit touches the agent's own
  configuration) is a signal to stop and confirm intent.

## Follow-up triage: structural vs cosmetic

Not every follow-up the agent can see is debt. Most have **zero interest rate**
(Cunningham 1992): ignoring them forever costs nothing. The agent classifies
every off-scope follow-up out loud before proposing any action.

| Class          | Examples                                                                          | Interest rate                                     | Action                                                                                                                    |
| -------------- | --------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `[cosmetic]`   | ugly test, approximate naming, isolated duplication, local readability nit        | ~0 (never compounds)                              | One line mention, **no ticket**. The user forgets it without guilt. It resurfaces only if it bites again on a later pass. |
| `[structural]` | leaking abstraction, wrong module boundary, shaky public contract, foundation bug | compounds (each new build on top raises the cost) | Flag **loudly**, then fix now or ticket it — never leave it running without a decision.                                   |

**Why**: the fear that "if I don't act, the architecture drifts more and more"
is real, but it applies only to the `[structural]` fraction. Treating cosmetic
items as debt is what produces the unmanageable backlog and the fix-now
dispersion. Naming the interest rate is the skill that dissolves the anxiety.

**How to apply**:

- Default to **not** creating a ticket for `[cosmetic]` items — not for
  everything the agent noticed.
- Decide once, with the user, what the default is for `[structural]` items. A
  workable standing default: ticket it without asking again, attached to a
  fitting parent, and **fix now** instead only when the foundation is young and
  nothing has been built on it yet (Fowler's Technical Debt Quadrant: the
  dangerous debt is the one left running without a decision).
- Never bundle follow-ups in an undifferentiated stream. One mention, one class
  tag.

## Backlog hygiene — obsolescence is a feature

A ticket that rots and becomes obsolete is evidence it was `[cosmetic]`: the
code moved, the problem dissolved on its own. Real `[structural]` debt never
goes obsolete — it gets worse. So periodically closing stale tickets is not
negligence, it is the triage completing itself. The backlog should end up
containing **only structural items**, which keeps it small, relevant, and free
of obsolescence anxiety.

## Backlog navigation: parent ticket → milestone fallback

When selecting the next ticket, a parent ticket that shows **no open child**
is NOT proof that its theme is exhausted. The native parent/child link and
milestone membership can diverge: a ticket may belong to the parent's
milestone without being linked as a child, and the parent's body may not list
its children at all. The body text is never the source of truth for
membership; the native link is.

**Why**: declaring "nothing left here" from the child view alone silently
drops work that is tracked only at the milestone level. The milestone is the
wider container; the child set can lag behind it.

**How to apply**:

- Before concluding a parent ticket is done, check whether it carries a
  milestone. If it does, list the **open** issues of that milestone and
  cross-reference them against the parent's children. Tickets in the milestone
  but not linked as children are candidate work the child view hides.
- Surface those orphans explicitly rather than declaring the theme exhausted.
- When the milestone and the child set match, say so — the cross-check is the
  evidence that tracking is consistent, not noise to omit.
- When the backlog uses one label per phase (see
  [`skills/github-issues`](../skills/github-issues/SKILL.md) § Phase labels),
  query the label rather than re-reading the order table in the parent's body:
  the label survives ticket churn the prose table does not track.

## Closing a child ticket updates its parent

When a child ticket is merged and marked done, **update the parent's body in
the same move**, never as a later pass. The tracker links the two but
propagates nothing, and the section below treats that body — not the child
list — as authoritative when deciding whether the parent can close.

**Why**: the body is the only place the _reasoning_ survives. The child list
answers "how many are closed", never "where does this stand".

**How to apply** — read the body, then:

- move the delivered ticket to done in the parent's own order table, and name
  the **next** one;
- add one line on what shipped, with the pull request reference;
- record any **decision the ticket settled or reversed** — including
  guardrails the implementation proved unnecessary, which a later session
  would otherwise re-propose;
- state the consequence for what remains: a ticket just became reachable,
  blocked, pointless, or urgent. Nothing else records that;
- list a follow-up opened by the delivery in the body's table too, not only as
  a child link.

Skip only when the body says nothing about the delivered ticket (a flat list
of independent items) — say so rather than leaving it silently untouched.

## Closing a parent ticket: children done is necessary, not sufficient

Never close a parent ticket on child completion alone — always read its own
body first, even when every linked child shows closed.

**Why**: the failure mode is a parent whose children are all closed while its
body states a blocking precondition that is tracked as a dependency, not as a
child, and is still open. Closing on the child signal alone marks the work
done while its own stated exit criterion is unmet. The child set answers "is
the scoped checklist complete"; the body answers "is the actual goal reached".
The two can diverge, and the body wins.

**How to apply**:

- Before closing, read the current body, not just the child list. Look for
  stated blocking dependencies, explicit exit conditions, or a scope
  description broader than what the children cover.
- If the body names a blocking ticket, check that ticket's live state — it may
  not be linked as a child at all.
- If the body and the child completion agree, close and say so explicitly: the
  check is the evidence, not noise to skip.
- This applies even when the parent "looks done" — that appearance is exactly
  the trap.

## Any ticket's children answer "is there open work"

The section above covers deciding whether to close a parent. The narrower,
more frequent trap hits **any** ticket, whether or not it is labelled as a
parent: reading its body and comments alone and concluding "still open" or
"undecided" when its **native children** tell a different story. Trackers
generally do not auto-close or auto-comment a parent when every child closes —
the parent can sit open, untouched, indefinitely.

**Failure mode**: a lookup that fetches title, state, body and comments but
omits the children makes a ticket look stalled or undecided. Re-fetched with
its children, it turns out fully implemented and merged, with no closing
comment ever posted — and a decision record already settles the exact question
about to be re-litigated from scratch.

**How to apply**: any lookup that will inform a recommendation ("what's left",
"should I start this", "is this decided") MUST include the ticket's children —
never rely on body and comments alone. Before writing a fresh decision or
recommendation on a ticket, check the children first: an all-closed set with
no closing comment on the parent is a **regularization candidate**, not a
green field. Closing still requires verifying that the children actually cover
the parent's stated scope — check the code, not the count. When they cover
only part of it, what remains is real work, not a regularization: say so and
keep the ticket open.

A corollary on decision records: a record kept only in a local scratch
directory disappears with the next cleanup or checkout. The moment a ticket
relies on one to justify starting work, paste its substance into the ticket —
a path alone becomes a dangling pointer.

## Relationship to audits

This rule is the session-scale counterpart of the discipline that governs
formal audits (see [`analysis-and-audit.md`](analysis-and-audit.md): quantify
the cost of the debt against the cost of the fix, and the user decides). It
applies the same principle to the small follow-ups the agent emits
mid-session, where the decision is lighter but identical in nature:
**classifying a gap as leave-as-is is the user's call, never the agent's
silent omission.**

## References

- Cunningham, W. (1992). The WyCash Portfolio Management System — the original
  technical-debt metaphor: debt is acceptable if serviced; the danger is
  compounding interest.
- Fowler, M. _Technical Debt Quadrant_ (deliberate/inadvertent ×
  prudent/reckless) — the dangerous debt is the one left running without a
  conscious decision.
