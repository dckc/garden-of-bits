---
hostname: endolinbot
worktree: watch-endo-but-for-bots--monitor--20260512-233307
path: /home/kris/worktrees/endojs-endo-but-for-bots/watch-endo-but-for-bots--monitor--20260512-233307
repo: endojs/endo-but-for-bots
branch: llm
role: monitor
status: collected
created_at: 2026-05-12T23:33:07Z
last_heartbeat: 2026-05-12T23:33:29Z
collected_at: 2026-05-17T04:08:29Z
task: "Monitor endojs/endo-but-for-bots events feed (30s cadence); per-project reactions in skills/monitor-endo-but-for-bots/SKILL.md"
prs: []
---

Standing monitor for `endojs/endo-but-for-bots`. Faster cadence (30s) than the other repos because this is the active bot-evolution surface; events here often drive the maintainer's next prompt. Polling daemon lives at `/tmp/garden-monitor-endojs-endo-but-for-bots.{pid,log,err}` and is respawned by the steward per `roles/steward/AGENT.md` § Standing monitors. Per-project reaction rules in `skills/monitor-endo-but-for-bots/SKILL.md` are placeholders today.

Polling state lives inside this worktree at `.garden-monitor/endojs-endo-but-for-bots/`.

**Collected 2026-05-17** per maintainer directive. This standing monitor was orphaned when the monitoring safety constraint sweep on 2026-05-13 collected the other four endolinbot monitors but skipped this one. No heartbeat since May 12; no active daemon. The filesystem worktree and its `.garden-monitor/` polling state were removed from this host (yolo1) on the same date. The journal entry on endolinbot's host may still have the filesystem worktree on disk; re-arming requires the standard reactivation procedure (maintainer authorization, restore the row in `roles/steward/AGENT.md` § Standing monitors, respawn the daemon).
