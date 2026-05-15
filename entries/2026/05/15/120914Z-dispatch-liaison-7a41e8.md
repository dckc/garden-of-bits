---
ts: 2026-05-15T12:09:14Z
kind: dispatch
role: liaison
short_id: 7a41e8
dispatch_root: /home/dev/garden/dispatches/gardener--7a41e8
task: fix-reset-hard
to: gardener
refs: []
---

Dispatch gardener to replace  with  in  (line 53). The hard reset is a data-loss hazard when multiple liaison sessions write to the shared journal worktree concurrently.  is a safe drop-in: it fast-forwards on both branch checkouts and detached HEAD, but refuses if there are uncommitted changes instead of silently destroying them.
