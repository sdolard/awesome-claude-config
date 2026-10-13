# Rules index

Route a task to the rule worth reading. Engines that cannot load a rule
automatically by file path read this index from their entry file and open the
matching rule on demand.

"Neutral" means the file was regenerated for any engine. The others still use
Claude Code vocabulary; their principles apply everywhere, their mechanics
need translating with the notes under [`engines/`](../engines/).

| Rule                                               | Read it when                                                             | Form        |
| -------------------------------------------------- | ------------------------------------------------------------------------ | ----------- |
| [`session-focus.md`](session-focus.md)             | Every session: scope drift, follow-up triage, reading a ticket backlog   | Neutral     |
| [`git-workflow.md`](git-workflow.md)               | Committing, merging, opening a pull request                              | Claude Code |
| [`code-quality.md`](code-quality.md)               | Writing or reviewing TypeScript                                          | Claude Code |
| [`test-strategy.md`](test-strategy.md)             | Deciding when a test is written relative to the code                     | Claude Code |
| [`test-generation.md`](test-generation.md)         | Generating tests with a model                                            | Claude Code |
| [`development.md`](development.md)                 | Diagnosing a problem; writing or reviewing tests                         | Claude Code |
| [`mutation-testing.md`](mutation-testing.md)       | Judging whether a test suite protects behavior                           | Claude Code |
| [`measurement-cost.md`](measurement-cost.md)       | Dosing expensive validations (model-driven suites, CI re-runs)           | Claude Code |
| [`analysis-and-audit.md`](analysis-and-audit.md)   | Producing an audit, a transverse review, a post-mortem                   | Claude Code |
| [`architecture-review.md`](architecture-review.md) | Finalizing a plan or decision that deserves a second opinion             | Claude Code |
| [`promoted-diagrams.md`](promoted-diagrams.md)     | Touching code a permanent diagram documents                              | Claude Code |
| [`llm-configuration.md`](llm-configuration.md)     | Setting generation parameters on a model call                            | Claude Code |
| [`prompt-engineering.md`](prompt-engineering.md)   | Writing or editing a prompt                                              | Claude Code |
