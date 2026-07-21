# sync-docs Plan Template

> Extracted from a production codebase — adapt the scratch-file path (here
> `tmp/`) to wherever your project keeps ephemeral working files.

Companion file of `SKILL.md` § Phase 3. Loaded by Claude only when it writes
the plan file — not during phases 0-2.

---

```markdown
# sync-docs plan — <ISO date>

## Analyzed range

- BASE_REF: `<short sha>` — <commit message>
- HEAD_REF: `<short sha>` — <commit message>
- Commits: <N>

## Summary

- Updates: <N>
- Deletes: <N>
- Creates: <N>
- Explicit skips: <N>

## UPDATE

### `<path>`

- **Reason**: <commit(s) + short description>
- **Targeted diff**:

  \`\`\`diff
  - <old info>
  + <new info>
  \`\`\`

## DELETE

### `<path>`

- **Reason**: <feature X removed in commit <sha>>
- **Upstream impact**: <docs referencing this path — to patch before delete>

## CREATE

### `<proposed path>`

- **Reason**: <module X introduced in commit <sha>, no existing doc>
- **Content plan**:
  - <bullet 1>
  - <bullet 2>
  - <bullet 3>

## Claude Code config

- Top-level config file (`CLAUDE.md` or equivalent): <sections to modify, or
  "no change">
- `.claude/rules/<domain>.md`: <pattern to add/remove, or "none">
- `.claude/skills/*/SKILL.md`: <existing skill to update, or "none">
- **Proposed new skill**: <name + justification>, or "none"
- **Proposed new rule**: <name + justification>, or "none"

## Skips (to remove ambiguity)

- `<path>` — <reason: no real drift even though the commit touches a
  neighboring domain>
```

---

## Compact inline summary to display (after writing the scratch plan)

```
Plan written: tmp/sync-docs-<timestamp>.md
  - Updates: N
  - Deletes: N
  - Creates: N
  - Skips: N

Validate fully, partially (give me the list), or cancel?
```

**Explicitly wait for the user's arbitration.** Never move to Phase 4 without
explicit feedback.
