# Session Focus & Follow-up Triage

> Guardrail against scope drift within a session, and against a follow-up
> backlog turning into an anxiety-inducing pile. Applies to every session
> regardless of what files get touched.

Context this addresses: a common working-mode risk is dispersion —
starting on one objective and drifting, follow-up after follow-up, into
tests, architecture, config, an unrelated bug. An LLM coding agent
**amplifies that drift**: being exhaustive and eager-to-help, it surfaces
every imperfection and offers a follow-up for each, which inflates both
the urge to fix-now and the fear that not-fixing degrades the codebase.
This rule turns that bias into a guardrail.

## Scope guardian

The agent holds the session objective and protects it.

- Treat the first concrete objective of a session as the cap. When either
  party starts pulling toward an unrelated subject, **name the drift
  explicitly and ask for confirmation before changing course** — don't
  silently follow the digression.
- If the user states a session objective ("this session = fix X, nothing
  else"), enforce it actively: a request that falls outside it gets a
  "this is off the session objective — switch cap, or capture for later?"
  rather than immediate execution.
- The branch name is a useful drift detector: editing files unrelated to
  the current branch's stated subject is a signal to stop and confirm
  intent.

## Follow-up triage: structural vs cosmetic

Not every follow-up an agent can see is debt. Most have **zero interest
rate** (Cunningham, 1992): ignoring them forever costs nothing. Classify
every off-scope follow-up out loud before proposing any action.

| Class | Examples | Interest rate | Action |
|---|---|---|---|
| `[cosmetic]` | ugly test, approximate naming, isolated duplication, local readability nit | ~0 (never compounds) | One line mention, **no ticket**. It resurfaces only if it bites again on a later pass. |
| `[structural]` | leaking abstraction, wrong module boundary, shaky public contract, foundation bug | compounds (each new build on top raises the cost) | Flag **loudly**. Either fix now (young foundation, not yet propagated) or ticket **with explicit sign-off**. |

The fear ("if I don't act, the architecture drifts more and more") is
real but applies only to the `[structural]` fraction. Treating cosmetic
items as debt is what produces an unmanageable backlog and fix-now
dispersion. Naming the interest rate is the skill that dissolves the
anxiety.

**How to apply**:

- Default to **not** creating a ticket. A ticket is for *reversible* debt
  *consciously* deferred — not for everything the agent noticed.
- For `[structural]` items that are still cheap (young, un-propagated
  foundation), the correct reflex is usually to **fix now**, not to
  ticket for "later" where the cost compounds (cf. Fowler's Technical
  Debt Quadrant: the dangerous debt is the one left running without a
  decision).
- Never bundle follow-ups into an undifferentiated stream. One mention,
  one class tag.

## Backlog hygiene — obsolescence is a feature

A ticket that rots and becomes obsolete is evidence it was `[cosmetic]`:
the code moved, the problem dissolved on its own. Real `[structural]`
debt never goes obsolete — it gets worse. Periodically closing stale
tickets is not negligence; it's the triage completing itself. A healthy
backlog ends up containing only structural items, which keeps it small,
relevant, and free of obsolescence anxiety.

## References

- Cunningham, W. (1992). The WyCash Portfolio Management System —
  original technical-debt metaphor: debt is acceptable if serviced; the
  danger is compounding interest.
- Fowler, M. *Technical Debt Quadrant* (deliberate/inadvertent ×
  prudent/reckless) — the dangerous debt is the one left running without
  a conscious decision.
