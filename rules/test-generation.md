# Test Generation — Contract-First Guardrail for LLM-Written Tests

> Extracted from a production codebase — adapt tool/file names to your own stack.

## Why this exists

An LLM agent (Claude Code, Copilot, or any coding assistant) asked to "write
tests for this function" will, left unguided, read the function's current
implementation and encode its present behavior as the expected one. That is
automated confirmation bias: the test passes today by construction, and will
keep passing after a regression that changes the output to something equally
wrong. This rule governs **test generation** by an LLM agent — a preventive
complement to whatever after-the-fact written-to-pass detection your project's
test-quality guidelines already cover (code review, a test-quality checklist,
mutation testing).

## Contract-First Rule (CRITICAL)

A test proposed by an LLM agent must be derived from the **contract**, never
from reading the source code of the function under test.

**Acceptable contractual sources** (in priority order):

1. Issue/ticket describing the expected behavior
2. A spec or design doc
3. A schema with field-level descriptions (e.g. a Zod/Pydantic/JSON-Schema
   definition documenting each field's meaning)
4. The type signature (input/output types, discriminated unions)
5. A docstring/JSDoc comment describing the invariants
6. A bug report (for a regression test)

**Forbidden source**: reading the body of the function under test to infer
expected behavior. That is automated confirmation bias — the agent observes
the current output and locks it in as "correct", which produces
written-to-pass tests by construction.

**Mandatory fallback**: if no contract is identifiable, the agent must **ask**
for the contract before writing a single test. No generation from intuition.

## Pre-Generation Workflow (strict order)

Before writing any test code, the agent executes these 5 steps in order:

1. **Identify the contract** — explicitly cite the source (issue link, spec
   path, schema name, signature). If none exists, stop and ask.
2. **List the edge cases to cover** — at minimum: `null`/`None`, `undefined`/
   missing, empty input, lower bound, upper bound, wrong type (if the boundary
   accepts an untyped/unknown value), collision, timeout. Enumerate them
   **before** writing any assertion.
3. **Formulate the mutation sentence for each test case** — _"This test would
   fail if X happened in the implementation."_ If the sentence doesn't hold (or
   collapses to "if the function broke somehow"), the test is a
   written-to-pass candidate and must be reformulated or dropped. This is a
   lightweight, manual stand-in for mutation testing (see References) applied
   at generation time rather than after the fact.
4. **Validate against your project's written-to-pass criteria**, if you have a
   documented set (protected business rule identified, mental mutation
   performed, invariant expressible in one business sentence, strongest
   deterministic assertion used rather than a loose one).
5. **Write the code** only once (1)-(4) have satisfactory answers.

## Colocation vs a separate test folder

Pick one convention for where new tests live relative to their source file —
colocated next to the module (`geo/haversine.ts` +
`geo/haversine.test.ts`) or centralized under a parallel `__tests__/` /
`tests/` tree — and hold new code to it consistently, even if legacy modules
still use the other pattern.

**Why colocation tends to win when adopting one for the first time**:

- Source/test proximity makes coverage visible in a plain directory listing —
  a source file with no neighboring test file stands out immediately.
- Moving or renaming a module means moving the pair together, reducing drift
  during refactors.
- It's a structural nudge, not a disciplinary one — a reviewer scanning the
  file tree sees the gap without needing to cross-reference a separate folder.

**If your codebase already has a majority pattern** (colocated or not), match
it for new tests rather than introducing a second convention piecemeal.
Legacy modules using the other pattern are a reasonable exception to grandfather
in — migrate them opportunistically during unrelated refactors, not as a
standalone chore. If a module's test coverage ratio is low relative to the
rest of the codebase, prefer adding a new colocated (or convention-matching)
test over further stretching an existing catch-all test file.

## Prompt Template: Correct vs Incorrect

### Incorrect (forbidden)

> Look at `distance.ts` and write the associated tests.

**Why it is forbidden**: the prompt forces the agent to read the
implementation and then encode its current behavior as "correct". No future
regression will be caught — the test locks in the code as it is today.

### Correct (contract-based)

> Write tests for `haversineDistance(lat1, lng1, lat2, lng2): number`.
>
> **Contract**: great-circle distance in kilometers between two WGS84 points.
>
> **Expected cases**:
>
> - Identical points → `0`
> - Antipodal points (0,0) and (0,180) → `≈ 20015.087` (± 0.01 km)
> - Two known city pairs with a documented reference distance → the reference
>   value (± an explicit tolerance)
>
> **Invariants**: symmetry (`f(a,b) === f(b,a)`), triangle inequality across 3
> points.
>
> **Out of scope**: `NaN`/`Infinity` validation (handled upstream by input
> validation before this function is ever called).

**Why it is correct**: the expected cases and invariants are derived from the
domain (geometry), not from the implementation. A bug introduced in the
formula (e.g. forgetting a `2 * atan2` factor) breaks the reference-distance
test — the mutation sentence from step 3 above holds.

## Refusal Patterns

The agent must **refuse** to write a test and propose a contract-based
reformulation when it detects:

- A prompt like "write the tests for this file/function" with no contract
  attached
- A request to reach a coverage threshold with no associated business
  invariant
- A tautological pattern, a mock-only test, happy-path-only coverage, or any
  other pattern your project's test-quality guidelines classify as
  written-to-pass

The refusal must be **explicit** — a short sentence naming which contract is
required — never silent. Example:

> I can't generate this test without a contract — is there an issue or spec
> describing `calculateScore()`? Failing that, can you give me: (a) the
> business rule being protected, (b) 2-3 expected edge cases?

## Post-Generation Audit (reminder)

After generation, before running the suite, re-read every test case and drop
those that fail the mutation-sentence check from step 3. Don't wait for the
human reviewer to catch it — a self-audit at generation time is cheaper than a
review round-trip.

## Mechanical Complement

Contract-first generation (this rule) covers the semantic judgment a linter
cannot evaluate. Where possible, pair it with a **mechanical, statically
detectable** complement: if your test framework has a companion ESLint/lint
plugin (most popular test runners do), enable its stricter rules — e.g. "no
test file may contain an assertion-free test", "don't use a loose equality
matcher when a strict one would catch an accidental extra field", "no
duplicate test titles in the same block". These catch a narrow but real slice
of written-to-pass patterns (an assertion-free `it()`, a bare
`toHaveBeenCalled()` with no argument/count check, a structural-only property
check) at `error` level, blocking them at commit/CI time without relying on
agent or reviewer vigilance.

If the generic plugin's rule set doesn't cover a pattern specific to your
codebase's failure modes (identified via a manual audit of past
written-to-pass tests), a small custom AST-based lint rule can encode that
specific pattern mechanically — same principle as any other
tooled-invariant-over-prose rule (cf. `code-quality.md` § "Enforce invariants
with tooling, not prose alone" if your rule set has an equivalent section).
Start at `warn` while cleaning up the existing backlog of violations, then
promote to `error` once the backlog is clear, so the rule blocks only new
regressions rather than failing the build on day one.

## References

- Myers, G. *The Art of Software Testing* (1979) — testing is the activity of
  looking for errors, not confirming the current behavior.
- DeMillo, Lipton, Sayward (1978), and later Jia & Harman's mutation-testing
  survey (2011) — the "would this test fail if the implementation mutated"
  question in step 3 above is a manual, cheap proxy for what a mutation
  testing tool (Stryker, PIT, mutmut…) checks mechanically; run one on your
  most business-critical modules if the language ecosystem has a mature tool.
