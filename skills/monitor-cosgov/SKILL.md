---
created: 2026-05-12
updated: 2026-05-13
author: gardener, liaison, monitor
---

# Skill: monitor-cosgov

> **DORMANT as of 2026-05-13.** This skill is not currently active. The `dcfoundation/cosmos-proposal-builder` (cosgov) standing monitor was collected per the monitoring safety constraint in `roles/COMMON.md` § Monitoring safety constraint (mirrored in `CLAUDE.md`): repositories whose comments and pull requests are not gated against untrusted contributors are not safe to monitor, because daemon log lines and event bodies enter the LLM's context. `dcfoundation/cosmos-proposal-builder` does not currently meet that bar. The precipitating dispatch is at [`journal/entries/2026/05/13/053822Z-dispatch-liaison-44e029.md`](../../../journal/entries/2026/05/13/053822Z-dispatch-liaison-44e029.md). The rules below are preserved verbatim for the record in case the constraint reverses; re-enabling this monitor requires explicit maintainer authorization recorded in a journal `message` entry, after which the role-author re-adds the row to `roles/steward/AGENT.md` § Standing monitors, restores the active mapping in `roles/monitor/AGENT.md`, and removes this banner.

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `dcfoundation/cosmos-proposal-builder` (aka cosgov). The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react.

## Project

- Slug: `cosgov`
- Upstream: `dcfoundation/cosmos-proposal-builder` (https://github.com/dcfoundation/cosmos-proposal-builder)
- Default branch: `main`
- Daemon cadence: 60s.

## Posture

Cosgov is **observation-only**: the garden watches the repo but does not actively drive it. Most event classes log silently in the tick entry; the bulletin is reserved for activity that signals external interest or an upstream cut.

## Allowlist of expected actors

`kriskowal`, `netlify[bot]`, `Copilot`, `kriscendobot` (the maintainer, the deploy-preview bot, the GitHub-built-in code reviewer, and the garden's own ferry account). Activity from anyone outside this list on a comment, review, or issue class is the signal that warrants surfacing.

## Reactions per event class

The rule is fundamentally one: log silently in the tick entry, except surface to the bulletin when (a) a comment, review, or issue event comes from an actor outside the allowlist, or (b) the event is a `ReleaseEvent`.

- `PushEvent`, `CreateEvent` / `DeleteEvent` (branches/tags), `ForkEvent`, `WatchEvent`, `MemberEvent` — log silently. No bulletin, no message, no further action.
- `PullRequestEvent` (opened, reopened, closed, edited, synchronize) — log silently.
- `PullRequestReviewEvent` (submitted, edited, dismissed), `PullRequestReviewCommentEvent`, `IssueCommentEvent`, `IssuesEvent` (opened, reopened, closed, edited, assigned, labeled) — log silently when the actor is in the allowlist; surface to the bulletin when the actor is outside it (external interest in a watched repo).
- `ReleaseEvent` — surface to the bulletin. Low-frequency, signals an upstream cut.
- Other event classes — surface as a `message` to `liaison` with the raw type and a one-line context; do not silently drop.

## Notes from the field

(append dated entries as reaction rules are learned)

- 2026-05-13 — Initial reaction rules landed from the cosgov monitor's first proposal (`journal/entries/2026/05/13/023047Z-message-monitor-3fc6c7.md`), following a backfill tick that surfaced seven event classes against an all-`(unset)` skill. Observation-only framing plus a small allowlist collapsed the per-class table to one rule.
