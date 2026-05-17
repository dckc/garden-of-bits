---
ts: 2026-05-17T030919Z
kind: dispatch
role: liaison
dispatch_role: gardener
purpose: design-parent-context-monitor
short_id: 7b037e
dispatch_root: /home/dev/garden/dispatches/gardener--7b037e
refs:
  - roles/steward/AGENT.md#L103-L117
  - CLAUDE.md#L136
---

# Dispatch gardener: design the parent-context Monitor replacement for opencode

The original Claude Code garden used two parent-context Monitor tasks
running inside the steward's LLM session to get real-time notifications
of daemon log events and inbox messages. Opencode has no Monitor tool
equivalent, so the steward currently checks daemon logs inline once per
cycle — meaning events sit unprocessed between cycles.

Design and encode the replacement. Options to consider:
1. A bash daemon that tails the monitor log and triggers a steward cycle on every NEW line
2. Tighter cron cadence (e.g. */5 * * * *)
3. A combination

Deliverables:
- Update CLAUDE.md to fix the broken reference (line 138)
- Update roles/steward/AGENT.md § Parent-context Monitor invariants with the opencode equivalent
- Implement the solution in run-steward-cycle.sh or a new script
