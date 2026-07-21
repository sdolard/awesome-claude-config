# Definition-of-Ready gate, duplicate detection, and branch/worktree decision — details

> Companion file of `SKILL.md`. Extracted from a production codebase — adapt
> tool names/IDs to your own stack.

---

## Definition-of-Ready lenses

Applied read-only against the ticket's title/description. For each
dimension, produce a verdict of **OK**, **gap**, or **not applicable**, and —
if a gap — a concrete, explicit question to put to the user. No numeric
scoring; these are judgment calls, not a formula.

| # | Dimension | Source | When it applies | What to check |
|---|---|---|---|---|
| 1 | Valuable | INVEST — Wake, *Extreme Programming Explored*, 2003 | Always | Does the description state an explicit user or product benefit? |
| 2 | Testable | INVEST + Adzic, *Specification by Example*, 2011 (Three Amigos) | Always | Is there an explicit or reasonably inferable acceptance criterion? |
| 3 | Estimable | INVEST + Cohn, *Agile Estimating and Planning*, 2005 (Definition of Ready) | Always | Enough detail for a rough estimate? If not, the right move is a timeboxed spike first, not a guess. |
| 4 | Root cause | 5 Whys — Ohno/Toyoda, Toyota Production System | Only for bug reports | Does the description name a root cause, or only a symptom? |
| 5 | Cynefin domain | Snowden & Boone, *A Leader's Framework for Decision Making*, HBR 2007 | Only for exploratory/epic-labeled work | Clear / Complicated / Complex / Chaotic? If Complex, recommend a timeboxed spike before committing to an implementation plan. |

**Gating vs. diagnostic**: only lenses 1-3 (Valuable, Testable, Estimable)
**gate** the start — a gap there blocks moving the ticket to in-progress
until the user decides how to proceed. Lenses 4-5 are **diagnostic only**:
they never block, they produce a recommendation surfaced in the briefing
(e.g. "write a reproduction test first", "timebox a spike before
implementing"). Don't conflate the two — treating a diagnostic gap as a hard
block trains users to route around the gate entirely.

**Deliberately excluded from gating**: the remaining INVEST letters
(Independent, Negotiable, Small) are worth noting in the briefing if
relevant, but don't carry a decision on their own — they're too easy to
satisfy trivially and too rarely the actual blocker in practice.

### On a gap in a gating lens

Never auto-decide. Ask explicitly, with a short, discrete set of options —
not a free-text prompt the user then has to compose an answer to:

- **Mark blocked** (recommended default) — apply the blocked status, and
  record the open questions as a comment on the ticket itself so they're not
  only in a local file.
- **Start anyway** — the user consciously accepts the gap; trace that
  decision in the briefing so it's visible to whoever picks this up later.
- **Pick a different ticket** — stop, zero mutation performed.

## Duplicate detection

1. Extract 3-4 salient, distinctive keywords from the ticket's title
   (lowercase, drop common stopwords in whichever language(s) your tracker
   uses). Favor distinctive nouns over an exhaustive token list — most
   full-text search backends AND all provided terms together, so a long
   token list can silently collapse the result set to zero and let a real
   duplicate through unnoticed.
2. Search your tracker for those keywords across all states (open and
   closed) — a duplicate is just as often something already closed as
   something still open.
3. For each candidate (excluding the ticket itself), assign one categorical
   verdict with a one-line justification naming the overlapping intent:
   - **unrelated** — don't list it.
   - **possible** — same general area, plausibly a different deliverable;
     list for awareness, no gate.
   - **probable duplicate** — same deliverable or same underlying defect;
     **gate** — ask the user before continuing.
4. When genuinely torn between *possible* and *probable duplicate*, default
   to *possible* unless both descriptions clearly describe the same concrete
   outcome — a duplicate gate that over-fires gets ignored.
5. This check never closes anything by itself. It surfaces the candidates
   and asks; the decision to actually close a duplicate stays with the user.

Method reference: Runeson, Alexandersson, Nyholm, *Detection of Duplicate
Defect Reports Using Natural Language Processing*, ICSE 2007.

## Branch/worktree decision table

Evaluated top to bottom — first matching row wins. `dirty tree on trunk`
(uncommitted local changes on the trunk branch) short-circuits every other
input, because switching in place there would carry those changes onto the
new branch.

| Dirty tree on trunk? | User override | Branch for this ticket already exists? | Peer detected on trunk? | Action |
|---|---|---|---|---|
| yes | — | — | — | isolated worktree (confirm first — this relocates where the user's uncommitted work lives) |
| no | worktree | no | — | create a new branch inside an isolated worktree |
| no | worktree | yes | — | open an isolated worktree onto the existing branch |
| no | branch | no/yes | no | switch in place (create or resume) |
| no | branch | no/yes | yes | **ask first** — an explicit request to switch in place conflicts with protecting a concurrent session; offer isolated worktree instead, or let the user consciously override |
| no | *(none)* | no | no | switch in place, create the branch |
| no | *(none)* | no | yes | isolated worktree, new branch |
| no | *(none)* | yes | no | switch in place, resume the branch |
| no | *(none)* | yes | yes | isolated worktree onto the existing branch |

A **peer already on this exact ticket's branch** is a different situation
entirely from "peer on trunk" above — it's not a switch-vs-worktree
question, it's a live concurrent-work conflict. Stop, surface who's on it,
and ask whether to coordinate, take over, or pick a different ticket. Don't
auto-create anything in that case.

**Why the autonomy is safe**: every action in this table is trivially
reversible (delete the branch, remove the worktree) except the two rows
explicitly marked "ask first" or "confirm first" — those are exactly the
rows where the action could disturb someone else's session or relocate
uncommitted work the user didn't expect to move. Everywhere else, deciding
and acting without a confirmation prompt removes friction without adding
risk.

**Slug/branch-name derivation** (generic pattern, adapt the exact taxonomy
to your commit-type convention): a type prefix derived from the ticket's
label (bug → `fix/`, chore/maintenance → `chore/`, docs → `docs/`, otherwise
→ `feat/`), followed by the first handful of significant words from the
title (lowercased, accents normalized, stopwords dropped, length-capped),
followed by the ticket number as a suffix. Keeping the number in the branch
name is what makes the "branch already exists for this ticket" detection in
the table above possible without a separate lookup table.

## Briefing structure

Write a short file (not pasted into the conversation) capturing what this
workflow learned, so the work can be resumed later without re-deriving it.
Lead with a **BLUF block** (verdict, current tracker status, and the
branch/worktree action taken, three lines max) before any supporting detail
— the reader should get the actionable answer without scrolling. Follow with
whatever sections are useful in your context, typically:

1. Ticket metadata (id, title, url, labels, assignees, parent/epic if any).
2. The extracted description, truncated if long.
3. The Definition-of-Ready table above, with any open questions.
4. Duplicate-candidate table, probable duplicates listed first.
5. Hierarchy/work-in-progress context (parent epic, sibling tickets, linked
   PRs, matching branches).
6. If the ticket modifies an existing flow: a diagram of the current state,
   to anchor the plan that follows. Skip explicitly (say so, don't just omit
   it) for greenfield work or a trivial edit.
7. Any recommendations the diagnostic lenses produced, plus a reminder that
   the implementation should close with a review pass — ideally not by the
   same model/session that wrote the code.
