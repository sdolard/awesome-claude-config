# Development Discipline — Diagnosis, Optimization & Test Honesty

> Extracted from a production codebase — the test-runner commands, Docker
> orchestration, and DeepEval/LLM-conversation-specific test tooling were
> intentionally left out. What transfers is the discipline itself.

## Diagnostic & optimization discipline

These principles apply to any non-trivial work — performance investigation,
debugging, refactoring, architecture changes. Repeated violations cost hours,
not minutes.

### Measure before optimizing

Run a **quantified baseline** before any change. "It's slow" is not a
diagnosis; "the build takes 94s, 93s of which is a single step" is. Without a
baseline, you cannot tell whether a change helped, hurt, or did nothing. If
your project has a benchmarking skill/command, use it as the default entry
point for this step rather than eyeballing wall-clock time.

### Pivot when the data contradicts the hypothesis

If a number contradicts your theory, **the theory is probably wrong** — don't
dig in, reformulate the hypothesis from the data.

One project's postmortem of a slow-CI investigation illustrates the pattern:
the initial hypothesis ("machine X is slower than machine Y") was refuted by a
measurement showing the opposite; the next hypothesis ("it's an I/O
bottleneck") was refuted by a profiler breakdown showing most of the time in
an unrelated overhead; a third hypothesis ("the build cache is broken") was
refuted by logs showing the cache correctly skipping a step that was silently
failing upstream. Only a fourth hypothesis held. Each pivot, taken alone,
looked plausible as the answer — digging in on any of the first three would
have cost hours for zero gain.

### Prefer structure over discipline

When you have the choice between a **convention** (a written rule to respect,
e.g. "add a comment annotation at the top of every such file") and a
**structure** (mechanical enforcement, e.g. a file-naming convention a build
tool reads automatically) — always prefer structure. Conventions depend on
human vigilance; structures don't. A file name is visible in a directory
listing; a comment is not, and gets forgotten the moment someone copy-pastes a
file.

### Issue-first for multi-step work

As soon as a piece of work exceeds roughly 30 minutes, touches several layers,
or requires several decisions, create a tracking issue **before** starting.
Without a ticket, the reasoning (pivots, decisions, measurements) gets lost in
the commit history. With one, there's a linear trace reconstructable at any
time.

## Written-to-Pass Tests (FORBIDDEN)

A **written-to-pass** test passes without validating anything about the
actual behavior of the code. It artificially inflates coverage and produces a
false sense of security. Never write one, and flag any you find in review.

**Operational definition**: a test is written-to-pass if at least one of the
following applies.

| Anti-pattern | Example | Why it's a trap |
|---|---|---|
| Tautological | `expect(() => throwOnZero(0)).toThrow()` when the code is literally `if (x === 0) throw` | Reproduces the code's own `if`, catches no regression. |
| Trivial assertion | `expect(result).toBeDefined()`, `expect(obj).toHaveProperty("id")` with no value check | Passes with any reasonable implementation. |
| Mock-only test | `expect(mockFn).toHaveBeenCalled()` without checking the payload or an observable effect | Tests the implementation's wiring, not its behavior. |
| Structure test | `expect(Object.keys(result).length).toBe(3)` | Locks the shape, not the semantics. |
| Happy-path only | A single `it("works")` test on a trivial input | Doesn't cover the branches (null, empty, max, edge). |
| Overly generic evaluator criteria (LLM-graded tests) | A criterion so broad it passes for any plausible implementation of the feature, not just this one | Redundant with deterministic assertions; costs a model call for zero signal. |
| Assertion redundant with the type system | `expect(typeof x).toBe("string")` when the type checker already guarantees it | Duplicates the type check. |
| Coverage-driven (written to hit an uncovered line, no invariant behind it) | An `it` whose only purpose is to bump the percentage | Dilutes the signal. Document the gap instead. |

**Questions to ask BEFORE writing a test**:

1. **Which business rule does this test protect?** If the honest answer is
   "none, I just want to execute this line" — don't write it.
2. **If I break the implementation, will this test fail?** Mentally apply a
   plausible mutation (remove a filter, flip a `>=`, drop a `where` clause).
   If the test still passes, it's written-to-pass.
3. **Can I state the invariant in one business sentence?** ("A resource is not
   readable across tenant boundaries," "a count includes items that reached
   *at least* this stage.") If the sentence revolves around function/mock
   names instead, it's testing implementation, not behavior.
4. **Is there a stronger deterministic assertion available?** Prefer
   `expect(rows).toHaveLength(1); expect(rows[0].label).toBe("X")` over
   `expect(fn).toHaveBeenCalled()`.

**When in doubt, don't write it.** A documented coverage gap beats a test
that lies. If a line can't be justified by a business invariant, maybe it
shouldn't exist (dead code, a defensive guard nothing can trigger, an error
handler catching the impossible).

**Audit immediately after generating tests**: re-read each `it`/`test`
against the 4 questions above and delete anything that fails, *before*
running the suite — don't wait for a reviewer to catch it.

**Exceptions**:

- Tests validating input at a **system boundary** (parsing an external
  request, deserialization) are legitimate even if the type system already
  covers the shape — they guard against malicious or malformed payloads, not
  just type mismatches.
- A regression test for a documented bug is always valid, even if it
  superficially looks tautological, **provided** it carries a comment
  pointing at the original incident (e.g. `// BUG: ...` plus a ticket
  reference).

---

## Sources this was extracted from

A production TypeScript monorepo combining a fast unit-test suite with an
LLM-conversation evaluation harness; the diagnostic-discipline examples come
from a multi-hour CI-performance investigation, generalized here. Concrete
commands, container orchestration, and the conversation-evaluation-specific
anti-patterns were intentionally left out — see the root README's integration
note for how to re-attach this to your own test runner and CI.
