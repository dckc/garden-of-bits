---
ts: 2026-05-15T12:49:00Z
kind: dispatch
role: liaison
project: garden-of-bits
to: "*"
---

# Dispatch: gardener — fix bot identity and pause review queue

Dispatch root: `dispatches/gardener--09003d/`. Project worktree on `dckc/garden-of-bits@main`.

Two things need fixing in the steward configuration:

## 1. Fix bot identity in PR-creation-flow scan

In `roles/steward/AGENT.md`, lines 316 and 329 reference `kriscendobot` as the bot identity. This garden runs under `dctinybrain`, not `kriscendobot`. Change both occurrences.

Also check `skills/pr-creation-flow/SKILL.md` for the same issue — it references `--author kriscendobot` and `dctinybrain`-authored panel verdicts; those may have been fixed by the prior gardener dispatch but verify.

## 2. Pause the review-queue daemon

The review-queue polls kriskowal's pending-review set. That's irrelevant for dckc's garden. The review-queue should be paused:

- In `roles/steward/AGENT.md`: Add a DORMANT/PAUSED note to the review-queue row in the standing monitors table. Remove the review-queue from the liveness check and respawn instructions. Note the pause in the active-set paragraph. The review-queue row can stay for documentation but mark it paused.

- In `roles/review-queue/AGENT.md`: Add a DORMANT banner at the top (same pattern as the collected monitor skills: `> **DORMANT as of 2026-05-15.**`).

- In `run-steward-cycle.sh`: Remove or comment out the review-queue daemon check and log lines. The script should only check the garden-of-bits daemon.

- In `skills/review-queue-poll/SKILL.md`: Add a DORMANT banner.

## 3. Restart the garden-of-bits daemon

The daemon died in the host reboot. Create a new monitor worktree and start it:

```sh
cd /home/dev/garden && git worktree add worktrees/dckc-garden-of-bits/watch-garden-of-bits--monitor--$(date -u +%Y%m%d-%H%M%S) --detach main
```

Then start the daemon:

```sh
nohup bash skills/github-activity-poll/monitor-poll.sh dckc/garden-of-bits \
  worktrees/dckc-garden-of-bits/watch-garden-of-bits--monitor--<ts> 60 \
  > /tmp/garden-monitor-dckc-garden-of-bits.log \
  2> /tmp/garden-monitor-dckc-garden-of-bits.err &
echo $! > /tmp/garden-monitor-dckc-garden-of-bits.pid
```

## Commit and push

Single commit: `chore: fix steward bot identity to dctinybrain, pause review-queue`

Push: `git push origin HEAD:main`

Write a `result` journal entry and push that too.

## Out of scope

- No endo-related changes (already dormant)
- No changes to other roles or skills (already adapted)

## Report

List each file changed and the one-line `Self-improvement: ...`.