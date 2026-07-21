---
name: github-issues
description:
  "Issue management with automatic project attachment and epic/sub-issue
  linking. Keywords: issue, epic, sub-issue, ticket, backlog, project board,
  gh issue create. Apply when creating tracked issues or organizing epics."
---

# Skill: GitHub Issues

> Extracted from a production codebase — adapt tool names/IDs to your own
> stack. Examples below use the GitHub CLI (`gh`) and GitHub Projects v2
> GraphQL mutations; swap them for your own tracker's equivalent (Linear,
> Jira, GitLab) and the *shape* of each rule still applies — a project board
> attachment step, a parent/child linking mechanism, a status field.

Issue management with automatic attachment to a project board and
epic/sub-issue linking, so tracked work never ends up orphaned or invisible
in the board's structure.

## When to create an issue (before starting work)

Create an issue **first**, before writing any code, when the work meets any
of these criteria:

- Multi-step implementation (more than roughly 30 minutes of work, or
  spanning multiple commits).
- Cross-cutting change (touches multiple packages, configs, or
  architectural layers).
- Non-trivial diagnostic work (a bench, a debugging session, an
  investigation likely to pivot).
- Anything that might later need rollback, re-evaluation, or re-explaining
  to someone who wasn't there.

**Why**: the issue is the single place where context, diagnosis, decisions,
and measurements accumulate over the life of the work. Without it, the
reasoning gets scattered across commit messages and conversation history
that nobody will reconstruct later — including the person (or agent) who did
the work, two weeks on.

**Workflow while the work is in progress**:

1. Create the issue first; post the initial diagnosis and plan as the body.
2. Post a progress comment at each significant pivot (new data, changed
   approach) — not a comment per commit, a comment per decision point.
3. Close with a summary comment: results, the commits/PRs involved, and any
   remaining follow-up work.

A real example of the failure mode this prevents: a multi-day performance
investigation that pivoted approach three times (a first fix that didn't
hold, a second hypothesis that turned out to be about I/O rather than
render cost, and a final structural fix). Without a tracked issue, that
sequence of reasoning would have been lost the moment the terminal session
ended. With one, anyone can reconstruct exactly why the first two attempts
were abandoned.

## Project configuration

Resolve these once per repo/board and keep them somewhere durable (this
skill file, a `CLAUDE.md`-equivalent config doc) rather than re-discovering
them every time:

```
PROJECT_ID:        <YOUR_PROJECT_ID>            # gh project list --owner <org> --format json
PROJECT_NUMBER:    <YOUR_PROJECT_NUMBER>
REPO:              <owner>/<repo>
STATUS_FIELD_ID:   <YOUR_STATUS_FIELD_ID>        # gh project field-list <PROJECT_NUMBER> --owner <org>
STATUS_OPTIONS:
  Todo         = <option-id>
  Blocked      = <option-id>
  In Progress  = <option-id>
  Done         = <option-id>
  Won't Fix    = <option-id>
```

To fill these in: `gh project list --owner <org>` gets you the project
number and node ID; `gh project field-list <number> --owner <org>` gets you
the status field's ID and its option IDs. These are org/board-specific — do
not copy the values from any example verbatim.

## Status discipline

When told to handle/start/resume a specific ticket, **before** anything
else:

1. Move its status to **In Progress** on the project board (mutation below).
2. Briefly confirm the move to the user.
3. Then start the work.

When the work is done and merged: move it to **Done**. If blocked: move it
to **Blocked**, with an explanatory comment on the issue recording why.

### Mutation: move a ticket to a given status

```bash
ISSUE_NUMBER=123
STATUS_OPTION_ID=<in-progress-option-id>  # see STATUS_OPTIONS above

# 1. Get the ProjectV2Item ID matching the issue
ITEM_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        projectItems(first: 10) {
          nodes { id project { id } }
        }
      }
    }
  }
' -f owner="<owner>" -f repo="<repo>" -F number="$ISSUE_NUMBER" \
  --jq '.data.repository.issue.projectItems.nodes[] | select(.project.id == "<YOUR_PROJECT_ID>") | .id')

# 2. Update the Status field
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { singleSelectOptionId: $optionId }
    }) { projectV2Item { id } }
  }
' -f projectId="<YOUR_PROJECT_ID>" \
  -f itemId="$ITEM_ID" \
  -f fieldId="<YOUR_STATUS_FIELD_ID>" \
  -f optionId="$STATUS_OPTION_ID"
```

If `ITEM_ID` comes back empty, the issue isn't attached to the board yet —
add it first (see below), then re-run the status mutation.

## Mandatory workflow

### 1. Create an issue and attach it to the board

```bash
ISSUE_URL=$(gh issue create --title "Title" --body "Description" --repo "<owner>/<repo>")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

ISSUE_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) { id }
    }
  }
' -f owner="<owner>" -f repo="<repo>" -F number="$ISSUE_NUMBER" --jq '.data.repository.issue.id')

gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
      item { id }
    }
  }
' -f projectId="<YOUR_PROJECT_ID>" -f contentId="$ISSUE_ID"
```

### 2. Create an epic with sub-issues

```bash
EPIC_URL=$(gh issue create --title "[Epic] Epic title" --body "Description" --label epic --repo "<owner>/<repo>")
EPIC_NUMBER=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')

EPIC_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) { id }
    }
  }
' -f owner="<owner>" -f repo="<repo>" -F number="$EPIC_NUMBER" --jq '.data.repository.issue.id')

gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
      item { id }
    }
  }
' -f projectId="<YOUR_PROJECT_ID>" -f contentId="$EPIC_ID"

for TITLE in "Sub-task 1" "Sub-task 2"; do
  SUB_URL=$(gh issue create --title "$TITLE" --body "Part of epic #$EPIC_NUMBER" --repo "<owner>/<repo>")
  SUB_NUMBER=$(echo "$SUB_URL" | grep -oE '[0-9]+$')

  SUB_ID=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) { id }
      }
    }
  ' -f owner="<owner>" -f repo="<repo>" -F number="$SUB_NUMBER" --jq '.data.repository.issue.id')

  gh api graphql -f query='
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
  ' -f projectId="<YOUR_PROJECT_ID>" -f contentId="$SUB_ID"

  # Link as a sub-issue of the epic — GraphQL, never a tasklist checkbox
  gh api graphql -f query='
    mutation($issueId: ID!, $subIssueId: ID!) {
      addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
        issue { id }
        subIssue { id number title }
      }
    }
  ' -f issueId="$EPIC_ID" -f subIssueId="$SUB_ID"
done
```

**Why `addSubIssue` and not a tasklist checkbox in the epic's markdown body**:
a native parent/child link is queryable (`subIssues`/`parent` fields),
survives independently of anyone remembering to edit the epic's body text,
and is what the "epic → milestone fallback" navigation rule below actually
relies on. A markdown checklist is just text — nothing enforces it stays in
sync with reality.

### 3. Link an already-existing issue as a sub-issue

```bash
PARENT_NUMBER=123
CHILD_NUMBER=456

PARENT_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) { issue(number: $number) { id } }
  }
' -f owner="<owner>" -f repo="<repo>" -F number="$PARENT_NUMBER" --jq '.data.repository.issue.id')

CHILD_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) { issue(number: $number) { id } }
  }
' -f owner="<owner>" -f repo="<repo>" -F number="$CHILD_NUMBER" --jq '.data.repository.issue.id')

gh api graphql -f query='
  mutation($issueId: ID!, $subIssueId: ID!) {
    addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
      issue { id }
      subIssue { id number title }
    }
  }
' -f issueId="$PARENT_ID" -f subIssueId="$CHILD_ID"
```

## No orphan ticket

A ticket without a parent epic is a ticket nobody will find later when
browsing by theme. Apply this systematically before creating an issue:

1. Look for an existing epic on the theme
   (`gh issue list --label epic --state open --repo "<owner>/<repo>"`).
2. Found one → create the sub-issue and link it via `addSubIssue`.
3. None found → create the parent epic first (label `epic`, a clear theme),
   then the sub-issue under it.
4. The only acceptable exception is an explicit standalone-ticket request
   from the user. Absent that, don't create an orphan — propose the
   appropriate parent epic instead.

**Why**: an epic is the backlog's thematic grouping mechanism. A ticket
without a parent is invisible in that structure — findable only by luck or
full-text search, not by browsing the theme it belongs to.

## Epic → milestone fallback (backlog navigation)

An epic showing **no open sub-issue** is not proof its theme is exhausted.
Sub-issue links and milestone membership can diverge in practice: a ticket
can belong to the epic's milestone without ever being linked as a sub-issue,
especially if someone edited the epic's markdown body by hand instead of
using `addSubIssue` — and that body text is never the source of truth, the
native sub-issue link is.

Before concluding an epic has nothing left, check whether it carries a
milestone. If it does, list the milestone's **open** issues and
cross-reference them against the epic's linked sub-issues. Any ticket that's
in the milestone but not linked as a sub-issue is work the sub-issue view
alone would hide — surface it explicitly rather than declaring the epic
exhausted. When the two views already match (no orphan), that agreement is
itself worth stating — it's the evidence the tracking stayed consistent, not
noise to omit.

## Epic structure: a phased implementation order

Every epic should include a section ordering its sub-issues into
dependency-aware phases, not just a flat list:

```markdown
## Suggested Implementation Order

| Phase            | Issue | Depends on | Rationale                     |
| ---------------- | ----- | ---------- | ------------------------------ |
| 1 - Foundation   | #123  | -          | Prerequisite to measure       |
| 2 - Optimization | #124  | #123       | Optimization based on metrics |
| 2 - Optimization | #125  | #123       | Can run in parallel with #124 |
| 3 - Extension    | #126  | -          | Independent extension         |
| 4 - Research     | #127  | -          | Long-term, open-ended         |
```

Standard phase vocabulary, adapt names to your domain:

| Phase | Description | Typical contents |
|---|---|---|
| Foundation | Prerequisites: instrumentation, metrics, infra | Logging, monitoring, missing tests |
| Optimization | Data-driven improvement of something already working | Performance, cost reduction |
| Extension | New capability building on the foundation | New feature surface |
| Research | Long-term, exploratory | PoC, feasibility study |

To build this table: identify which sub-issues genuinely block others
(shared data model, shared instrumentation) versus which are independent and
can run in parallel, then group by phase and give each row a one-line reason
— not just a phase label with no justification.

## Recommended labels

| Label | Usage |
|---|---|
| `epic` | Parent issue with sub-issues |
| `feature` | New capability |
| `bug` | Defect fix |
| `chore` | Maintenance, refactoring, no user-facing behavior change |
| `docs` | Documentation only |

## Rules

1. **Always** attach a newly created issue to the project board.
2. **Always** use the parent/child GraphQL link for sub-issues, never a
   tasklist checkbox in markdown.
3. Epics carry the `epic` label.
4. A sub-issue's body references its parent epic (`Part of #<epic_number>`).
5. **No orphan tickets** — every issue attaches to a parent epic via
   `addSubIssue` (see § No orphan ticket above).

## Sources this was extracted from

A production monorepo tracked on GitHub Issues + GitHub Projects v2, using
native sub-issue links (not tasklist markdown) and a five-state status field
(Todo/Blocked/In Progress/Done/Won't Fix). Concrete project/field/option IDs
and the repo owner/name were intentionally left out — resolve your own via
`gh project list` / `gh project field-list` as described above; the *shape*
of each mutation and rule is what's meant to transfer.
