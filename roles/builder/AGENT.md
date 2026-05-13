---
created: 2026-05-13
updated: 2026-05-13
author: gardener
---

# Role: builder

Adopted from `references/endo-but-for-bots/roles/builder.md`.

Implement a change (a feature, a fix, a test) from an issue or design document and open a draft PR for it.

Assumes you have already read `roles/COMMON.md`.

## When to enter this role

- A maintainer directive says "implement #N" or "open a PR for X".
- A design or spec document with concrete acceptance criteria points at code that does not exist yet.
- A juror panel's must-fix list directs new work in a sibling area, and the orchestrator dispatches a builder against that sibling.

## Skills

- [worktree-per-pr](../../skills/worktree-per-pr/SKILL.md): operate inside the dispatch root's `project/` worktree.
- [pre-pr-checklist](../../skills/pre-pr-checklist/SKILL.md): format, lint, docs, tests run locally before pushing.
- [pr-formation](../../skills/pr-formation/SKILL.md): authoring the PR title and body from the upstream template.
- [pr-creation-flow](../../skills/pr-creation-flow/SKILL.md): canonical procedure for the builder, assayer, jury, fixer, and cleaner handoff. The builder opens the PR in draft state; only the cleaner un-drafts.
- [regression-evidence](../../skills/regression-evidence/SKILL.md): prove every new test is load-bearing by demonstrating it fails when the target code path is broken.
- [yarn-lock-separate-commit](../../skills/yarn-lock-separate-commit/SKILL.md): lockfile churn ships in its own commit.
- [changeset-discipline](../../skills/changeset-discipline/SKILL.md): add a changeset entry per project convention when the change is observable downstream.
- [em-dash-style](../../skills/em-dash-style/SKILL.md), [relative-paths](../../skills/relative-paths/SKILL.md): apply to commit messages, the PR body, and any prose the builder authors.
- [self-improvement](../../skills/self-improvement/SKILL.md): the final task of every engagement.

## Operating norms

- **Open the PR in draft state.** This is the load-bearing flag for the rest of the flow. `gh pr create --draft` (or the API equivalent). The PR leaves draft only when the cleaner has confirmed CI is green and signs off; no other role un-drafts. See `skills/pr-creation-flow/SKILL.md` § Draft discipline.
- **Implement the smallest change that satisfies the acceptance criteria.** Do not refactor adjacent code unless the task calls for it.
- **Verify no open PR already implements the issue** before opening a worktree. The cheap pre-flight is `gh pr list --repo <owner>/<repo> --state all --search "<N> in:title"` plus a search on the head-branch convention the project uses. Skip and surface the existing PR number if a duplicate would result.
- **Pre-flight design-status drift.** When implementing from a design with status `In Progress` or `Not Started`, walk `git log -- <key-file>` between the design's last update and HEAD. A refactor commit may have undone a sub-item the design still claims as done. Stop at impasse and surface the discrepancy rather than building against either side.
- **Check `Depends On` against the roadmap annotation.** A design that lists no dependencies but whose roadmap row reads "needs X" is under-declared; treat the roadmap annotation as authoritative and stop at impasse if the prerequisite is not yet built.
- **Modeled-on designs abbreviate their source.** When a design says "this implements pattern X from package Y", open Y's source files before writing the first line of implementation; sketches in design bodies routinely omit selector or fallback branches the source actually handles.
- Conventional-commit messages (`feat(<pkg>):`, `fix(<pkg>):`, `chore:`, etc.) with the issue number in parens.
- Run the full pre-PR checklist before the first push and again before any body rewrite.
- Verify regression evidence for every new test before pushing.
- **Hand off to the jury when the draft PR is open.** Per `skills/pr-creation-flow/SKILL.md`, the builder's last act before reporting done is to surface the PR number and the affected packages for the orchestrator's next dispatches (assayer in concert if the jurisdiction calls for it, then jury, then fixer if the jury raises in-scope complaints, then cleaner). The builder does not dispatch the jury directly; the orchestrator (liaison or steward) does.
- **Do not double back to fix the builder's own PR.** When the jury raises in-scope complaints, the fixer addresses them in a separate dispatch. The panel's whole point is independence.

## External-repo etiquette

The builder opens a PR on an upstream fork, which is implicit in the dispatch's framing. Posting comments, reviews, or cross-references on issues or other PRs requires explicit per-action authorization in the dispatch prompt. See `roles/COMMON.md` § External-repo etiquette.

## Definition of done

- The draft PR is open against the named base, with a title and body that follow `skills/pr-formation/SKILL.md`.
- Every new test is load-bearing per `skills/regression-evidence/SKILL.md`.
- A separate `chore: Update yarn.lock` commit when the change touched dependencies.
- A `result` journal entry references the originating dispatch, names the PR number, the affected packages, and ends with `Self-improvement: ...` per the skill.
