# LLM Call-Time Configuration — Honor Vendor Defaults

> Extracted from a production codebase — the model registry, provider-specific
> deprecation tracking, and concrete production model names were
> intentionally left out. What transfers is the policy and its justification.

## Policy

**Honor the model vendor's default reasoning/thinking effort and sampling
parameters.** Don't second-guess a model vendor on parameters they've already
tuned. Any deviation from a vendor default must be justified by a
**measured** regression (an eval suite, a benchmark, an A/B test) — never by
intuition alone.

**Why this matters**: the cost of silently overriding a reasoning budget or a
sampling parameter compounds across every call that uses it, and is invisible
in a code diff — a one-line change can shift the cost/quality tradeoff for
every subsequent request, with nothing in the review surfacing that tradeoff
explicitly.

## Forbidden patterns (illustrative — adapt the exact parameter names to your provider SDKs)

None of these should be **set** by application code when building a request
payload. They may legitimately appear in comments, in type definitions
imported from a provider SDK, or in a capability-declaration layer — but
never as a value forced onto a call from request-building code.

| Pattern (illustrative) | Typical provider family | Why forbidden |
|---|---|---|
| `reasoning_effort` / `reasoningEffort` | OpenAI-style, xAI-style APIs | Overrides the vendor-tuned reasoning depth. |
| `thinking` (as a request payload field), `budget_tokens` | Anthropic-style APIs | Opts into / sizes extended thinking without measurement. |
| `thinkingConfig` / `thinkingBudget` | Google Gemini-style APIs | Overrides a dynamic, vendor-managed thinking budget. |
| `top_p` / `top_k` (as call-time args) | Any | Vendor defaults are already tuned for the target use case (e.g. chat). |
| `frequency_penalty` / `presence_penalty` | Any | Same rationale. |
| `seed` (outside an eval/reproducibility harness) | Any | Not a production signal — reserved for benchmarking, never shipped to users. |

**Non-behavior knobs are always fine to set**: model identifier, messages,
system prompt, tool definitions, tool choice, max steps, an output token cap
(a cap on length is not a behavior change), and an abort signal.

## Documented exceptions require the same rigor as the rule itself

A hardcoded deviation from a vendor default is sometimes legitimate — e.g.
forcing a temperature of 0 for a deterministic classification step, or
disabling parallel tool calls because your own orchestration logic assumes
one call at a time. Each such exception should carry an explicit comment
stating *why*, and any new exception should be held to the same bar: a
measured justification, not a guess.

## When you believe a vendor default is wrong

The valid path is:

1. **Open an issue.** State the hypothesis precisely (e.g. "high reasoning
   effort improves detection accuracy on class X of inputs").
2. **Run a benchmark.** Compare default vs. override on a representative
   dataset. Record cost (tokens), latency, and quality/accuracy.
3. **If the benchmark confirms the hypothesis**, add the override at the
   model **capability-declaration layer** (wherever your code declares what a
   given model supports/needs), not as an ad hoc override buried in a
   request-building code path. Document the measurement alongside the
   change.

Skipping steps 1-2 and shipping the override anyway is exactly the
anti-pattern this rule exists to prevent.

## Why (literature)

- Peeperkorn et al., *Is Temperature the Creativity Parameter of Large
  Language Models?* (ICCC 2024) — the folk theory that "temperature tunes
  creativity/reasoning" is oversimplified; defaults are fine in most cases.
- Renze, *The Effect of Sampling Temperature on Problem Solving in Large
  Language Models* (EMNLP Findings 2024) — no statistically significant
  benefit from tuning temperature in `[0.0, 1.0]` on modern models for
  problem-solving tasks.
- OpenAI, *Learning to Reason with LLMs* (o1 blog, 2024); Anthropic,
  *Extended Thinking* documentation; DeepSeek-AI, *DeepSeek-R1* (2025) — each
  vendor picks a defensible default reasoning behavior for their own chat
  surface. Overriding it is a product decision requiring evidence, not a
  routine engineering default.
