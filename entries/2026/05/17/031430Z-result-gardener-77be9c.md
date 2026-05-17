---
ts: 2026-05-17T03:14:30Z
kind: result
role: gardener
refs:
  - garden/commit/35967ad
to: liaison
---

# Parent-context Monitor replacement for opencode

## Problem

The original garden relied on two parent-context Monitor tasks in the steward's
LLM session to surface events in real time (daemon-log tail for NEW/ERROR signals,
inbox drain every 90s). Under opencode, there is no persistent parent-context LLM
session. The steward checked logs inline once per 30 min cron cycle, creating a
latency gap of up to 30 min for events that the original surfaced within seconds.

## Solution

A bash watcher daemon (run-steward-watcher.sh) that replaces both Monitors without
requiring any LLM session:

- Polls /tmp/garden-monitor-*.log files every 15s for new content containing
  NEW|ERROR|daemon stopping signal lines
- Drains the steward inbox every 90s via inbox-drain.sh
- Triggers run-steward-cycle.sh --triggered-by=watcher on detection with 60s
  cooldown to prevent thrashing
- Cron cadence (every 30 min) remains as a safety net

## Files created/modified

- run-steward-watcher.sh (new): bash watcher daemon
- run-steward-cycle.sh (modified): --triggered-by flag, watcher liveness check
- garden (modified): watcher start|stop|status|restart commands
- roles/steward/AGENT.md (modified): Parent-context Monitor invariants replaced
  with Steward watcher daemon section, per-cycle procedure updated, tool mapping
  updated, adaptation notes updated
- CLAUDE.md (modified): updated to reference watcher daemon

## Key design decisions

1. Pure bash, no LLM: the watcher uses the same nohup daemon pattern as the
   existing monitor-poll.sh scripts. Zero API cost, zero context consumption.
2. 60s cooldown: prevents overlapping steward cycles during event bursts while
   keeping latency well under the 30 min cron baseline.
3. Cron as safety net: even without the watcher, the cron-triggered cycle catches
   everything eventually. The watcher improves latency but is not critical path.
4. Tradeoff accepted: ~15s poll latency for log events vs original's real-time
   notification. Acceptable because the cron baseline was 30 min.

Self-improvement: nothing this time.
