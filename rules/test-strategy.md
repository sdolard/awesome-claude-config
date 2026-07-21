# Test Strategy — When to Write the Test, Relative to the Code

> Governs **timing** (test-first vs test-after vs eval), not *what* to
> test or *how* to run it. Sits upstream of any test-generation guardrail
> your project has — at the moment implementation starts, before a single
> test exists.

## Test-first is conditional, not universal

TDD is an excellent **conditional** tool, not a universally optimal
discipline. "Always TDD" costs more than it returns.

What TDD actually optimizes is **design feedback**, not coverage: writing
the test first forces low coupling and a usable API. Its ROI is high when
the design is **uncertain but specifiable**, and low when the design is
either already obvious or **not yet knowable**.

Treating test-first as a blanket mandate forces it onto exploratory code
(where the API gets thrown away) and onto non-deterministic surfaces
(LLM output, visual UI) where red-green-refactor does not apply —
producing brittle tests that lock in an implementation instead of
protecting behavior. Naming the condition is what makes the tool useful.

## Decision grid

Pick the timing from the **nature of the code**, not from a quota.

| Code under work | Test timing | Why |
|---|---|---|
| Deterministic business logic (decision tables, rules, scoring) | **test-first** | Design feedback is highest here; this is also where mutation testing pays off most. |
| Reproducible bug | **test-first** (red first) | The failing test captures the regression before the fix — the canonical TDD reflex. |
| Refactor under an existing suite | lean on existing tests | The safety net already exists; add tests only for newly exposed branches. |
| Spike / exploration (design not yet known) | **no test-first**, test after | The code is throwaway; a test-first API freezes a shape about to be discarded. Test once the shape stabilizes. |
| LLM / prompts (non-deterministic output) | **eval, not red-green** | Offline evaluation harnesses, prompt snapshots, LLM-graded scoring — not unit TDD. |
| UI / visual | test-after or visual regression | The intent is perceptual; a test-first on markup/CSS tests implementation, not intent. |
| Integration glue where mock cost > test value | test-after, minimal | Don't pay a heavy mock setup for a test that protects little — document the gap explicitly instead of skipping silently. |

**How to apply**: default to test-first on deterministic business logic
and on bugs; test-after on exploratory and integration glue; eval on
LLM/UI surfaces. When unsure whether the design is "knowable yet", treat
it as a spike: write the code, let the shape settle, then test — don't
force a premature contract. The timing choice never relaxes the quality
bar: a test-after test is still subject to whatever written-to-pass ban
your project enforces, and to the mutation-test expectation on covered
modules.

## References

- Beck, K. *Test-Driven Development by Example* (2002) — TDD is a
  **design** technique, not a coverage quota.
- *"Is TDD Dead?"* — Beck / Fowler / DHH conversations (2014): the shared
  conclusion is neither "never" nor "always", but test-first when the
  design benefits from the feedback, test-after when it does not, eval
  when determinism does not exist.
