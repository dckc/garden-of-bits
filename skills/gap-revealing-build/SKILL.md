---
created: 2026-05-15
updated: 2026-05-15
author: gardener
---

# Skill: gap-revealing-build

A builder dispatch whose primary deliverable is a structured inventory of gaps in a tentative design, not a feature implementation. The verb is the maintainer's: *"probe #N"*. The builder attempts to implement the design, stops at every ambiguity, documents what is missing, and opens a DRAFT PR whose body is the gap report. The PR stays draft pending design revision; the standard jury / cleaner / un-draft loop does **not** run.

The dispatched role is still the [builder](../../roles/builder/AGENT.md); this skill is consulted **only** when the orchestrator's dispatch invokes the *probe* verb. On a normal `build #N` dispatch the builder follows [pr-creation-flow](../pr-creation-flow/SKILL.md) instead.

The verb's distinct semantics vs *build #N*: `build` produces a mergeable feature PR (cleaner / judge / fixer / un-draft chain follows); `probe` produces a DRAFT PR that carries a gap report (no chain follows; the maintainer reads the report and revises the design).

## When to use

- A maintainer prompt says *"probe #N"*, *"probe the design at #N"*, or *"have a builder attempt #N to reveal gaps"*. The verb names this procedure.
- A design PR (or design document) has tentative status. The maintainer wants to know whether the design holds up under contact with code, without committing to merge an implementation.
- A design names a mechanism that the maintainer suspects is under-specified, and an enumerated gap report is more valuable than a polished implementation.

Pre-conditions:

- The design is **reachable in the worktree**. A design PR's branch must be checked out (the implementation is stacked on that branch); a design that lives only on the project's roadmap branch must be referenced from its file path on that branch.
- The orchestrator has named the base branch in the dispatch prompt. Default base for a probe is the design PR's head (stacked PR); the dispatch prompt may override.
- The orchestrator has named the verb explicitly. The builder does not infer probe semantics from a design-shaped target; the dispatch must say *probe* (or equivalent) for this skill to apply.

## Inputs

- The design's file path on the worktree (e.g. `designs/<slug>.md`).
- The base branch the implementation PR branches off (typically the design PR's head; sometimes the project's implementation base on a stacked-PR setup).
- The pre-flight gap list the orchestrator may have surfaced in the dispatch prompt (treat as gap #1, #2, ... in the report; the orchestrator's pre-flight observations are part of the deliverable, not separate from it).

## Procedure

### 1. Read the design fully

Read the full design file (and any documents it references that the dispatch makes reachable). Note every place the design says **TBD**, **future**, **open question**, **hand-waves**, **for further consideration**, or otherwise defers a mechanism. Each such place is a candidate gap.

Read the design's dependency graph and acceptance criteria sections, if any. A criterion the design states without naming the mechanism that satisfies it is a gap.

### 2. Stop at every ambiguity (load-bearing rule)

This is the discipline that distinguishes a probe from a normal build. On a `build #N` the builder makes pragmatic choices and proceeds; on a `probe #N` the builder **stops at every ambiguity** and documents the gap instead of guessing. The deliverable is the gap inventory; choosing one interpretation and proceeding past it destroys the very signal the maintainer asked for.

An ambiguity is anything where the implementation cannot be written without making a load-bearing choice the design does not name:

- The design says "the proxy decides X" but does not say how.
- The design enumerates values for a field but does not name the validation site.
- The design names a policy but does not say what failure mode applies when the policy rejects.
- The design names a coexistence behavior with a sibling mechanism but does not name the dispatch order.
- Two design sentences imply contradictory shapes for the same mechanism.

When you encounter an ambiguity, do **not** pick one interpretation and proceed. Write the gap entry (next section) and either:

- Skip the affected code path (leave a `// gap: see PR body §X.Y` comment and continue with what is clear), or
- Stop the implementation at that line if the ambiguity is so structural that nothing downstream can be written without resolving it.

The dispatch's job is to surface the ambiguity, not to resolve it. Resolution belongs to the design author.

### 3. Write each gap as a structured entry

Each gap takes a fixed four-field shape. Number them sequentially in the order you encounter them while implementing:

```
### Gap N: <one-line summary>

**Where in the design.** <file:line range, or section heading, or both>.

**Verbatim quote.** > <the design's own words, copied exactly>.

**What's needed to implement.** <one or two sentences naming the load-bearing fact the design does not provide>.

**Candidate resolutions.**
- **A.** <one-sentence proposal>. Trade-off: <one sentence>.
- **B.** <one-sentence proposal>. Trade-off: <one sentence>.
- **C.** <one-sentence proposal>. Trade-off: <one sentence>.

**Maintainer's call:** design revision | implementation-time choice | needs broader review.
```

The four fields are load-bearing. The verbatim quote anchors the gap to design prose the author can search for; *what's needed* lets the author re-read the design with a specific question; *candidate resolutions* gives the author drafted alternatives rather than asking them to invent from scratch; *maintainer's call* tells the author whether the gap blocks the design or the implementation.

Two or three candidate resolutions per gap is the target. One is acceptable when the design's structure rules out alternatives; four or more is a sign the gap is actually two gaps and should be split.

### 4. Implement the skeleton where the design is clear

Where the design is unambiguous, write the skeleton: the exo interfaces, the type-checked function signatures, the wired imports, the package layout, the CLI verb shape. The point is to *demonstrate* that the parts of the design that are clear actually compose; this is the second-most-valuable signal after the gap report itself, because it tells the maintainer "the X part of the design holds up; only the gaps need revision."

Lockfile churn, conventional-commit messages, and the `pre-pr-checklist` apply normally. The skeleton is real code; treat it that way.

A gap that the dispatch instructed you to *attempt past* (rare, and only when the orchestrator's dispatch prompt explicitly named the gap as out-of-scope for this probe) is implemented with a stub plus a `// gap: ...` comment. The default is to stop at every ambiguity per § 2.

### 5. Open the DRAFT PR with the four-section body

Open the PR with `gh pr create --draft` against the named base. The title is the project's conventional-commit shape with the probe nature annotated:

```
<type>(<scope>): <one-line summary> (gap-revealing prototype of #<design-PR>)
```

The body **must** carry four sections in this order. Each section is required even when empty (write "None." rather than omitting):

```markdown
## Gaps surfaced

<numbered list of structured gap entries per § 3 above>

## Skeleton implemented

<bullet list naming what compiled, passed tests, typechecked: package by package, exo by exo, function by function. Cite specific commits where useful.>

## Skeleton not implemented

<bullet list naming what was abandoned at first ambiguity. Cross-reference the gap that blocked each item.>

## Recommendations to design author

<one or two paragraphs naming which gaps the design author should resolve before implementation can proceed, and which gaps the implementation can resolve at implementation time once the maintainer authorizes the choice. Treat the four-field "Maintainer's call" labels as the source of truth and group accordingly.>
```

Cross-link the design PR (or design document) from the PR body's first line so the maintainer can navigate between the two.

### 6. The PR stays DRAFT

This is the second load-bearing rule. The probe PR is **not** un-drafted. The judge, cleaner, fixer-loop, and un-draft chain in [pr-creation-flow](../pr-creation-flow/SKILL.md) does **not** apply to a probe. The PR exists as a discussion artifact, not a feature; the maintainer reads the gap report, revises the design, and either authorizes a follow-up `build #N` dispatch (which goes through the normal chain) or closes the probe PR as superseded.

The orchestrator's next action on a probe `result` is to post a bulletin row pointing the maintainer at the *Gaps surfaced* section, not to dispatch a cleaner or a judge.

### 7. Report back

Return to the orchestrator (≤ 600 words): the PR URL + head SHA, the count of gaps surfaced (one-line each), the count of skeleton-implemented items, the count of skeleton-abandoned items, and a one-line `Self-improvement: ...` per [self-improvement](../self-improvement/SKILL.md). The orchestrator writes the result entry and posts the bulletin row.

## Output shape

- A draft PR on the named base, titled with the `gap-revealing prototype of #<design-PR>` annotation.
- A PR body with the four required sections in order: *Gaps surfaced*, *Skeleton implemented*, *Skeleton not implemented*, *Recommendations to design author*.
- One commit per affected package per [retcon](../retcon/SKILL.md)'s grouping discipline (the probe's commits are not retconed at write time; the implementation is small enough that the grouping discipline applies naturally).
- A separate `chore: Update yarn.lock` commit per [yarn-lock-separate-commit](../yarn-lock-separate-commit/SKILL.md) when dependencies changed.
- A journal `result` entry written by the orchestrator naming the PR number and the count of gaps surfaced.

The PR's net diff is *not* the deliverable; the gap report is. A probe whose body has zero gaps in its *Gaps surfaced* section is a finding in its own right (the design held up under contact with code) and the orchestrator notes that explicitly on the bulletin.

## Notes

- A probe is a one-shot dispatch. A second probe on the same design (after revision) is a fresh dispatch with a fresh PR, not a fixer round on the prior probe's PR.
- The probe does **not** run the regression-evidence skill against the skeleton. The skeleton is not a feature; tests against it pin a contract the design has not finalized. If the skeleton has tests at all, they are smoke-level (does it import, does it construct) and the gap report explicitly names the testing strategy as a future implementation concern.
- The probe is the right shape when the maintainer is choosing between two design directions and wants the gap profile of each before committing. Two probes (one per direction) is a legitimate use, with the maintainer reading both gap reports side by side.
- A normal `build #N` dispatch should *not* opportunistically slip into probe semantics when the design feels under-specified. Builders on a build dispatch surface impasses via the journal `message: builder → liaison` channel and let the orchestrator decide whether to re-dispatch as a probe; flipping disciplines mid-dispatch destroys the maintainer's signal of which deliverable they were getting.

## Notes from the field

- _2026-05-15_: the verb landed when kriskowal said *"Please dispatch a builder to attempt to implement this tentative design, in order to reveal gaps. This kind of feedback has been a pretty common so please ask the gardener to create a skill and give a verb to the liaison for invoking it."* The directive named the recurrence (the maintainer had used this pattern several times in recent weeks without a verb for it) and asked for both the skill and the orchestrator verb in one motion. The companion dispatch is `entries/2026/05/15/034700Z-dispatch-liaison-4a8df9.md` (builder attempting [`endojs/endo-but-for-bots#138`](https://github.com/endojs/endo-but-for-bots/pull/138)'s OCapN/Daemon-integration design); its pre-flight gap list is the worked example of how the orchestrator surfaces gaps upfront and how the builder folds them into the numbered inventory.
