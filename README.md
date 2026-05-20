---
created: 2026-05-12
updated: 2026-05-20
author: liaison, gardener
---

# Garden journal

## Bulletin board

### ⚠ Parallel liaison sessions

The garden was designed for a **single liaison or steward** dispatching one subagent at a time. Opencode allows multiple liaison sessions in parallel, which creates several concurrency risks:

- **Shared `journal/` worktree**: all sessions on the same host share one filesystem checkout. Concurrent `git add`/`commit`/`push` sequences race on `index.lock` and `git push` rejection. The `git reset --hard` in `skills/journal-sync/SKILL.md` was replaced with `git merge --ff-only` (commit `39140da`) to avoid silently destroying uncommitted journal entries, but the underlying races remain (stale `index.lock`, push-rejection retry limits).
- **Bulletin edits**: concurrent edits to this file from two sessions will clobber each other. Only one session should edit `journal/README.md` at a time.
- **Garden meta edits**: concurrent edits to `roles/`, `skills/`, or top-level docs from two sessions racing on `main` can produce non-fast-forward push rejections; the losing session's work stays local.
- **Fork branch pushes**: two subagents from different liaison sessions pushing to the same branch on the same fork will collide (second push rejected).

**Practical mitigation**: treat the garden as single-user for meta-edits. If you must run multiple sessions, coordinate by area — one session handles journal/bulletin, another handles fork worktrees on different repos or branches. When in doubt, wait for the other session to push its journal entries before writing your own.

### Garden bootstrap checklist

<!-- BEGIN bootstrap-checklist -->
- [x] opencode installed and authenticated (dctinybrain)
- [x] git identity configured (dctinybrain / dckc+tinybrain@madmode.com)
- [x] fork bare clones: `dctinybrain-jesc24.git`, `dckc-garden-of-bits.git`
- [x] journal worktree exists on `journal` branch
- [x] PR #1 (refactor/parser-grammar) opened on `dctinybrain/jesc24`
- [x] steward cycle runs (model name fixed)
- [ ] CI workflow landed on `main` (currently only on `dc-ci` branch)
- [ ] pre-existing build failure fixed (collections.vo ordering, Coq stdlib deprecation)
- [ ] steward cron installed (`./garden cron install`)
- [ ] bootstrap checklist encoded as a proper doc so agents can track it
<!-- END bootstrap-checklist -->

### dctinybrain/jesc24

- **PR #1** ([refactor/parser-grammar](https://github.com/dctinybrain/jesc24/pull/1), draft): improve PEG grammar readability in `quasi_jessie.v`. Three rounds of fixer/shepherd work completed: fixer addressed dckc review feedback and extracted PEG notation; shepherd #1 fixed `star` import in `peg_notation.v`; shepherd #2 fixed `Z vs nat` type error in `quasi_jessie.v` (annotated PNT index constants with `: nat`). CI is **GREEN** as of 2026-05-20T01:16Z. dckc's prior COMMENTED reviews from before the refactoring remain; awaiting dckc re-review.
- **PR #4** ([readme/repo-scope-ocpl-to-jesc](https://github.com/dctinybrain/jesc24/pull/4), OPEN, not draft): docs-only PR reorienting README from OCPL to Jessie Escrow scope. Design panel (critic, skeptic, copyeditor, pedant, novice) rendered COMMENTED verdict at 2026-05-19T23:04Z: 0 must-fix, 3 should-fix. PR un-drafted (`gh pr ready 4`). Awaiting maintainer review.
- **PR #5** ([design/repo-org](https://github.com/dctinybrain/jesc24/pull/5), draft): design document proposing repo reorganization to vendor Iris and OCPL materials. Design panel judge dispatched at 2026-05-20T00:30Z (judge--275856) did not return a result; the PR was re-classified as not design-only (includes vendored sources and build config). Shepherd dispatched at 2026-05-20T02:05Z (shepherd--235901) for CI fix; CI IN_PROGRESS as of 02:30Z. Cleaner and code-panel judge to follow once CI is green.
- **PR #6** ([design/repo-org](https://github.com/dctinybrain/jesc24/pull/6), draft): **duplicate** of PR #5 (same branch, same title, same body). Steward messaged liaison to close.
- **CI workflow** exists on `dc-ci` branch (opam-based, Coq 8.9.1) but not on `main` — CI never fires on PRs. Needs landing.

## Ongoing work

### Active worktrees

Full index at [`worktrees/README.md`](worktrees/README.md). Host `yolo1`:

| Fork | Bare clone | Worktrees |
|---|---|---|
| `dctinybrain/jesc24` | `worktrees/dctinybrain-jesc24.git/` | 1 monitor worktree (active) |
| `dckc/garden-of-bits` | `worktrees/dckc-garden-of-bits.git/` | 1 monitor worktree (active) |

### Monitors

- **garden** (dckc/garden-of-bits): RUNNING (pid 149444, cadence 60s). No events.
- **jesc24** (dctinybrain/jesc24): RUNNING (pid 149445, cadence 60s). PushEvent on design/repo-org (shepherd PR #5 CI fix, 02:30Z).

### Recent activity

For the flat chronological view, run `git log` on this branch or browse [`entries/`](entries/) by date.

## Maintenance

- **Bulletin items**: posted *and cleared* by agents via `skills/journal-sync/SKILL.md` (on the `main` branch). The steward typically clears items during its per-cycle close, by re-checking each item's underlying condition (was the PR reviewed? was the decision made? was the staged authorization forwarded?) and dropping items whose condition is resolved. The maintainer never edits the bulletin.
- **Ongoing work** sections are kept current by the steward (during its per-cycle close) and by the liaison (when it does worktree-manager work). Subagents do not update these sections directly; they post `message` entries to `entries/` that the orchestrator promotes here when warranted.
- **Schemas** for entries and for worktree index files live in `roles/COMMON.md` (on the `main` branch) and in [`worktrees/README.md`](worktrees/README.md) respectively.
