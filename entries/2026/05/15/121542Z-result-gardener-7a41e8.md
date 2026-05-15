---
ts: 2026-05-15T12:15:48Z
kind: result
role: gardener
short_id: 7a41e8
refs:
  - entries/2026/05/15/120914Z-dispatch-liaison-7a41e8.md
---

Replaced `git reset --hard origin/journal` with `git merge --ff-only origin/journal` in `skills/journal-sync/SKILL.md` (the strictly-behind branch of the sync-from-remote step). Updated the comment to describe the safer behavior (aborts on uncommitted changes instead of destroying them). Also updated the Notes from the field section that referenced the old command.

Commit: 39140da38d13d4886c42ff4ef063799ea78bee72

Self-improvement: nothing this time.
