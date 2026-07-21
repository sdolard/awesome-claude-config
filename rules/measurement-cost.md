# Measurement & CI Cost Levers

> Governs **how expensive validations are dosed** during a session
> (LLM-driven corpus evals, expensive test suites, CI pipeline runs).
> Complements a test-strategy doc (which tests to write, when) — this is
> about how much to pay **per run**.

## Corpus/eval measures: cheap mode to iterate, expensive mode once at the end

If a measurement is real LLM calls or otherwise expensive per run (e.g.
an eval corpus with a "run N times and average" knob):

- During iteration, run it at the **cheapest** setting (N=1) as a
  pass/fail smoke check.
- Reserve the **expensive, high-N** setting for **at most one final
  measure**, when closing a PR or an epic whose acceptance rests on the
  measured bands — never per-commit.

**Why**: each run is real cost (API calls, compute, wall-clock). If the
acceptance bands already absorb single-run variance, N=1 is a valid
smoke signal during iteration; tripling every loop multiplies cost
without changing any decision.

## One expensive measure per PR

A PR carries **one** final expensive measurement. Re-measure mid-PR only
when a change touches the measured path itself (the logic under test,
not an unrelated refactor or a doc/test-only commit).

## Dependency freshness precondition before a decision-grade measurement

Before a final high-cost measurement that will **decide** something
consequential (a model swap, a library migration, a config change with
real cost implications), verify the relevant SDK/library is at its
latest published version.

**Why this matters, concretely**: one project measured a benchmark
against an SDK version that was bumped to a newer release only 33
minutes after the decision was made — the newer version wasn't the
cause of the swap, but it proved the measurement had run one-to-several
releases behind what actually shipped days later. A stale dependency
during a decision-grade measurement makes the decision untraceable.

**How to apply**:

- Check freshness right before the final expensive measure, never during
  cheap-mode iteration (that would multiply cost per the section above).
- If behind by a patch/minor with no breaking surface touched by the
  code under test → bump first, then measure on the bumped dependency.
- If bumping is out of scope (breaking major, unrelated risk) → state
  explicitly in the decision record which version was measured, so a
  later drift is traceable rather than silently assumed current.

## CI re-runs: targeted job only

- When a CI run fails on a **known-flaky** signature, re-run that job
  only — never the whole pipeline.
- A red job with a diff that plausibly explains it is **not** flaky —
  investigate before any re-run.
- A targeted re-run of a single job only relaunches that job; other jobs
  that had failed in the previous attempt are typically copied over
  unchanged, not re-executed. Confirm a job actually re-ran (via your
  CI's API) before reading its result as fresh signal.
- **A content-addressed/cached CI backend can replay a stale result
  instead of re-testing** — in both directions. A manual rerun of an
  unchanged commit can replay a cached failure; less obviously, what
  looks like a fresh run of a genuinely new commit can also replay a
  cache entry if the runner judges the relevant inputs unchanged, even
  when they actually differ from what the current pipeline definition
  would produce. Tell-tale: a suspiciously fast top-level "cached"
  marker on the job's outermost step in the raw log, as opposed to
  normal incremental caching on internal sub-steps; an abnormally small
  exported artifact is a secondary tell.
- **This cuts both ways on a merge-gating job too**: a cached stale
  *pass* can silently let a broken commit through just as easily as a
  cached stale *fail* can block a good one. If your CI backend supports a
  cache-buster on the top-level call (e.g. keying on run attempt or
  commit SHA), wire it into every merge-gating and LLM/E2E job — that's
  the durable fix, not a manual check every time. Until it's wired
  everywhere, never assume a green **or** red cache-backed gate is fresh
  signal without checking for a top-level cache hit first.

## Guards live in code, never duplicated as instructions

When a cost/safety guard is enforced deterministically in code or CI
config, don't restate it as prose in agent instructions/prompts. That
duplication creates a second source of truth that drifts. The
instruction file can explain *why* the guard exists; it should not carry
the guard itself once tooling enforces it.

## Interaction with a "validate locally before push" policy

These levers dose the *volume* of runs; they never downgrade the
validation *tier*. Skipping a local pre-push validation for speed can
still be a reasonable call under time pressure, but it must stay
explicit ("local quick check, full validation pending"), never silent.
