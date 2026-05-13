---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: groom-open-questions

Adopted from `references/endo-but-for-bots/skills/groom-open-questions.md`.

Format and discipline of the open-questions / answers ledger the [groom](../../roles/groom/AGENT.md) leaves for the maintainer.

## When to use

When the groom (or any other role) encounters a roadmap question it cannot resolve unilaterally: re-prioritization, unclear status, contradicting design metadata, or a missing estimate. The goal is to leave a structured note the maintainer can answer at their next interactive turn without re-deriving the context.

## Where the note lives

Two valid locations, depending on the project's convention:

- **In the project's `process/` tree** (the reference's pattern): one file appended over time at `process/GROOM-OPEN-QUESTIONS.md` at the roadmap-branch root. Maintainer answers land in `process/GROOM-ANSWERS.md`. Ship updates as isolated process commits per `skills/process-documents/SKILL.md`.
- **In this garden's journal**: as a `message` entry tagged with the project slug, addressed to `liaison` (or `to: "*"` for broadcast). The groom does not maintain a process file on the project's branch; the journal entry is the note. Maintainer answers arrive as a follow-up `message` entry or in the dispatch prompt of the next groom engagement, and the groom's next dispatch surfaces them via `grep -rl '^project: <slug>' journal/entries/`.

The dispatch brief names which location applies. Default for the active garden is the journal.

## Format

```markdown
# Open questions for the maintainer

Latest grooming pass: <UTC timestamp>.

## <YYYY-MM-DD> grooming pass

<one-paragraph context: what triggered this pass, how many
designs were reviewed, what changed in the README>

### Re-prioritization candidates

- **<design-slug>**: <why it is a candidate, e.g. its prerequisite
  shipped two weeks early; recent commits suggest interest shifted;
  M3 has bandwidth>.
  Recommended action: <move to M2 / hold in M3 / drop entirely>.
  Awaiting decision.

### Status drift

- **<design-slug>**: README says `<status>`, design file says
  `<other-status>`, last commit touching the package was on
  `<date>`. Which is correct?

### Missing or stale estimates

- **<design-slug>**: no estimate in § Per-Design Estimates.
  Suggested: `<size>` (`<duration>`) based on similarity to
  `<reference design>`. Awaiting confirmation.

### Roadmap shape

- <free-form: should M5 be split? Should we collapse M3 and M4
  given recent re-ordering? Should the strategic-early list move?>
```

## Procedure

1. Open the open-questions note (create if missing). In the journal-side flow this is a fresh `message` entry; in the process-tree flow this is `process/GROOM-OPEN-QUESTIONS.md`.
2. Insert a new dated section at the top (process-tree flow) or write a fresh entry (journal flow).
3. For each unresolved question, write one bullet that names the design (or the cross-cutting concern), states what the ambiguity is, and includes a recommended action so the maintainer can sign off in one word ("yes" / "no" / "pick A").
4. If the same question appears in a later pass and the answer is still pending, do not duplicate it. Update the existing entry's date in place and append a "still pending as of <date>" note (process-tree flow), or write a new journal entry that `refs:` the prior one and says the same thing in one sentence.

## Pitfalls

- **Do not ask the maintainer to verify something the groom could verify itself.** The note is for genuinely human decisions (prioritization, vision), not for "I was too lazy to grep".
- **Keep each question under 80 words.** The maintainer reads this inline; long entries get skipped.
- **Resolve old entries when answered.** Process-tree flow: move the resolved bullet into a "Resolved" subsection at the bottom of the dated section, prefixed with the date and the maintainer's answer in one sentence. Do not delete; the audit trail is useful when the same question recurs. Journal-side flow: the resolution is a fresh `result` or `message` entry that `refs:` the original open-question entry and states the answer; the original stays in place because the journal is append-only.
- **If an answer requires a decision the maintainer has already made elsewhere** (chat, an issue, a previous grooming pass), cite it rather than re-asking.

## Notes from the field

- _2026-05-13_: adopted from the reference and extended to cover the active garden's journal-as-message-bus pattern. The reference assumed a `process/` tree; this version names both paths and lets the dispatch brief pick.
