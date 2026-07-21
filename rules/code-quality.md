# Code Quality — Portable TypeScript Conventions

> Generic subset of a production project's code-quality rule. Repo-specific
> commands, dead-code-gate tooling, and CI job names were intentionally left
> out — see the root README's integration note for how to re-tool the
> "why" below into your own lint config / CI gate.

## TypeScript strictness baseline

- Strict mode on.
- No `any` — use `unknown` for genuinely unknown types, enforced by a lint
  rule (`@typescript-eslint/no-explicit-any: "error"` or equivalent).
- No `@ts-ignore` — prefer `@ts-expect-error` with a comment explaining why,
  so the suppression breaks loudly (a type error) if the underlying issue
  gets fixed and the suppression becomes stale.
- Type casts need a comment explaining *why* the cast is safe — an
  unexplained `as` is a debugging trap for the next reader.
- Null safety: optional chaining (`?.`) and nullish coalescing (`??`) over
  manual `!= null` checks.

## `satisfies` over `as` to validate without widening

```typescript
// satisfies — keeps the literal types
const routes = {
  home: "/",
  admin: "/admin",
} satisfies Record<string, string>;
// routes.home: "/" (literal)

// as — widens to the target type, loses the literal
const routes = {
  home: "/",
  admin: "/admin",
} as Record<string, string>;
// routes.home: string
```

Useful anywhere you want compile-time validation against a shape (a config
object, a tool registry, a constant map) without losing the precise literal
type on the result.

## Exhaustive switch on discriminated unions

Add a `default` branch asserting `never` to guarantee every case is
handled — a missing case becomes a compile error instead of a silent
runtime gap the moment a new variant is added:

```typescript
switch (event.type) {
  case "text-delta": ...
  case "finish": ...
  default: {
    const _exhaustive: never = event; // TS error if a variant was added
    throw new Error(`Unhandled event type: ${_exhaustive}`);
  }
}
```

## Branded types for IDs

Template literal types prevent cross-entity ID confusion at compile time,
at zero runtime cost:

```typescript
type OrganizationId = `org_${string}`;
type UserId = `usr_${string}`;
// The two are structurally incompatible — TypeScript refuses cross-assignment
```

## JSON serialization silently drops `undefined`

`JSON.stringify` strips keys whose value is `undefined` — a common source
of "the field just isn't in the payload and nobody explicitly removed it"
bugs:

```typescript
// WRONG: undefined key disappears in JSON, no error, no warning
const profile = { budget: existingBudget }; // undefined -> silently lost

// CORRECT: conditional spread only includes the key when it has a value
const profile = { ...(existingBudget && { budget: existingBudget }) };
```

## Declarative annotations over ad-hoc filtering logic

For context-based filtering (which items are available/visible/enabled
given some runtime context), prefer a **declarative annotation co-located
with the definition** (e.g. an `availability` field on a registry entry)
over a separate file with imperative if/else filtering logic scattered
elsewhere. The annotation keeps the filtering rule next to the thing it
filters, instead of requiring a reader to jump between the definition and
a separate rules file to understand why an item is or isn't active.

## Module isolation gotcha (framework instrumentation vs request handlers)

Some frameworks (Next.js among them) load separate module instances for an
instrumentation/startup hook versus the actual request handlers — a
module-level singleton initialized in one will **not** be visible from the
other, even though it looks like the same process. If you need genuinely
shared state across those contexts, use a global registry keyed by a
well-known symbol (e.g. `globalThis` + `Symbol.for(...)`) rather than a
plain module-level `let`/`const`, which will silently create two disjoint
instances.

## Naming conventions (adapt casing to your language, keep the categories)

| Type | Convention |
|---|---|
| Components | `PascalCase` |
| Hooks | `useX` |
| Utils/functions | `camelCase` |
| Types | `PascalCase` |
| Constants | `SCREAMING_SNAKE_CASE` |

## Module barrels (`index.ts`) need a quantified threshold

See the root README's "barrel threshold" section (§10) — don't decide
per-folder by gut feel; pick a concrete auditable threshold (e.g. "≥3
external call sites") and grep-audit against it periodically.

## Fix all errors surfaced during a check run, not just the ones you caused

When running the project's lint/typecheck/test command, fix **all** errors
and warnings encountered — including pre-existing ones the current change
didn't introduce.

**Why**: the expectation is a clean codebase at every session, not just
patched wherever the immediate change happens to touch. If a pre-existing
warning is non-trivial to fix within the current scope, surface it
explicitly and ask before deferring it — don't silently leave it.

## Keep a single language boundary between code/logs and user-facing text

If the product is localized (UI in one or more human languages), draw one
firm line: all error messages, log lines, and assertion text emitted from
code stay in a single language (English is the pragmatic default for tooling
interoperability and non-native-speaker contributors) — the localized
language is reserved strictly for actual UI strings routed through your
i18n system. A localized string leaking into an API error payload or a log
line breaks observability tooling and confuses contributors who don't read
that language; a hardcoded English string leaking into rendered UI breaks
the product's localization for end users. When porting existing code that
violates this, fix it in the same change rather than carrying the drift
forward.

## Validate locally before every push, using the same environment as CI

If your project has a way to run the CI environment locally (a
container-based local runner, a reproducible sandboxed pipeline tool),
prefer it over pushing and waiting on the remote CI feedback loop for
routine iteration — it reproduces the CI environment exactly (image, env,
dependencies), eliminating the "works locally but fails in CI" class of
issues. Keep a fast subset (lint + typecheck + unit tests, no build) for
the tight edit loop, and a full subset (+ build, + slower integration
suites) for pre-push/pre-merge. If you skip the full local validation for
speed, say so explicitly ("local quick check only, full validation
pending") rather than reporting "tests green" as if the full gate had run.
