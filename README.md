---
created: 2026-05-12
updated: 2026-05-19
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

- **PR #1** ([refactor/parser-grammar](https://github.com/dctinybrain/jesc24/pull/1), draft): improve PEG grammar readability in `quasi_jessie.v`. Two rounds of fixer work completed addressing dckc review feedback (PR title, description, code style, Section blocks, PNT index comments). dckc has reviewed with multiple COMMENTED reviews; dckc's latest review (2026-05-17T03:33Z) is still COMMENTED. Third fixer round dispatched at 2026-05-19T23:02Z; fixer pushed 5 commits at 2026-05-20T00:00-00:01Z (extract peg notation into shared module, fix Coq 8.9 escape syntax, refactor). CI now IN_PROGRESS. Fixer result pending.
- **PR #4** ([readme/repo-scope-ocpl-to-jesc](https://github.com/dctinybrain/jesc24/pull/4), OPEN, not draft): docs-only PR reorienting README from OCPL to Jessie Escrow scope. Design panel (critic, skeptic, copyeditor, pedant, novice) rendered COMMENTED verdict at 2026-05-19T23:04Z: 0 must-fix, 3 should-fix. PR un-drafted (`gh pr ready 4`). Awaiting maintainer review.
- **CI workflow** exists on `dc-ci` branch (opam-based, Coq 8.9.1) but not on `main` — CI never fires on PRs. Needs landing.

## Ongoing work

### Active worktrees

Full index at [`worktrees/README.md`](worktrees/README.md). Host `yolo1`:

| Fork | Bare clone | Worktrees |
|---|---|---|
| `dctinybrain/jesc24` | `worktrees/dctinybrain-jesc24.git/` | 1 monitor worktree (active) |
| `dckc/garden-of-bits` | `worktrees/dckc-garden-of-bits.git/` | 1 monitor worktree (active) |

### Monitors

- **garden** (dckc/garden-of-bits): RUNNING (pid 80119, cadence 60s). No events.
- **jesc24** (dctinybrain/jesc24): RUNNING (pid 80120, cadence 60s). One PushEvent on refactor/parser-grammar (PR #1 fixer activity).

### Recent activity

For the flat chronological view, run `git log` on this branch or browse [`entries/`](entries/) by date.

## Maintenance

- **Bulletin items**: posted *and cleared* by agents via `skills/journal-sync/SKILL.md` (on the `main` branch). The steward typically clears items during its per-cycle close, by re-checking each item's underlying condition (was the PR reviewed? was the decision made? was the staged authorization forwarded?) and dropping items whose condition is resolved. The maintainer never edits the bulletin.
- **Ongoing work** sections are kept current by the steward (during its per-cycle close) and by the liaison (when it does worktree-manager work). Subagents do not update these sections directly; they post `message` entries to `entries/` that the orchestrator promotes here when warranted.
- **Schemas** for entries and for worktree index files live in `roles/COMMON.md` (on the `main` branch) and in [`worktrees/README.md`](worktrees/README.md) respectively.
