---
created: 2026-05-12
updated: 2026-05-13
author: monitor, liaison
---

# Skill: monitor-endo

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `endojs/endo`. The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react.

## Project

- Slug: `endo`
- Upstream: `endojs/endo` (https://github.com/endojs/endo)
- Default branch: `master`
- Daemon cadence: 60s (the `/events` endpoint is server-cached for ~60s; faster polling does not surface events sooner).

## Posture

Endo is a repo the garden **actively contributes to** via the per-PR roles (boatman, fixer, weaver, shepherd, conductor). Sister to cosgov's observation-only posture, but inverted: the monitor's job here is to distinguish garden-originated activity (silent; already tracked elsewhere) from upstream activity that needs surfacing or routing to the bound role on an active worktree.

## Reaction modes

The per-class rows below use a four-mode vocabulary:

- `silent` — daemon logs it; no journal entry.
- `terse-tick` — one `tick` entry; no liaison action.
- `surface-bulletin` — `tick` entry plus an entry on `journal/README.md` under the relevant section.
- `escalate-message` — `message` to liaison or a more specific role.

## Reactions per event class

- `PushEvent` — three sub-cases:
  - push to `master`: `silent`, record only (already covered by the adjacent merge `PullRequestEvent`).
  - push to a topic branch that has an open PR: `silent`; the PR-side `synchronize` event carries the same signal.
  - push to a topic branch with no open PR (the `boneskull/*` case): `terse-tick`, no liaison action. Escalate to `escalate-message` only if the same branch accumulates more than 3 pushes in 10 minutes without ever opening a PR, which suggests a contributor stuck on local iteration.
- `PullRequestEvent` — route by action and actor:
  - `opened` by a non-garden actor: `surface-bulletin` under "New PRs to triage".
  - `opened` by the garden's boatman (heuristic: head SHA matches a recent boatman dispatch's reported HEAD, or the dispatch root for this monitor cycle pre-asserts it): `silent`, already tracked.
  - `closed (merged=true)`: `terse-tick`; if the PR is one this garden has a worktree for, append a "merged upstream" note to the worktree index entry.
  - `closed (merged=false)`: `terse-tick`; if this garden authored it, `escalate-message` to liaison.
  - `reopened`, `edited`: `silent`.
  - `synchronize`: `silent` unless the PR is bound to an active garden worktree, in which case the bound role (fixer / weaver / shepherd) should re-check CI.
- `PullRequestReviewEvent` (submitted, edited, dismissed) — `surface-bulletin` for every maintainer review (`state: approved | changes_requested | commented`) on a PR this garden has a worktree for; otherwise `silent`.
- `PullRequestReviewCommentEvent` — `silent` on its own; only surface as part of the parent `PullRequestReviewEvent`'s tick.
- `IssuesEvent` — route by action:
  - `opened`: `terse-tick`, `surface-bulletin` under "New issues".
  - `assigned` / `labeled`: `silent`.
  - `closed`: `silent` unless this garden authored the issue.
  - `reopened`, `edited`: `silent`.
- `IssueCommentEvent` — route by author:
  - From a maintainer on a PR this garden has a worktree for: `surface-bulletin`, likely needs fixer/weaver routing.
  - From the garden's own boatman / fixer (heuristic: comment within a few minutes of a garden-originated push to the same PR): `silent`.
  - From any other source: `silent`.
- `ReleaseEvent` — `terse-tick`, `surface-bulletin` with the release tag. Low-frequency, signals an upstream cut.
- `CreateEvent` / `DeleteEvent` (branches/tags):
  - branch created by the garden's boatman: `silent`.
  - tag created (release): see `ReleaseEvent`.
  - branch deleted (dependabot cleanup, post-merge): `silent`.
- `ForkEvent`, `WatchEvent`, `MemberEvent` — `silent`.
- Other event classes — `escalate-message` to liaison with the raw type and a one-line context; do not silently drop.

## Notes from the field

- 2026-05-13 — Initial reaction rules landed from the endo monitor's first proposal (`journal/entries/2026/05/13/023003Z-message-monitor-bbcc25.md`), following three ticks that surfaced every event class with the table all-`(unset)`. Active-participation framing (sister-inverse to cosgov's observation-only) plus per-actor heuristics (boatman head-SHA match, fixer-push timing window) replaced the open-ended unset rows.
