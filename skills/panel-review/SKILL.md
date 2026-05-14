---
created: 2026-05-13
updated: 2026-05-14
author: gardener
---

# Skill: panel-review

Adopted from `references/endo-but-for-bots/skills/panel-review-12-perspectives.md` and reshaped for this garden's six-seat default panel.

The aggregation discipline and submission contract for jury reviews. The default jury in `skills/pr-creation-flow/SKILL.md` is six seats (assessor, stylist, archivist, curator, locksmith, saboteur) dispatched by the [judge](../../roles/judge/AGENT.md); this skill describes how their findings combine into one verdict and how the judge submits that verdict.

## When to use

- Every PR-creation-flow jury round. The judge is the panel's foreperson (aggregates the six per-juror blocks into one body and submits the formal review).
- A maintainer-requested standalone review of a stale PR. Same procedure; the orchestrator names the panel composition in the dispatch brief and the judge dispatches that composition.

## Panel composition

- **Default for PR-creation flow: six seats** (assessor, stylist, archivist, curator, locksmith, saboteur), dispatched as a single panel round by the judge. The judge picks sequential or concurrent at its discretion; the panel's deliverable is the same shape either way. See `skills/pr-creation-flow/SKILL.md` § Jury composition for the seat list and the deliberate-overlap rationale.
- **Smaller panels** (e.g., three seats for a tiny PR) are valid when the orchestrator names a reduced composition in the dispatch brief.
- **Larger panels** are supported by the same aggregation rules. The reference's 12-perspective panel (correctness, test coverage, types, API stability, diff hygiene, error messages, performance, naming, changeset, backwards compatibility, docs, security, plus the adversarial slot) remains a viable composition when a PR is large or important enough that the six-seat default would miss a perspective. The judge dispatches each named seat and aggregates them all.

## Per-juror block shape

Each panel member returns:

```
### <perspective name>

**Verdict:** approve / request-changes / comment-only

**Findings:**
- (concrete actionable, file:line where applicable)

**Notes (out of scope but worth flagging):**
- ...
```

Each block under ~400 words. "Comment-only" is for taste; anything that warrants a code change is "request-changes".

## Aggregation

The judge groups findings into:

- **Must fix before merge** (any "request-changes" with concrete code / test / doc impact). Drives the jury-fixer loop per `skills/pr-creation-flow/SKILL.md`.
- **Should fix in this PR** (taste or clarity items raised independently by at least two seats; on a six-seat panel the deliberate inquiry-area overlap means routine duplicate flagging is expected and is the signal "promote to should-fix").
- **Out of scope / follow-up** (useful but not blocking this PR's loop).

Dedupe overlapping findings. Where panel members disagree, present both views and pick the side most consistent with the project's `CLAUDE.md` (or `AGENTS.md`); make the disagreement explicit so the orchestrator can act.

## In-scope vs out-of-scope

The jury-fixer loop iterates only on **must-fix and should-fix items in scope for the PR's change**. Out-of-scope complaints (adjacent refactors, package-wide hygiene, follow-up issues) live in the "Out of scope / follow-up" section and do not block the loop. The orchestrator surfaces them as separate issues or follow-up PRs after the jury declares the loop done.

See `skills/pr-creation-flow/SKILL.md` § Jury-fixer loop for the loop's exit condition.

## Posting the review

**Submit as a formal review, not a plain comment.** A plain `gh pr comment` does not flip `reviewDecision`, so the orchestrator's dispatch matrix never sees the verdict and the jury-fixer loop never advances.

```sh
gh pr review <N> -R <repo> --request-changes --body-file /tmp/panel.md
# OR if must-fix is empty but should-fix has items:
gh pr review <N> -R <repo> --comment --body-file /tmp/panel.md
# OR if the panel net-approves with no findings (rare for a fresh PR):
gh pr review <N> -R <repo> --approve --body-file /tmp/panel.md
```

The judge submits the formal review. The body is the same aggregated report (typically 700 to 1200 words for the six-seat default; smaller panels run shorter, larger ones run longer). Cite findings by perspective grouped where members agreed; do not list individual agent names.

## Pitfalls

- **Panel-report prose is not exempt from the project style rules.** The aggregated body ships in a public PR review. The same prose rules apply (no em-dashes per `skills/em-dash-style/SKILL.md`, no methodology leaks per `skills/pre-pr-checklist/SKILL.md`). Sweep the body before submitting.
- **A "shadow" finding may be a panel hallucination.** Variable-shadowing claims need a 30-second sanity check before promoting to a should-fix item. Re-read the offending lines and confirm they are in the same lexical scope. A panel run that reads the diff once can mis-name a parameter as shadowing an outer const that lives in a different function.
- **Sibling-package forks miss recent peer fixes.** When a PR introduces a package by forking an existing peer, the correctness perspective should diff the new sibling against the peer's recent commits for fixes that landed between the fork point and the PR's submission. A one-line check that pays for itself on every sibling-fork PR.
- **GitHub blocks `--request-changes` on a self-authored PR.** When the authenticated identity is also the PR's author, the submission returns a GraphQL error. Fall back to `--comment` with the full body; the verdict is preserved in the body, but `reviewDecision` does not flip. The orchestrator's dispatch matrix that keys on `reviewDecision` also keys on the "Must-fix before merge" heading in the body for bot-authored PRs.
- **Design-plus-implementation in one PR needs a design-assessment posture.** When a PR implements all phases of a design as a single deliverable explicitly to assess the design's completeness, the panel's job grows beyond "is this code correct" to include "did the design specify enough to implement, and where did the builder fill in gaps?". The aggregate body carries an "Out of scope but worth flagging (design feedback)" section listing the panel's answers, intended as input back to the design PR rather than as fixer-brief items.

## Notes from the field

- _2026-05-13_: adopted from the reference and reshaped for the 2-member default panel (juror plus saboteur). The reference's 12-perspective form was preserved as a larger-panel option.
- _2026-05-14_: redesign. The default panel grew from 2 seats to 6 named seats (assessor, stylist, archivist, curator, locksmith, saboteur), the judge role was introduced as the panel's foreperson (it aggregates and submits, but is not itself a reviewer), and per-juror block submission migrated from "the juror is the panel-side editor" to "each seat returns a block, the judge aggregates". The orchestrator names a different composition in the dispatch brief when the default does not fit.
