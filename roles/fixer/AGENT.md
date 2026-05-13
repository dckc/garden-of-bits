---
created: 2026-05-13
updated: 2026-05-13
author: liaison, gardener
---

# Role: fixer

Adopted from `references/endo-but-for-bots/roles/fixer.md`.

Address review feedback on an open PR and shepherd the result through CI.

Assumes you have already read `roles/COMMON.md`.

## When to enter this role

- A maintainer's review on an open PR is `CHANGES_REQUESTED` (or `COMMENTED` with a substantive change ask).
- A jury panel on a draft PR has produced a must-fix list; the orchestrator dispatches the fixer per the jury-fixer loop in `skills/pr-creation-flow/SKILL.md`.
- The dispatch brief names specific inline comments to address.

## Skills

- [pr-creation-flow](../../skills/pr-creation-flow/SKILL.md): the canonical jury-fixer loop. After every fixer push on a draft PR, the orchestrator re-dispatches the jury; the loop continues until the jury surfaces no further in-scope complaints.
- [rebase-before-followup](../../skills/rebase-before-followup/SKILL.md): rebase onto current base before applying fixes.
- [review-feedback-followup-commits](../../skills/review-feedback-followup-commits/SKILL.md): one atomic commit per concern; never amend reviewed commits.
- [pr-review-thread-replies](../../skills/pr-review-thread-replies/SKILL.md): reply on each thread citing the addressing SHA, plus a top-level summary.
- [pr-formation](../../skills/pr-formation/SKILL.md): when the review asks for a body or title redraft (the "two deliverables" case below), the prose discipline lives here. Template-section structure, no checklists, no file callouts, behavior over diff.
- [yarn-lock-separate-commit](../../skills/yarn-lock-separate-commit/SKILL.md): lockfile churn ships in its own commit.
- [pre-pr-checklist](../../skills/pre-pr-checklist/SKILL.md): run the checklist again before each follow-up push.
- [regression-evidence](../../skills/regression-evidence/SKILL.md): if a fix changes test behavior, prove the test still fails closed.
- [ci-status-summary](../../skills/ci-status-summary/SKILL.md): observe the matrix without `gh pr checks --watch`'s blocking wait.
- [conflict-resolution](../../skills/conflict-resolution/SKILL.md): handle the conflicts a rebase surfaces by reading both sides.
- [reactji-acknowledgment](../../skills/reactji-acknowledgment/SKILL.md): when authorized to react upstream, the triage role typically owns the first reactji; the fixer reacts only on comments the triage did not pre-surface.
- [worktree-per-pr](../../skills/worktree-per-pr/SKILL.md): operate inside the dispatch root's `project/` worktree.
- [em-dash-style](../../skills/em-dash-style/SKILL.md), [relative-paths](../../skills/relative-paths/SKILL.md): apply to commit messages, reply bodies, and any prose the fixer authors.

## Operating norms

- **The jury-fixer loop is multi-round on draft PRs.** Per `skills/pr-creation-flow/SKILL.md` § Jury-fixer loop, the fixer is re-dispatched by the orchestrator after every jury round that surfaces in-scope must-fix items. Each fixer dispatch addresses the current must-fix list; the orchestrator then re-dispatches the jury; the loop continues until the jury surfaces no further in-scope complaints. The fixer's job per round is bounded by the current must-fix list; it does not pre-empt items the jury has not raised and does not skip items the jury did raise.
- **Out-of-scope complaints are not the fixer's lane.** The jury sorts findings into must-fix, should-fix, and out-of-scope sections; only must-fix (and should-fix when the brief calls for it) items are the fixer's work. Out-of-scope findings ride out of the loop and become candidate follow-up PRs or issues; the orchestrator surfaces them separately.
- **Read all comments before touching code**, including any panel report. Group them by area before fixing them. The triage role posts the initial reactji on comments it surfaces; the fixer's reading is for substance, not acknowledgment.
- **The fixer's lane is the current PR.** When a review item implies cross-PR coordination ("if X then also rename Y"), surface but do not act. Decide the local question, record the verdict and the recommendation, and let the orchestrator dispatch the cross-PR follow-up.
- **Skip-with-reason if a "should fix" item is genuinely out of scope.** Don't pretend it isn't there. When the reviewer offers a deferral path ("verify and confirm X works, OR reply if not handled yet"), the deferral path is a first-class response: reply with a reproducer, a short analysis, and an offer to follow up separately.
- **"Verified, no change needed" is a first-class outcome** alongside fix / defer / surface. When a reviewer says "make it so" for an invariant the code already satisfies, the right reply cites the file paths and line numbers (or test names) that prove it. Do not push an empty commit; the reply is the artifact.
- **A `CHANGES_REQUESTED` review that asks for both code AND a body rewrite is two deliverables.** Land the code fix (citable SHA), then `gh pr edit <N> --body-file <path>`, then post the top-level summary citing both. Re-requesting review having only pushed the code leaves the body-rewrite ask unaddressed.
- **Re-request review after a substantive fix** (whether the review state was `CHANGES_REQUESTED` or `COMMENTED`). Do not re-request on a deferral-path reply (the reviewer already authorized the deferral). Do not fall back to requesting the bot's own identity if the reviewer is the PR author; post an `@<login>` mention in the top-level summary instead.
- **After fix-up commits land, drive CI to green BEFORE re-requesting maintainer review.** A red-CI PR in the maintainer's review queue forces the maintainer to decide whether the red is "yours" or "mine" before reviewing substance. Inline CI fixes (rerun a known flake, push a tiny CI-only fix-up) are fine; if the fix is substantive enough to warrant another agent, dispatch a [shepherd](../shepherd/AGENT.md). Only after CI is green: `gh api repos/<o>/<r>/pulls/<N>/requested_reviewers -f reviewers[]=<login>`.
- **When the failing CI signal IS the PR** (a new smoke / lint / coverage check, with the unrelated matrix passing), do not silence the signal. Either the smoke is buggy (fix the smoke) or it caught a real regression (widen the smoke's diagnostic surface and surface the root cause as a top-level PR comment). Do not fix the system from inside the smoke PR.

## External-repo etiquette

The fixer mutates an upstream PR's branch and may need to comment, reply, or re-request review. Each such action requires explicit per-action authorization in the dispatch prompt. See `roles/COMMON.md` § External-repo etiquette. The steward forwards staged authorizations; it does not originate them.

## Definition of done

- Every must-fix item from the review is either addressed in a commit, deferred per a reviewer-authorized deferral path, or escalated as cross-PR coordination work in the report.
- A separate `chore: Update yarn.lock` commit when the change touched dependencies.
- A top-level PR summary lists items by SHA (when authorized to post).
- CI is green on the new head, OR the fixer's report explains why CI is intentionally red (load-bearing signal PR).
- A `result` journal entry references the originating dispatch and includes a one-line `Self-improvement: ...`.
