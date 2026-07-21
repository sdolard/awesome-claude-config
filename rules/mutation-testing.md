# Mutation Testing — Coverage Anti-Patterns & Contract-First Review

> Extracted from a production codebase — the mutation-testing tool
> configuration, per-module rollout waves, and CI job names were
> intentionally left out. What transfers is the KPI reasoning and the review
> questions.

## Mutation score over coverage, as the priority KPI

Coverage answers "what fraction of the code executed during the tests?" The
mutation score answers "would my tests have detected a bug introduced in this
code?" The two are not equivalent — a tautological test can show 100%
coverage and 0% detection.

**Rule**: for any module under mutation testing, the mutation score **takes
precedence over coverage** as an acceptance criterion. A change that
increases coverage while regressing the mutation score is a signal that
written-to-pass tests were added (cf. a project's "Written-to-Pass Tests"
rule).

**References**: Marick, *How to Misuse Code Coverage* (1999) · Jia & Harman,
*An Analysis and Survey of the Development of Mutation Testing* (IEEE TSE
2011).

## Coverage anti-patterns (Marick 1999)

Five patterns worth rejecting in review without re-litigating each time —
naming them explicitly avoids the same debate resurfacing on every PR.

| # | Anti-pattern | Why it's a trap |
|---|---|---|
| 1 | `coverage > 80%` as a merge threshold | A bare percentage carries zero semantics — 100% line coverage can still return `500` instead of `201`. |
| 2 | Fuzzing / property-based testing counted as "coverage" | The tool becomes its own oracle — it checks that the code doesn't crash, not that it respects its contract. Keep it as a separate, complementary signal, not additive with line coverage. |
| 3 | A single uniform coverage threshold across all modules | A stable utility module and a critical business-logic module don't carry the same criticality — one global threshold either over- or under-constrains one of them. |
| 4 | A slow metric made mandatory in the PR gate | Feedback over roughly 30s tends to get bypassed in practice (skipped, force-pushed past, ignored). Keep expensive metrics (full mutation runs, long end-to-end suites) on a periodic/non-blocking cadence instead. |
| 5 | Double-counting the same path across test suites (e.g. unit + end-to-end) | One logical behavior tested twice by two different tools is still one behavior covered, not two — don't let it inflate a coverage total. |

Marick's original argument — *code coverage measures what was executed, not
what was tested* — is exactly what makes the mutation score the priority KPI
above.

## Contract-first PR review: four questions for any modified test

Any change touching a test file should be able to answer these four
questions, per test added or modified:

| # | Question | If the answer is… |
|---|---|---|
| 1 | What precise bug would this test catch? | "none" → **delete it** |
| 2 | Would it survive a complete rewrite of the implementation (same contract, different code)? | no → **it's coupled to implementation details, rewrite it** |
| 3 | Are the edge cases covered (null, empty, bounds, wrong type)? | no → **complete them** |
| 4 | Would a trivial mutant (`>` → `>=`, `&&` → `\|\|`) be killed by this test? | no → **the assertion is too weak** |

These four questions are a **semantic** guardrail, complementary to whatever
mechanical guardrails a lint plugin or a mutation-testing tool already
enforce — they cover what static analysis can't see: *does this test test
the right thing?*

**Reviewer stance**: if a question goes unanswered, or the answer reveals a
tautological/mock-only test (cf. the anti-pattern table in a project's
"Written-to-Pass Tests" rule), request the deletion or the rewrite before
merge — don't let it in "to fix later."
