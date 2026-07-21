---
name: start-ticket
description:
  "Start a tracked issue with discipline: fetch it, run a Definition-of-Ready
  gate, detect likely duplicates, check its place in the epic/sub-issue
  hierarchy, decide branch vs. isolated worktree, mark it in-progress, write a
  short briefing, then hand off to planning. Keywords: start ticket, handle
  ticket, work on issue, Definition of Ready, INVEST, duplicate detection,
  epic, sub-issue, worktree, plan mode."
argument-hint: "<issue-number|issue-url> [--mode=branch|worktree]"
allowed-tools:
  Read, Grep, Glob, Bash(gh *), Bash(git status), Bash(git branch *), Bash(git
  log *), Bash(git switch *), Bash(git worktree *), Write, AskUserQuestion
---

# Skill: Start Ticket

> Extracted from a production codebase — adapt tool names/IDs to your own
> stack. The concrete `gh`/GraphQL calls below assume GitHub Issues + GitHub
> Projects v2; swap them for your own tracker's CLI/API (Linear, Jira, GitLab
> Issues…) and the *shape* of the workflow still applies. See the companion
> `veracity-checklist.md` for the detailed gate tables this file references.

Entry discipline for a tracked issue. Its whole point is avoiding false
starts: a vague ticket nobody could estimate, a duplicate already filed, a
parent epic silently already exhausted, an already-open PR nobody noticed,
uncommitted work left on the trunk branch — all of that gets caught **before**
any status mutation and before planning begins.

## When to invoke it

The user asks to start/handle/tackle a specific ticket by number or URL. This
skill replaces the manual chain of: view the issue, mutate its status,
explore its epic, search for duplicates, then open a planning session — by
running that chain in order, with gates at each step.

## Workflow shape

Six stages, in this order. Each stage's gate must clear before the next one
runs; nothing outside the final status mutation touches external state, so an
interruption at any point leaves zero residual side effect beyond a possible
local branch/worktree (itself trivially reversible).

```
fetch issue + hierarchy + linked PRs + local git state
        │
        ▼
Definition-of-Ready gate  ──gap──▶ ask: block, or proceed accepting the gap
        │ OK
        ▼
duplicate detection        ──probable duplicate──▶ ask before continuing
        │ clear
        ▼
hierarchy check  ──is an epic──▶ refuse, list open sub-issues, stop
        │  ──already delivered──▶ ask: close as done instead of restarting
        │ clear
        ▼
branch / worktree decision (autonomous, reversible)
        │
        ▼
status mutation → in-progress  +  short briefing file  +  hand off to planning
```

### Fetch everything you need in one pass

Batch the read-only calls: the issue itself (title, body, labels, assignees,
parent, sub-issues, current tracker status), any linked/matching pull
requests, and the local git state (current branch, branches whose name
references this ticket, commit history mentioning it). Do this once, up
front, in parallel where your tools support it — every gate below reads from
this single fetch, never re-fetching the same field twice.

A commit history search for the ticket's reference (not just an open-PR
search) matters more than it looks: a squash-merge workflow stamps the PR
number into the commit message, but the *ticket* number often lives only in
the PR body ("Closes #N") or a trailer, not the commit subject or the PR
title — a title-only or subject-only search misses tickets whose 6 phases of
work already landed across two or three merged PRs, and the ticket gets
re-started as if untouched. Bias this search toward recall (over-matching a
few false positives) rather than precision — the failure mode you're
guarding against (silently redoing shipped work) is far more costly than one
extra confirmation question.

### Definition-of-Ready gate

Before committing to start the ticket, check it against a small set of
readiness lenses — some **gate** (block the start on a gap), some are
**diagnostic only** (produce a recommendation, never a block). Full table,
citations, and the gating/diagnostic split: `veracity-checklist.md`.

If a gating lens has a gap, don't decide unilaterally what to do — ask the
user explicitly: mark the ticket blocked (with the open questions recorded on
the ticket itself), or proceed anyway with the gap consciously accepted and
traced in the briefing.

### Duplicate detection is a judgment call, not a fake metric

Compare the new ticket's title/description against candidates surfaced by a
keyword search of your tracker. This is a categorical **judgment**
(unrelated / possibly related / probable duplicate with a one-line
justification), never a simulated decimal similarity score — an LLM cannot
reliably compute a real Jaccard/cosine similarity, so a number here would be
fabricated precision, not a real measurement. If you genuinely need a
numeric score, compute it with an actual script, not by asking the model to
estimate one.

Bias toward **precision** over recall on this step specifically (the
opposite bias from the already-delivered check above): a duplicate-detection
gate that fires too often trains the user to dismiss it. When genuinely
unsure between "related but different deliverable" and "same deliverable",
default to the weaker verdict unless both descriptions clearly describe the
same concrete outcome. Never close a ticket as a duplicate unilaterally —
surface the candidate and ask.

Method reference: Runeson, Alexandersson, Nyholm, *Detection of Duplicate
Defect Reports Using Natural Language Processing*, ICSE 2007 — title +
description similarity outperforms metadata-only matching for duplicate
retrieval.

### Hierarchy check

- If the ticket itself has open sub-issues (i.e. it's a parent/epic), refuse
  to start it as if it were atomic work — list its open sub-issues and let
  the user pick one instead.
- If the ticket has a parent, surface that context in the briefing (sibling
  tickets, overall epic goal) — informational, not a gate.
- If the fetch above turned up commits or a merged PR that already reference
  this ticket, treat it as likely already delivered: don't restart it, ask
  whether it should be closed as done instead.
- If an open (possibly draft) PR is already linked, offer to resume that PR's
  branch rather than starting fresh.
- If a local branch already exists whose name references this ticket, treat
  it as forgotten in-progress work and reuse it rather than creating a
  second, diverging branch for the same ticket.

### Branch vs. isolated worktree — decide autonomously, act, don't ask by default

This decision is safe to make without confirmation **because it's trivially
reversible** (a local branch/worktree costs nothing to delete). The only
questions worth pausing on are the ones that could disturb someone else's
in-progress work:

- **Solo on the trunk branch, tree clean** → just switch/create the branch
  directly in place.
- **Someone else (another agent session, another contributor) is actively on
  the trunk branch** → create an isolated worktree instead of switching in
  place. Switching HEAD in a shared checkout out from under a concurrent
  session is the exact failure mode this avoids — it's a shared-nothing
  argument at the working-tree granularity (cf. Stonebraker, *The Case for
  Shared Nothing*, 1986, for the general principle behind isolating mutable
  state per worker).
- **Trunk branch, but the working tree is dirty** (uncommitted local changes)
  → don't switch (that would carry the uncommitted changes onto the new
  branch); use an isolated worktree instead, which starts clean and leaves
  the dirty checkout untouched. This one is worth a quick confirmation, since
  it changes where the user's uncommitted work physically lives.
- **A branch for this ticket already exists** → resume it (switch onto it, or
  open a worktree onto it) rather than creating a second one.
- **Someone else is already actively on this exact ticket's branch** → this
  is the one case that genuinely blocks: surface who, and ask whether to
  coordinate, take over, or pick a different ticket instead of silently
  creating a conflicting checkout.

Full decision table (including how an explicit branch/worktree override
provided by the user interacts with a detected peer on trunk):
`veracity-checklist.md` § Branch/worktree decision table.

### Status mutation, briefing, hand-off

Once every gate above has cleared:

1. Mutate the ticket's tracker status to **in-progress**. This is the single
   external mutation this workflow performs when everything is clear (a
   **blocked** mutation, with a comment recording the open questions, is the
   only other status this workflow ever writes, and only after the user
   explicitly chose it at the Definition-of-Ready gate).
2. Write a short briefing file capturing what was learned (metadata,
   readiness gaps, duplicate candidates, hierarchy context, and — if the
   ticket changes an existing flow/state machine/pipeline — a diagram of the
   *current* state to anchor the analysis that planning will build on).
   Structure: `veracity-checklist.md` § Briefing structure.
3. Hand off to planning, leading with the verdict (BLUF — Bottom Line Up
   Front, US Army FM 6-0 *Commander and Staff Organization and Operations*:
   state the decision before the supporting detail, so the reader doesn't
   have to scroll to find out whether they can proceed). If an isolated
   worktree was created, route the hand-off there explicitly — the planning
   step must happen where the code actually lives, not in the original
   checkout.

**Plan requirements before implementation starts** (skip only for a genuinely
trivial edit — typo, mechanical rename, a fix under ~5 lines on an obvious
path):

- The plan addresses every open question the readiness gate surfaced.
- The plan names the modules it expects to touch (a quick keyword grep across
  the codebase, not guesswork).
- The plan includes a diagram of the target state, in whatever notation fits
  the kind of change (sequence diagram for interactions across
  components/services, a state diagram for a state machine, a flowchart for a
  pipeline/branching logic, a class/component diagram for a new abstraction).
  Write diagrams to a file that renders them (most terminals, including
  Claude Code's, do not render diagram markup inline) — not pasted into the
  conversation.
- The plan schedules a closing review pass before commit — ideally by a
  reviewer that is not the same model/session that wrote the code (see the
  root README's cross-perspective-review guidance for why self-review is
  structurally weaker).
- For anything non-trivial, get a second opinion on the drafted plan before
  treating it as final (see `agents/second-opinion.md` and
  `rules/architecture-review.md` in this repo). Agreement adds confidence;
  disagreement gets surfaced to the user explicitly, never silently resolved
  one way.

## Status discipline (recap)

- **Before** starting real work on a ticket: move it to in-progress.
- **After** it merges: move it to done.
- **If** genuinely blocked: move it to blocked, with the reason recorded as a
  comment on the ticket, not just in a local file.

Never silently skip a status mutation because "it's obvious" — the tracker
status is the team's/agent-swarm's shared source of truth for what's actively
being worked, and a stale status is what causes duplicate effort.

## Non-goals

- This workflow does not close a suspected duplicate by itself — it only
  asks.
- It does not reassign a ticket away from its current assignee without
  confirmation.
- It does not create a new ticket — that's the companion `github-issues`
  skill's job.
- It does not write application code — its output is a status change, a
  branch/worktree, and a briefing file.
- It does not push a ticket to "done" — that happens through the normal
  merge workflow, not this entry-point skill.

## Sources this was extracted from

A production monorepo using GitHub Issues + GitHub Projects v2, with a
multi-instance-agent-aware git workflow (parallel coding-agent sessions on
the same host, hence the branch-vs-worktree peer-safety heuristic). Concrete
GraphQL queries, field IDs, and container/tooling specifics were intentionally
left out — replace them with your own tracker's equivalent; the *shape* of
each gate is what's meant to transfer.
