# Review Checklist — Reference Material

> Extracted from a production codebase's review checklist — stack-specific
> examples were replaced with generic ones. This is **stance-agnostic
> reference material** a review perspective (cf. `SKILL.md`) draws from —
> not a per-domain script to run top to bottom.

Naming conventions and TypeScript-specific strictness rules are covered by
a companion code-quality rule if your project has one (e.g. `PascalCase`
for components/types, `camelCase` for functions, `SCREAMING_SNAKE_CASE`
for constants) — not repeated here.

## Reading contract (applies to every finding)

- **Evidence-first** (Turpin et al., 2023): quote the offending code
  verbatim with `file:line` *before* the verdict. A finding whose evidence
  cannot be located verbatim in the file gets dropped (anti-hallucination).
- **Classify by defect type**, not free text — Orthogonal Defect
  Classification (Chillarege et al., 1992) gives an orthogonal-by-
  construction taxonomy: `function | interface | checking | assignment |
  timing | algorithm | documentation`. Useful for spotting which class of
  defect no perspective actually looked for.
- **Abstain over guess**: insufficient context → say so explicitly, never
  fabricate a finding. A false positive costs adoption faster than a
  missed defect costs correctness (Bessey et al., 2010; Johnson et al.,
  2013 — both on why static-analysis tools get turned off by teams).
- **Don't re-flag what your lint/type gate already catches** (Sadowski et
  al., 2018): raw `any`/unknown-type escapes, unused imports, formatting,
  disabled type checks. Those are a deterministic tool's job — a reviewer
  agent re-reporting them wastes the one resource (judgment) it's uniquely
  suited to spend.
- **Project conventions override the model's training-time priors**: if a
  model's baked-in knowledge disagrees with a documented project
  convention, the convention wins — the model's knowledge may simply be
  stale.

## 1. Design & Architecture

### Integration

- [ ] Changes fit naturally with the existing architecture
- [ ] No unnecessary new abstraction (YAGNI)
- [ ] Module boundaries respected

### God class / god component detection

| Type      | Threshold | Action                          |
| --------- | --------- | -------------------------------- |
| Class     | >300 LOC  | Consider splitting                |
| Component | >200 LOC  | Extract sub-components            |
| Function  | >80 LOC   | Extract helper functions          |
| File      | >500 LOC  | Consider module splitting         |
| Nesting   | >4 levels | Refactor to reduce complexity     |

These are starting thresholds, not hard law — treat a repeated pattern of
"just over the line" as a stronger signal than any single crossing.

### Coupling

- [ ] No circular dependencies between modules
- [ ] Dependencies flow in one direction (e.g. UI → service → data)
- [ ] Shared mutable state minimized and explicit where it exists

## 2. Complexity

### YAGNI red flags

- Feature flags for a feature nobody requested yet
- Abstract factories wrapping a single implementation
- Configuration surface for values that never actually change
- "Future-proofing" comments with no concrete near-term driver

### Cyclomatic complexity

| Score | Risk   | Action                     |
| ----- | ------ | ---------------------------- |
| 1-10  | Low    | OK                            |
| 11-20 | Medium | Consider refactoring          |
| 21-50 | High   | Should refactor                |
| >50   | Severe | Refactor before this ships     |

### Cognitive load

- [ ] Functions do one thing
- [ ] Early returns for guard clauses instead of deep nesting
- [ ] No nested ternaries beyond one level
- [ ] `switch` statements have a default/exhaustive case

## 3. Functionality

### Edge cases

- [ ] Empty inputs handled (`null`, `undefined`, `[]`, `""`)
- [ ] Boundary values exercised (0, -1, max representable value)
- [ ] Unicode/special characters considered where relevant
- [ ] Large inputs degrade gracefully rather than blowing up

### Race conditions

- [ ] Async operations properly awaited, not fired-and-forgotten
- [ ] Concurrent state updates don't silently clobber each other
- [ ] Cleanup runs on unmount/cancellation
- [ ] Debounce/throttle applied where the domain calls for it

### Error handling

- [ ] Every error path has a message useful to whoever reads it next
- [ ] Errors logged with enough context to correlate (a trace/request id)
- [ ] Transient failures retry with backoff, not a tight loop
- [ ] A failing dependency degrades gracefully rather than cascading

## 4. Anti-patterns

| Pattern                  | Detection                                        | Severity | Fix                                        |
| ------------------------- | --------------------------------------------------- | -------- | -------------------------------------------- |
| Magic numbers              | Bare literals in logic (e.g. `if (x > 42)`)         | MEDIUM   | Extract to a named constant                  |
| Magic strings               | Inline strings used as keys/types                    | MEDIUM   | Extract to an enum/constant                   |
| Copy-paste code             | 3+ similar blocks (>10 lines each)                    | HIGH     | Extract to a shared function                  |
| Dead code                    | Unreachable code, unused exports                       | LOW      | Remove                                         |
| God class                    | See threshold table above                              | HIGH     | Split by responsibility                        |
| Primitive obsession          | Raw primitive types where a domain type would fit      | MEDIUM   | Introduce a value object/branded type          |
| Hardcoded config              | URLs, timeouts, limits baked into code                  | MEDIUM   | Move to environment/config                     |
| Silent failures               | Empty `catch` blocks                                     | CRITICAL | Log and handle appropriately                    |
| Callback hell                  | >3 levels of nested callbacks                             | HIGH     | Convert to `async`/`await`                      |
| Feature envy                    | A function mostly manipulates another module's data      | MEDIUM   | Move the function to where the data lives        |
| Mixed-language strings in code  | Localized/UI-language text leaking into throws/logs/errors when the project mandates one code language | HIGH     | Rewrite in the mandated code language; keep localized text strictly in UI-facing strings |
| Escape-hatch typing              | `any` / a blanket type-check suppression instead of a narrower, justified escape | MEDIUM   | Narrow the type, or suppress with an explanatory comment that breaks loudly if it goes stale |

## 5. Tests

### Test quality

- [ ] Tests assert behavior, not implementation detail
- [ ] One clear assertion focus per test
- [ ] No test interdependencies
- [ ] Deterministic — no flakiness from timing, ordering, or randomness

### Test naming

Pattern: `should <expected behavior> when <condition>`.

Good:

```typescript
it("should return an empty array when the input is empty");
it("should throw when the user is not found");
```

Bad:

```typescript
it("test1");
it("works correctly");
it("handles the thing");
```

### Test independence

- [ ] Each test runs in isolation
- [ ] No shared mutable state between tests
- [ ] Setup/teardown properly isolated
- [ ] No reliance on execution order

### Test anti-patterns

| Pattern                 | Problem                        | Fix                          |
| ------------------------ | --------------------------------- | -------------------------------- |
| Testing implementation     | Brittle to any refactor              | Test behavior/output only          |
| Mocking everything          | Tests pass while the real code fails | Exercise real integrations where feasible |
| No real assertions           | False confidence                       | Add assertions that can actually fail |
| Setup duplication              | Maintenance burden                       | Shared `beforeEach`/fixtures       |
| Magic test values                | Unclear intent                            | Use descriptive, named test data    |

### If your project integrates LLM calls

Non-deterministic output changes what "correct" even means for a test —
see the parent skill's report format and a companion test-strategy rule if
your project has one (LLM output belongs to an *eval* timing, not
red-green TDD).

| Criterion                                                    | Checked |
| --------------------------------------------------------------- | ------- |
| Test is explicitly skipped/gated when no LLM credentials are available | [ ]     |
| Timeout generous enough for a real LLM round trip (seconds, not ms)     | [ ]     |
| Assertion on a success/failure envelope before inspecting content        | [ ]     |
| Assertion targets behavior/structure, not an exact string                 | [ ]     |
| No brittle keyword-matching against free-form model output                 | [ ]     |

| Anti-pattern                                                     | Why it's a problem                                            | Fix                                                                 |
| --------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| Keyword matching on the LLM response (`"word" in response`)                | Fragile, flaky, breaks under paraphrase/i18n, misses meaning         | Semantic/LLM-graded evaluation instead                                    |
| Asserting the exact wording                                                  | The model may phrase the same idea differently on every run             | Assert on behavior/structure (a parsed field, a tool call, a state change) |
| A keyword check gating a smarter semantic check                                 | The blunt check fails/short-circuits before the better check even runs   | Run the semantic check as the actual gate; keep the keyword check as a log/warning at most, never a hard gate |
| A semantic grader with a criterion too generic to fail anything ("is relevant", "sounds professional") | Passes for essentially any output — tests nothing project-specific       | Write a grading criterion specific enough to your domain that a wrong answer would actually fail it |

## 6. Comments

### Worth having

- [ ] Public API functions carry a docstring/JSDoc
- [ ] Complex algorithms explain *why*, not just what
- [ ] Workarounds reference the issue/ticket that explains them
- [ ] Business rules cite the requirement they encode
- [ ] Type casts explain why the cast is safe

### Worth removing

- [ ] Comments that just restate the obvious code below them
- [ ] Changelog-style comments (that's what version control is for)
- [ ] Commented-out code (delete it — it's in history if needed)
- [ ] A `TODO` with no ticket/issue reference
- [ ] Redundant docstrings (e.g. `@param name - the name`)

### Quality bar

Good (explains *why*):

```typescript
// Deferred via setTimeout(0) so it runs after the framework's batch
// update completes — required for the scroll position calc. See #234.
```

Bad (explains *what*, adds nothing):

```typescript
// Set the value to 5
const value = 5;
```

## 7. PR / diff metrics

### Size thresholds

| Metric        | Optimal | Warning | Critical |
| -------------- | ------- | ------- | -------- |
| Lines changed | <200    | 200-400 | >400     |
| Files changed | <10     | 10-20   | >20      |
| Commits       | 1-3     | 4-10    | >10      |

### When to split a PR

- It spans multiple unrelated features
- Refactoring is mixed in with feature work
- The file count alone makes it hard to hold in one's head
- Different parts carry meaningfully different risk levels

### Quality signals

Positive: a clear description with context, a linked issue, test coverage
for the change, screenshots for a UI change, migration notes if state
shapes changed.

Negative: "WIP"/"misc" as the whole title, no description, unrelated
changes bundled together, a red CI check, new code with no tests.

## Cross-references

- Naming/TypeScript conventions: your project's own code-quality rule.
- Follow-up triage (structural vs. cosmetic — what deserves a tracked
  ticket vs. a one-line mention): a companion session-focus-style rule if
  your project has one.
- Functional/business-logic correctness (as opposed to code-quality
  concerns covered here): the companion `functional-review` skill.
