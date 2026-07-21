---
name: meeting-summary
description:
  "Analyze a meeting/call transcript and produce a literature-grounded,
  actionable summary committed to the repo. Keywords: meeting summary,
  transcript, minutes, action items, decisions, debrief, call notes, standup,
  BLUF, actionable summary, follow-up. Apply when the user provides a
  transcript (pasted text or file) of a meeting / call / exchange and wants an
  actionable summary recorded in the repo."
argument-hint: "[transcript_path] [--type=business|technical|mixed] [--date=YYYY-MM-DD]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

> Extracted from a production codebase — adapt output paths to your own docs
> structure.

# Meeting Summary

Turn the raw transcript of a meeting / call / exchange into a **faithful,
actionable** record stored in your repo. The bar is _actionable_: a reader who
missed the meeting must know, in 15 seconds, **what was decided** and **what
they must do next**.

## Configuration (adapt before use)

This skill is output-path agnostic by design — pick one convention and keep it
consistent:

| Placeholder            | What it is                                                  | Suggested default        |
| ----------------------- | ------------------------------------------------------------ | ------------------------- |
| `<MEETINGS_DIR>`        | Where meeting summary files are committed                    | `docs/meetings/`          |
| `<MEETINGS_TEMPLATE>`   | The canonical skeleton file, if you maintain one              | `<MEETINGS_DIR>/TEMPLATE.md` (optional — see § Phase 3) |
| `<MEETINGS_INDEX>`      | An index file listing past summaries, if you maintain one     | `<MEETINGS_DIR>/README.md` (optional — see § Phase 4) |
| `<ISSUE_TRACKER_SKILL>` | Your project's own skill/workflow to open a tracker issue, if any | none by default |

If your project has no meeting-notes folder yet, create `<MEETINGS_DIR>` on
first use and ask the user to confirm the location before writing the first
file.

## Output language

Render the summary in the **transcript's language** (a sensible default is the
project's primary spoken/written language, whatever that is — French, English,
or otherwise). This `SKILL.md` file itself stays English-only if that is your
project's convention for Claude Code config; the produced artifact follows the
meeting, not the config-file convention.

## Theoretical foundations

The structure below is not arbitrary — it encodes what the literature says
makes a summary effective and a follow-up actionable.

| Principle                       | Source                                                          | Application                                                             |
| -------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **BLUF** (Bottom Line Up Front)  | US Army writing standard; journalism inverted pyramid              | Decisions + actions first, in a 15-second TL;DR                          |
| **Pyramid Principle**            | Minto, _The Pyramid Principle_ (1978)                              | Top-down: conclusion, then grouped support — never a chronological dump  |
| **SMART** action items           | Doran (1981)                                                       | Each action: Specific, owner (Assignable), deadline (Time-bound)         |
| **Next-action discipline**       | Allen, _Getting Things Done_ (2001)                                | Every open loop → one concrete next physical action + owner              |
| **3 W's** (Who / What / When)    | Project-management practice                                       | The action-table columns                                                 |
| **MoSCoW**                       | Clegg & Barker / DSDM                                              | Prioritize actions: Must / Should / Could / Won't                        |
| **Decision records**             | Nygard, ADR (2011); DACI (Atlassian)                                | Capture decision + driver/approver + status, not the debate              |
| **Minutes ≠ verbatim**           | Robert's Rules of Order                                            | Record what was decided/done; condense what was merely said              |
| **Faithfulness over fluency**    | Maynez et al. (2020), faithfulness in abstractive summarization    | Every decision/action anchored to the transcript; inferences segregated  |
| **Cognitive load / chunking**    | Miller (1956); Sweller                                             | Short scannable sections, ≤ 7 items per block                            |
| **Meeting science**              | Rogelberg, _The Surprising Science of Meetings_ (2019)              | The follow-up doc is where the meeting's value is realized               |

## Phase 0 — Acquire input & metadata

1. **Locate the transcript**: from the argument path, an attached/pasted
   block, or ask for it. For a file, `Read` it (chunk if > 1500 lines).
2. **Capture metadata** — ask only for what is missing, never fabricate:
   - subject/title, date (prefer a date found _in_ the transcript; else
     today's date), participants (as named in the transcript), type
     (`business | technical | mixed`), source (file name / "pasted").
3. **Detect the transcript language** → it sets the output language.

If no transcript is supplied, ask for it (path or paste). Do **not** proceed
from memory of an earlier conversation.

## Phase 1 — Pass 1: grounded extraction (faithfulness first)

Read the whole transcript once and extract, **each anchored to a transcript
location** (speaker + short paraphrased quote, or timestamp when present):

- **Decisions** — anything settled, agreed, or rejected.
- **Actions** — anything someone committed to do (commitment verbs: "I'll do
  X", "we'll send Y", "we need to…").
- **Open questions / parking lot** — unresolved or deferred.
- **Risks / vigilance points** — concerns, blockers, dependencies.
- **Key facts / numbers** — figures, dates, names, amounts cited.

Hard rules (this is where summaries fail):

- **Never invent an owner or a deadline.** If the transcript assigns none,
  write `owner: to be assigned` / `deadline: not set`. Inventing them is the
  #1 failure mode.
- **Segregate inference from observation.** A point you _deduced_ but nobody
  stated goes to a clearly-marked **"Inferences (to confirm)"** zone — never
  into Decisions/Actions.
- **Speaker uncertainty** (ASR errors, no labels, overlap): attribute
  tentatively and flag it; never hard-assign a doubtful owner.

## Phase 2 — Pass 2: structure & prioritize

- Order by **importance, not chronology** (Pyramid / BLUF).
- Build the **TL;DR**: ≤ 5 bullets — the decisions + top actions, readable in
  15 s.
- For each **action**: apply SMART — rewrite a vague intent ("think about
  pricing") into a concrete next step ("draft a 3-tier pricing grid"); set a
  MoSCoW priority; fill Who / What / When.
- For each **decision**: record the driver (who pushed it) and the approver
  if identifiable (DACI-lite); set status (final / tentative / rejected).
- **Deduplicate**: merge restatements of the same action or decision.

## Phase 3 — Write the file

- Path: `<MEETINGS_DIR>/YYYY-MM-DD-<slug>.md` (slug = kebab-case of the
  subject). If that name exists, suffix `-2`, `-3`, …
- If `<MEETINGS_TEMPLATE>` exists, use it as the exact skeleton (frontmatter
  counts, section order). If it doesn't exist yet, use this minimal skeleton
  and propose it becomes the project's template on first use:

  ```markdown
  ---
  date: YYYY-MM-DD
  type: business|technical|mixed
  participants: [Name1, Name2]
  source: file name | pasted
  decisions: N
  actions: N
  open_questions: N
  ---

  # <Meeting subject>

  ## TL;DR

  - <decision/action bullets, ≤5>

  ## Decisions

  ## Actions

  | Who | What | When | Priority |
  | --- | ---- | ---- | -------- |

  ## Open questions

  ## Risks / vigilance points

  ## Inferences (to confirm)

  ## Confidence & limits
  ```

- **Optional Mermaid**: only if there is a non-trivial decision/dependency
  chain (≥ 3 linked decisions). Otherwise skip — no filler diagram.

## Phase 4 — Update the index (if you maintain one)

If `<MEETINGS_INDEX>` exists, append a row (date, linked title, type, #
decisions, # actions, # open questions), kept sorted by date descending. If
you don't maintain an index, skip this phase — do not create one uninvited.

## Phase 5 — Faithfulness gate (self-check before declaring done)

Re-read the output against the transcript:

- [ ] Every Decision and Action has a transcript anchor. Un-anchored → move to
      Inferences or drop.
- [ ] No invented owner / date / figure. Cross-check each number against the
      source.
- [ ] TL;DR readable in ≤ 15 s and consistent with the body.
- [ ] No verbatim dump — discussion condensed to its "why".
- [ ] Low-confidence items explicitly flagged in "Confidence & limits".

Report the gate result to the user (e.g. "12 actions, 4 decisions, 2 low-
confidence items flagged"), and point to the file — do **not** paste the whole
summary back into the terminal.

## Action items → tracker (manual only)

Actions stay in the document by default. Promote one to a tracker issue
**only on the user's explicit request**, via `<ISSUE_TRACKER_SKILL>` if your
project has one (no automatic ticket proliferation — a summary is not a
mandate to open issues). When promoting, link the issue body back to the
meeting file.

## Notes

- A messy or partial transcript still yields a summary: capture what is
  grounded, and list the gaps honestly under "Confidence & limits" — do not
  paper over them.
- This skill records; it does not editorialize. Keep opinions out of
  Decisions and Actions; if a recommendation is yours, mark it as an
  inference.
