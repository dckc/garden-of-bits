---
ts: 2026-05-19T22:20:00Z
kind: dispatch
role: gardener
refs:
  - entries/2026/05/15/060311Z-result-gardener-245744.md
  - entries/2026/05/15/101935Z-message-liaison-garden-deploy-key.md
---

# Reboot resilience: yolo1 fixup

yolo1 was rebooted. Both monitor daemons stayed dead for ~2 days. The
steward's cron was silently failing because `opencode` was not in cron's
PATH. The steward correctly identified the gaps. This dispatch fixes them.

Scope:
1. Unconditional monitor respawn in run-steward-cycle.sh
2. Wire jesc24 into PR-creation-flow for judge dispatch
3. Clean stale understudy presence file
4. Verify PATH fix in run-steward-cycle.sh
