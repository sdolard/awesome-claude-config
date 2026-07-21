# Prompt Engineering Best Practices

> Extracted from a production codebase — adapt tool/file names to your own stack.

When writing or modifying LLM prompts (system prompts, tool descriptions,
few-shot templates), apply these principles.

## Structure

1. **Role/Context**: define who the model should act as.
2. **Task**: a clear, specific instruction — imperative verbs ("Analyze…",
   "Generate…", "List…").
3. **Constraints**: explicit boundaries, format requirements, edge cases.
4. **Output format**: specify the expected structure.
5. **Examples**: add a concrete example when the task benefits from one.

## Techniques

- Be specific and unambiguous — eliminate vague language.
- Break complex tasks into numbered steps.
- Add constraints to prevent common failure modes (hallucination, verbosity,
  off-topic drift).
- Use XML tags (`<input>`, `<output>`, `<example>`, `<thinking>`) for internal
  structure — prefer them over markdown headers inside a prompt body, since
  models trained on this convention parse them more reliably as structural
  boundaries rather than as content.
- Specify what NOT to do when relevant.
- For complex reasoning, ask for step-by-step thinking, or use a dedicated
  `<thinking>` block.

## Anti-Patterns

- Vague instructions ("do your best", "be helpful").
- Missing output format specification.
- No constraints on length or scope.
- Redundant or contradictory instructions.
- Mixing multiple unrelated tasks in one prompt.

### Contrastive framing traps the model into an a-contrario reading

Pattern: "don't do X. However, as soon as `<single allowed case>`, do Y."
Explicitly enumerating the *only* allowed exception invites the model to infer
that every case not listed is forbidden — freezing behavior outside that one
case, even when the intent was narrower.

Illustrative case: a prompt instructing an agent not to re-call an
update-record tool for unchanged data, "however, for a genuinely *new* field
with no dedicated slot, call it with a generic catch-all field" — left the
*revision of an existing field* (e.g. a corrected value for a field that
already has a dedicated slot) uncovered. The model, reading the "however"
clause as the exhaustive list of exceptions, risks acknowledging the correction
in its response text without calling the tool to persist it.

**Fix pattern**: state each branch positively and exhaustively — "unchanged
value → no call; modified or corrected value → call with the new value; new
attribute with no dedicated field → the catch-all field" — rather than a
default-plus-single-exception framing. Smaller/cheaper models tend to
under-call tools whenever a prompt gives them any textual permission to
abstain, so a wording change here is worth an eval/regression run before
shipping, not just a read-through.

### Over-constraining: don't re-state an invariant the code already guarantees

Piling up "don't do X" clauses in a prompt for an invariant your deterministic
code already enforces is a net loss: it's redundant (a token cost that adds no
behavior), it couples two sources of truth that will eventually drift out of
sync, and it caps the model's adaptability — which is usually the entire
reason to use an LLM in that spot rather than a fixed script.

Triage every candidate clause with one question: **does the code already
guarantee this?** If yes, keep it out of the prompt — only what the code
*cannot* enforce (a verbal/behavioral choice, a tone, a judgment call) belongs
there.

Illustrative case: a cross-model review suggested adding a clause telling an
orchestrated agent "do not advance the conversation to the next step
yourself" — but the surrounding state machine already owned progression
entirely; the LLM had no code path capable of advancing it regardless of what
it said. The clause was dropped: it only rigidified the model's phrasing
without changing any actual behavior, since the invariant was structurally
unreachable to violate in the first place.

**Practical note**: a cross-model or external reviewer structurally
over-suggests this kind of guardrail — it can only see the prompt, not what
the surrounding code enforces, so it defaults to "add a constraint for
safety". Apply the triage question above to every such suggestion rather than
stacking them reflexively.
