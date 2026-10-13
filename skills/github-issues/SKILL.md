---
name: github-issues
description:
  "GitHub issue management with project-board attachment and epic/sub-issue
  linking. Keywords: issue, epic, sub-issue, ticket, backlog, project, gh issue
  create. Apply when creating GitHub issues or managing epics."
---

<!-- GENERATED FILE: do not edit by hand. Regenerated from a reference configuration; see PROVENANCE.json. -->

# Skill: GitHub Issues

GitHub issue management with automatic attachment to a GitHub Projects board
and epic/sub-issue linking, so tracked work never ends up orphaned or
invisible in the board's structure.

The examples use the GitHub CLI (`gh`) and the Projects v2 GraphQL API. On
another tracker the commands change and the _shape_ of each rule still
applies: a board attachment step, a native parent/child link, a status field.

## Running this skill

- Run the documented `gh` commands through the agent's terminal tool.
- Do not infer authorization for a GitHub mutation: the user's request must
  place the issue, project, comment, or status change in scope.
- The skill has no engine-specific dependency. How each engine discovers and
  invokes it is described in the `engines/` notes of this repository.

## When to create an issue (BEFORE starting work)

Create an issue FIRST if the work meets any of these criteria:

- Multi-step implementation (more than ~30 min of work or multiple commits)
- Cross-cutting changes (touches multiple packages, configs, or layers)
- Non-trivial diagnostic work (bench, debug, investigation with pivots)
- Anything that might need rollback, re-evaluation, or re-explanation later

**Why**: an issue is the single place where context, diagnosis, decisions, and
measurements are consolidated. Without it, the "why" gets lost in commit
messages or conversation history.

**Workflow during the work**:

1. Create issue first, post diagnosis and plan as the initial body
2. Post progress comments at each significant pivot (new data, approach change)
3. Close with a summary comment: results, commits, any remaining work

**The failure mode this prevents**: a performance investigation that pivots
three times (a first diagnosis that does not hold, a second pointing at a
different layer, a final structural fix). Without tickets, that reasoning is
lost when the session ends. With them, anyone — including yourself in two
weeks — can reconstruct why the first two attempts were abandoned.

## Project Configuration

Resolve these once per repository and keep them in the project's own copy of
this skill. They are per-project values: never reuse another project's.

```bash
OWNER="<owner>"                     # user or organization login
REPO="<repo>"
PROJECT_NUMBER="<project number>"   # gh project list --owner "$OWNER"
PROJECT_ID="<project node id>"      # gh project list --owner "$OWNER" --format json
STATUS_FIELD_ID="<field node id>"   # gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json
# The same field-list output gives one option id per status column:
STATUS_TODO="<option id>"
STATUS_BLOCKED="<option id>"
STATUS_IN_PROGRESS="<option id>"
STATUS_DONE="<option id>"
```

## Status discipline (MANDATORY)

When the user asks to **handle / start / resume** a ticket (by number or URL),
BEFORE anything else:

1. Move the ticket status to **In Progress** on the project (mutation below).
2. Briefly confirm to the user ("Ticket moved to In Progress").
3. Then start the work.

When the work is done and merged: move to **Done**. If blocked: move to
**Blocked** with an explanatory comment on the issue.

### Mutation: move a ticket to a given status

```bash
ISSUE_NUMBER="<issue number>"
STATUS_OPTION_ID="$STATUS_IN_PROGRESS"

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
' -f owner="$OWNER" -f repo="$REPO" -F number="$ISSUE_NUMBER" \
  --jq ".data.repository.issue.projectItems.nodes[] | select(.project.id == \"$PROJECT_ID\") | .id")

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
' -f projectId="$PROJECT_ID" \
  -f itemId="$ITEM_ID" \
  -f fieldId="$STATUS_FIELD_ID" \
  -f optionId="$STATUS_OPTION_ID"
```

If `ITEM_ID` is empty: the issue is not in the project yet. Add it first with
`addProjectV2ItemById` (see "Create an issue" below), then re-run the status
mutation.

## Mandatory Workflow

### 1. Create an issue and attach it to the project

```bash
# Create the issue
ISSUE_URL=$(gh issue create --title "Title" --body "Description" --repo "$OWNER/$REPO")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

# Get the issue's GraphQL ID
ISSUE_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) { id }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$ISSUE_NUMBER" --jq '.data.repository.issue.id')

# Add to the project
gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
      item { id }
    }
  }
' -f projectId="$PROJECT_ID" -f contentId="$ISSUE_ID"
```

### 2. Create an epic with sub-issues

```bash
issue_id() {
  gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) { id }
      }
    }
  ' -f owner="$OWNER" -f repo="$REPO" -F number="$1" --jq '.data.repository.issue.id'
}

add_to_project() {
  gh api graphql -f query='
    mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
  ' -f projectId="$PROJECT_ID" -f contentId="$1"
}

# 1. Create the epic (parent issue) and add it to the project
EPIC_URL=$(gh issue create --title "[Epic] Epic title" --body "Description" --label epic --repo "$OWNER/$REPO")
EPIC_NUMBER=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
EPIC_ID=$(issue_id "$EPIC_NUMBER")
add_to_project "$EPIC_ID"

# 2. Create sub-issues, add them to the project, link them to the epic
for TITLE in "Sub-task 1" "Sub-task 2"; do
  SUB_URL=$(gh issue create --title "$TITLE" --body "Part of epic #$EPIC_NUMBER" --repo "$OWNER/$REPO")
  SUB_ID=$(issue_id "$(echo "$SUB_URL" | grep -oE '[0-9]+$')")
  add_to_project "$SUB_ID"

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

### 3. Link an existing issue as sub-issue

```bash
# issue_id is the helper defined in the previous section
PARENT_ID=$(issue_id "<parent number>")
CHILD_ID=$(issue_id "<child number>")

gh api graphql -f query='
  mutation($issueId: ID!, $subIssueId: ID!) {
    addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
      issue { id }
      subIssue { id number title }
    }
  }
' -f issueId="$PARENT_ID" -f subIssueId="$CHILD_ID"
```

## Useful Queries

Both queries read a single page (`first:`). On a parent with more children, or
a project with more items, than the page size, request `pageInfo { hasNextPage
endCursor }` and follow the cursor — a truncated page reads as "nothing left".

### List sub-issues of an issue

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        subIssues(first: 50) {
          nodes { number title state }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="<issue number>"
```

### Check if an issue is in the project

For a project owned by an organization, replace `user(login:` with
`organization(login:`.

```bash
gh api graphql -f query='
  query($projectNumber: Int!, $owner: String!) {
    user(login: $owner) {
      projectV2(number: $projectNumber) {
        items(first: 100) {
          nodes {
            content {
              ... on Issue { number title }
            }
          }
        }
      }
    }
  }
' -F projectNumber="$PROJECT_NUMBER" -f owner="$OWNER"
```

## Recommended Labels

| Label     | Usage                        |
| --------- | ---------------------------- |
| `epic`    | Parent issue with sub-issues |
| `feature` | New feature                  |
| `bug`     | Bug fix                      |
| `chore`   | Maintenance, refactoring     |
| `docs`    | Documentation                |

## Rules

1. **ALWAYS** add the issue to the project after creation
2. **ALWAYS** use the GraphQL API to link sub-issues (not tasklist markdown)
3. Epics must have the `epic` label
4. Reference the parent epic in the sub-issue's body
5. **NEVER an orphan ticket**: every issue MUST be attached to a parent epic
   via `addSubIssue`. An epic groups the tickets of a single theme — it is the
   project's thematic classification mechanism.

## No orphan ticket (MANDATORY)

A ticket without a parent is forbidden. Workflow to apply systematically
before creating an issue:

1. **Look for an existing epic** on the theme
   (`gh issue list --label epic --state open --repo "$OWNER/$REPO"`).
2. If an epic matches → create the sub-issue and link it via `addSubIssue`.
3. If no epic matches → **create the parent epic first** (label `epic`, clear
   theme), then the sub-issue under it.
4. Only acceptable exception: explicit user request ("create a standalone
   ticket on X"). Without an explicit instruction, refuse to create an orphan
   ticket and propose the appropriate parent epic.

**Why**: epics are the thematic grouping mechanism of the backlog — without a
parent, a ticket is invisible in the project structure and gets lost.

## Epic Structure

Every epic MUST include a "Suggested implementation order" section:

1. **Identify dependencies** between sub-issues
2. **Group by phases** (Foundation → Optimization → Extension → Research)
3. **Justify the order** with a brief rationale

### Template

```markdown
## Suggested Implementation Order

| Phase            | Issue | Depends on | Rationale                     |
| ---------------- | ----- | ---------- | ----------------------------- |
| 1 - Foundation   | A     | -          | Prerequisite to measure       |
| 2 - Optimization | B     | A          | Optimization based on metrics |
| 2 - Optimization | C     | A          | Can be parallelized with B    |
| 3 - Extension    | D     | -          | Independent extension         |
| 4 - Research     | E     | -          | Long-term research            |
```

### Standard Phases

| Phase        | Description                   | Examples                     |
| ------------ | ----------------------------- | ---------------------------- |
| Foundation   | Prerequisites, metrics, infra | Logging, monitoring, tests   |
| Optimization | Data-driven improvements      | Performance, token reduction |
| Extension    | New features                  | New product areas            |
| Research     | Long-term exploration         | PoC, feasibility studies     |

### Phase labels — make the order queryable, not just readable (MANDATORY)

The "Suggested Implementation Order" table lives in the epic's markdown body —
readable, but not queryable, and it silently drifts as sub-issues close or new
ones are added (nothing forces the table to stay in sync). Close this gap with
one label per phase, applied to every sub-issue in that phase:
`phase-<N>-<slug>`, where `<N>` matches the table's Phase column and `<slug>`
is a short, epic-specific theme (not a generic word — see the collision note
below). Example for an epic migrating a storage layer:

```
phase-1-storage-foundation   "1 - Foundation: schema versioning"
phase-2-storage-dual-write   "2 - Dual write: writers A, B"
phase-3-storage-cutover      "3 - Cutover: readers, then removal of the old path"
phase-4-storage-research     "4 - Research: gated on a third use case"
```

**Mechanics**:

- **Create the label with `gh label create`**, with a description that is the
  same human-readable phase text as the table row, **including the member
  issue numbers**. The description is what turns the label into a durable
  index: editing it when a sub-issue is added or closed keeps the phase
  membership visible from `gh label list --search phase-` without opening the
  epic at all.
- **Apply the label to every sub-issue of that phase** at creation time
  (`gh issue edit <N> --add-label "phase-2-storage-dual-write"`).
- **Query the order directly**:
  `gh issue list --label phase-2-storage-dual-write --state open` surfaces
  exactly what is left in a phase. A milestone gives the full set; the phase
  label gives the **ordered slice** of that set.
- **Naming collision guard**: a bare `phase-N` label (no slug) is NOT
  epic-scoped. As soon as a repository has run two epics, their phase
  numbering collides on the same label. Always suffix with the epic-specific
  slug.
- **Update the description, not just the epic body**, when phase membership
  changes. The label description is the source of truth a `gh label list`
  query reads; the epic body table is the human-readable narrative. Keep both,
  but the label is what makes "what's next" answerable without reading prose.
