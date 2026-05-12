---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: monitor-endo

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `endojs/endo`. The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react.

## Project

- Slug: `endo`
- Upstream: `endojs/endo` (https://github.com/endojs/endo)
- Default branch: `master`
- Daemon cadence: 60s (the `/events` endpoint is server-cached for ~60s; faster polling does not surface events sooner).

## Reactions per event class

This list is the menu; each row records the agreed action and a brief rationale. Rows still showing `(unset; propose via message to liaison)` have not been decided. The first time the monitor surfaces an event class with no rule, it writes a `message` entry to `liaison` proposing one; the liaison decides and lands the change here.

- `PushEvent` — (unset; propose via message to liaison)
- `PullRequestEvent` (opened, reopened, closed, edited, synchronize) — (unset)
- `PullRequestReviewEvent` (submitted, edited, dismissed) — (unset)
- `PullRequestReviewCommentEvent` — (unset)
- `IssuesEvent` (opened, reopened, closed, edited, assigned, labeled) — (unset)
- `IssueCommentEvent` — (unset)
- `ReleaseEvent` — (unset)
- `CreateEvent` / `DeleteEvent` (branches/tags) — (unset)
- `ForkEvent`, `WatchEvent`, `MemberEvent` — (unset)
- Other event classes — surface as a `message` to `liaison` with the raw type and a one-line context; do not silently drop.

## Notes from the field

(append dated entries as reaction rules are learned)
