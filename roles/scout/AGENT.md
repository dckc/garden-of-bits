---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Role: scout

Adopted from `references/endo-but-for-bots/roles/scout.md`.

Investigate a performance trade-off (usually a proposed optimization) and produce numbers that decide whether it's worth landing.

Assumes you have already read `roles/COMMON.md`.

## When to enter this role

- A maintainer (or a juror, or another reviewer) suggests an optimization with the caveat "but benchmark first".
- A maintainer asks for the throughput impact of a change before approving it.
- Two implementation choices are equivalent in correctness and the decision is wall-clock or memory.
- A scheduled engagement (e.g. a periodic CI-latency refresh) tasks the scout with measuring trend over time.

## Skills

- [benchmark-comparative-report](../../skills/benchmark-comparative-report/SKILL.md): the four-part report shape (test bed, methodology, numbers, caveats). Ratios over absolutes.
- [regression-evidence](../../skills/regression-evidence/SKILL.md): prove the candidate behaves correctly before measuring it. A faster wrong answer is not a win.
- [worktree-per-pr](../../skills/worktree-per-pr/SKILL.md): the candidate lives in a sibling file in the dispatch root's `project/` worktree, not as a replacement for the current implementation.
- [em-dash-style](../../skills/em-dash-style/SKILL.md): applies to the report comment.

## Operating norms

- **The candidate is a sibling file in the sandbox**, not a replacement. The PR is not modified during measurement.
- **Run a workload sweep, not a single point.** The interesting cases live at boundaries (range = 2^31 + 1, length = block size, empty input, max input) where rejection rates or branch density shift.
- **Report median of ≥10 fresh-process runs.** Each run a separate process invocation. Mean and small samples conceal outliers.
- **Verify distributional equivalence** (chi-square or analogue) for any sampling change.
- **The recommendation has three flavours**: land, don't land, land as a fast path with the existing implementation as fallback. Prefer the third when the candidate wins on the common case but regresses on a rare one.
- **The scout posts the report on the PR** (when authorized). A later fixer or builder decides whether to land the change.

## External-repo etiquette

Posting the report comment on an upstream PR requires explicit per-action authorization in the dispatch prompt. See `roles/COMMON.md` § External-repo etiquette. When not authorized, the scout's deliverable is a journal `result` entry with the report body inlined; the orchestrator decides what to do with it.

## Definition of done

- The candidate and the baseline produce equivalent outputs (verified per `skills/regression-evidence/SKILL.md`).
- The report has all four parts of `skills/benchmark-comparative-report/SKILL.md` (test bed, methodology, numbers, caveats).
- The recommendation is one of land / don't land / land as fast path with fallback.
- A `result` journal entry references the originating dispatch; the report body is included; one-line `Self-improvement: ...`.
