---
created: 2026-05-12
updated: 2026-05-20
author: liaison
---

# Garden journal

## Bulletin board

### Pending reviews

| PR | Title | State | CI | Notes |
|----|-------|-------|----|-------|
| [#4](https://github.com/dctinybrain/jesc24/pull/4) | docs: reorient README from OCPL to jesc (Jessie Escrow) scope | **OPEN** (not draft) | ✅ GREEN | Design panel COMMENTED (0 must-fix, 3 should-fix). Ready for your review. |

### New PRs to triage

| PR | Title | State | CI | Notes |
|----|-------|-------|----|-------|
| [#7](https://github.com/dctinybrain/jesc24/pull/7) | chore: move Iris/OCPL materials to vendor/iris-coq/ | **DRAFT** | ✅ GREEN | Organizational refactor, 172 files moved. Implements design from PR #5. Needs review. |

PRs #1, #5 are still in draft — not ready for your review yet.


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
- [x] steward cron installed (`./garden cron install`) — firing every 30 min
- [x] CI workflow landed on `main` (`.github/workflows/ci.yml`, active)
- [ ] pre-existing build failure fixed (collections.vo ordering, Coq stdlib deprecation)
- [ ] bootstrap checklist encoded as a proper doc so agents can track it
- [ ] `dc-ci` branch on dctinybrain/jesc24 closed (irrelevant)
<!-- END bootstrap-checklist -->

### dctinybrain/jesc24

- **PR #4** ([readme/repo-scope-ocpl-to-jesc](https://github.com/dctinybrain/jesc24/pull/4), OPEN, not draft): docs-only PR reorienting README from OCPL to Jessie Escrow scope. Design panel (critic, skeptic, copyeditor, pedant, novice) rendered COMMENTED verdict at 2026-05-19T23:04Z: 0 must-fix, 3 should-fix. PR un-drafted. CI GREEN. Ready for maintainer review.
- **PR #5** ([design/repo-org](https://github.com/dctinybrain/jesc24/pull/5), draft): design doc proposing repo reorganization to vendor Iris and OCPL materials. Design resolved (tests move down, docs move down, `-Q` stays `iris`). Not ready for review.
- **PR #6** ([design/repo-org](https://github.com/dctinybrain/jesc24/pull/6)): **CLOSED** — was a duplicate of PR #5.
- **PR #7** ([feat/vendor-iris-coq](https://github.com/dctinybrain/jesc24/pull/7), draft): implementation of PR #5's design — moves Iris/OCPL materials to `vendor/iris-coq/`, updates `_CoqProject` and `README` paths. Build verified. Next stage: judge (code panel, 12 seats). **BLOCKED** — steward cycles hung (see bulletin), no judge dispatched.
- **PR #1** ([refactor/parser-grammar](https://github.com/dctinybrain/jesc24/pull/1), draft, base: `dc-jessie`): improve PEG grammar readability in `quasi_jessie.v`. Three rounds of fixer/shepherd work completed. CI GREEN. dckc's prior COMMENTED reviews predate the refactoring; awaiting re-review. Not ready for review.
- **CI**: `.github/workflows/ci.yml` on `main`, active and passing. The `dc-ci` branch is irrelevant and should be closed.

## Ongoing work

### Active worktrees

Full index at [`worktrees/README.md`](worktrees/README.md). Host `yolo1`:

| Fork | Bare clone | Worktrees |
|---|---|---|
| `dctinybrain/jesc24` | `worktrees/dctinybrain-jesc24.git/` | 1 monitor worktree (active) |
| `dckc/garden-of-bits` | `worktrees/dckc-garden-of-bits.git/` | 1 monitor worktree (active) |

### Monitors

- **garden** (dckc/garden-of-bits): RUNNING. No events.
- **jesc24** (dctinybrain/jesc24): RUNNING. Caught PR #7 open at 04:43 UTC. Watcher triggered steward cycles but they hung (see bulletin above).

### Recent activity

For the flat chronological view, run `git log` on this branch or browse [`entries/`](entries/) by date.

## Maintenance

- **Bulletin items**: posted *and cleared* by agents via `skills/journal-sync/SKILL.md` (on the `main` branch). The steward typically clears items during its per-cycle close, by re-checking each item's underlying condition (was the PR reviewed? was the decision made? was the staged authorization forwarded?) and dropping items whose condition is resolved. The maintainer never edits the bulletin.
- **Ongoing work** sections are kept current by the steward (during its per-cycle close) and by the liaison (when it does worktree-manager work). Subagents do not update these sections directly; they post `message` entries to `entries/` that the orchestrator promotes here when warranted.
- **Schemas** for entries and for worktree index files live in `roles/COMMON.md` (on the `main` branch) and in [`worktrees/README.md`](worktrees/README.md) respectively.
