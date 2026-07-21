# Cross-Tier Second Opinion (Same-Vendor Model)

> A mechanism for getting a second opinion from a **different capability
> tier of the same model vendor** (e.g. a smaller/larger or
> differently-tuned model than the one driving the main session) before
> presenting architecture-level reasoning as final. See the companion
> `agents/second-opinion.md` in this repo for the concrete subagent
> implementation, and the root README's cross-perspective-review section
> for the cross-*vendor* variant of this idea.

## Trigger

Get a second opinion in each of these cases:

- **Architecture-scoped plan**: before finalizing a plan that touches
  ≥2 modules, introduces or changes a public contract, or arbitrates a
  technology/library choice — or before finalizing any written decision
  doc.
- **Stuck-on-problem escalation**: after 2-3 substantive failed
  debugging attempts, before telling the user "I cannot find it." This
  case is genuine problem-solving rather than judging the main model's
  own artifact, so a same-vendor tier still adds real value even though
  it can't fully substitute for a cross-vendor review (see below).
- **Ad-hoc algorithmic/logic decision** made inline during implementation
  (a scoring formula, a state-machine guard condition, a classification
  rule…) that never goes through a formal plan or decision doc — same
  risk profile as an architecture-scoped plan, just made outside those
  two triggers.

**Self-initiate, don't wait to be asked**: the agent is responsible for
recognizing the moment it is making this class of decision and firing the
second opinion itself, before presenting the decision as settled — not
only when explicitly asked "what does the other model think?" This
doesn't mean the second opinion is infallible and exempt from scrutiny:
verify its factual claims against the actual code before acting on them,
the same way you'd verify the main model's own claims.

## Mechanism

- Spawn a dedicated, **read-only** subagent (no edit/write tools) pinned
  to the alternate tier, with a prompt containing the plan/decision and
  the question to evaluate.
- Have a fallback tier configured in case the primary alternate tier is
  unavailable, so the mechanism degrades gracefully instead of silently
  not firing.
- If no alternate tier is reachable at all, say so explicitly rather than
  presenting the single-model reasoning as if it had been reviewed.
- **Notify usage, always**: state in the response, at the point of
  invocation, that a second opinion is being requested and from which
  tier. The call must be visible in the conversation, never silent — the
  user should be able to tell when the mechanism fired without having to
  infer it from an agent list.

## Synthesis

When the second opinion agrees, that's added confidence. When it
diverges, **surface both perspectives explicitly** — never silently pick
one over the other.

## Relationship to a cross-vendor review mechanism

A same-vendor second opinion does **not** satisfy a cross-vendor
self-preference-bias guard (Zheng et al., 2023, *Judging LLM-as-a-Judge*)
for the plan-review and ad-hoc-decision cases above — the producer and
the second opinion still share training lineage and the same structural
blind spots. It's a genuine complement, not a substitute, for a mandate
that requires an independently-trained model on security, public
contracts, irreversible operations, or transverse audits. The exception
is the debugging case: since that's problem-solving rather than judging
the model's own artifact, the self-preference-bias concern doesn't apply
there, and a same-vendor tier can have a real shot at spotting what the
primary tier missed.
