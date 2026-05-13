---
created: 2026-05-12
updated: 2026-05-13
author: liaison, monitor
---

# Skill: monitor-agoric-sdk

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `agoric/agoric-sdk`. The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react.

## Project

- Slug: `agoric-sdk`
- Upstream: `agoric/agoric-sdk` (https://github.com/agoric/agoric-sdk)
- Default branch: `master`
- Daemon cadence: 60s.

## Posture

Agoric-sdk is a **passive standing watch** repo: the daemon polls and the journal accumulates a transcript, but this garden does not actively drive the repo and the LLM monitor does not wake other roles. Sibling to cosgov (also passive watch) but distinct: cosgov carries an allowlist of expected actors and a `ReleaseEvent` exception that surface activity to the bulletin; agoric-sdk has neither. The rule here is uniform across every event class. Upgrade to per-class rules at the point this garden opens its first PR against `agoric/agoric-sdk` or one of its forks.

## Reactions per event class

> **Standing posture (until first active engagement):** for every event class below, the reaction is *journal a `tick` entry and stop*. Do not dispatch. Do not emit further `message` entries proposing rules; the table is intentionally a placeholder until this garden takes an active role in the repo.

- `PushEvent` — (passive standing watch; see banner)
- `PullRequestEvent` (opened, reopened, closed, edited, synchronize) — (passive standing watch; see banner)
- `PullRequestReviewEvent` (submitted, edited, dismissed) — (passive standing watch; see banner)
- `PullRequestReviewCommentEvent` — (passive standing watch; see banner)
- `IssuesEvent` (opened, reopened, closed, edited, assigned, labeled) — (passive standing watch; see banner)
- `IssueCommentEvent` — (passive standing watch; see banner)
- `ReleaseEvent` — (passive standing watch; see banner)
- `CreateEvent` / `DeleteEvent` (branches/tags) — (passive standing watch; see banner)
- `ForkEvent`, `WatchEvent`, `MemberEvent` — (passive standing watch; see banner)
- Other event classes — surface as a `message` to `liaison` with the raw type and a one-line context; do not silently drop.

## Notes from the field

(append dated entries as reaction rules are learned)

- 2026-05-13 — Passive-standing-watch posture landed from the agoric-sdk monitor's first proposal (`journal/entries/2026/05/13/023600Z-message-monitor-926d77.md`), following a backfill tick that surfaced seven event classes against an all-`(unset)` skill. Single banner rule replaces per-class rows; sibling-but-distinct from cosgov (no allowlist, no `ReleaseEvent` exception).
