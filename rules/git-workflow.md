# Git Workflow — Portable Methodology

> Extracted from a production monorepo. Adapt the concrete tool names
> (commit linter, CI runner, package manager) to your own stack — the
> *shape* of each convention is what's meant to transfer. See the root
> `README.md` integration note for how to map a given item to a Rule, a
> Hook, or repo tooling.

## Conventional Commits, with a project-specific scope list

```
<type>(<scope>): <description>
```

Keep the type list short and standard (`feat`, `fix`, `docs`, `style`,
`refactor`, `test`, `chore`) and let the **scope** list grow with the
project's actual module boundaries. Whatever tool enforces this
(commitlint or equivalent) should be the single source of truth for the
scope list — keep any prose description of it in sync with the linter
config, never let the two drift.

### A parser gotcha worth guarding against: the ASCII straight apostrophe

If your release automation runs a Conventional Commits parser (e.g.
`googleapis/release-please-action`) to decide when to cut a release, test
whether an ASCII straight apostrophe (`'`, U+0027) in a commit **subject**
breaks that parser. One project observed several non-English commit
subjects containing a contraction apostrophe silently fail to trigger a
release PR for weeks before the gap was noticed — the parser errored
internally on the token, the commit still merged, and nothing surfaced the
failure. If your linter can enforce it, add a rule blocking the ASCII
apostrophe in subjects (or write in English, where contractions are less
common in commit subjects anyway) rather than relying on manual vigilance.
The typographic apostrophe (`'`, U+2019) is a safe substitute if you need
one.

## Atomic commits

One commit = one logical change. Separate fixes from features. Each
commit should pass CI independently — this is what makes `git bisect`
useful later.

## Merge strategy: squash by default

Squash-merge PRs into a linear main branch. Reasons that generalize
beyond any one project:

- `git log --oneline` becomes usable by humans and by AI coding agents —
  high information density, bounded context per line.
- The PR number in the squash commit message enables *lazy expansion* of
  context (`gh pr view <N>` or equivalent) only when actually needed —
  the discussion and review history isn't lost, just deferred.
- Each commit on main is the tip of a CI-green PR, which keeps
  `git bisect` reliable.
- Reverting a feature becomes a single `git revert <sha>`.

Reserve merge commits for the rare case of a multi-week epic with
individually-deployable atomic commits, where the archaeology of the
reasoning has standalone value — decide that explicitly per PR, don't let
it become the default by accident.

## Post-merge cleanup is not optional

After a squash merge, switch back to the base branch, fast-forward it,
and delete the merged branch (local and remote). One gotcha: squash merge
means the branch's own commit is never an ancestor of the base branch, so
a plain `git branch -d` always refuses with "not fully merged" even when
the PR genuinely merged. Confirm via your forge's API (e.g.
`gh pr view <N> --json state`) and force-delete (`-D`) once confirmed,
rather than treating the refusal as a signal something is wrong.

## Standing push/PR autonomy is an explicit, narrow grant — not a default

If your review workflow has an automated step (a local review skill, a
cross-model review, a required check) that gates a change before it
ships, consider granting your coding agent standing authorization to
push and open the PR **without re-asking** once that gate has genuinely
passed and every finding it raised was addressed. The grant should be:

- **Explicit and recorded** (e.g. in this file, tied to a specific ticket
  or decision), never inferred from a single instance of the user not
  objecting.
- **Narrow**: it covers commit → push → PR creation for the already-gated
  change. It does **not** extend to `--force` push, merging, or any other
  irreversible action — those stay gated by confirmation regardless.
- **Conditional on the gate having actually run**: if the review step was
  skipped or unavailable, the agent should still stop and ask, because the
  autonomy is a consequence of the review having happened, not a general
  license.

The point of the grant is to remove a redundant confirmation once the
real checkpoint (the review) has already done its job — not to relax the
review itself.

---

## Sources this was extracted from

A production TypeScript monorepo using Husky pre-commit/commit-msg/pre-push
hooks, commitlint, and `release-please` for two published npm packages.
Concrete tool names and the exact scope list were intentionally left out —
the conventions themselves are what's meant to transfer.
