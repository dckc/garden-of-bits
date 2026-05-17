---
created: 2026-05-17
updated: 2026-05-17
author: gardener
---

# Skill: monitor-dctinybrain-jesc24

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `dctinybrain/jesc24`. The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react.

## Project

- Slug: `jesc24`
- Upstream: `dctinybrain/jesc24` (https://github.com/dctinybrain/jesc24)
- Default branch: `main`
- Daemon cadence: 60s

## Posture

jesc24 is a repo the garden **actively contributes to** via the PR-creation-flow pipeline. Self-hosted bot at `dctinybrain/jesc24`; the bot authors active PRs directly. The monitor's job here is to distinguish garden-originated activity (silent; already tracked elsewhere) from upstream activity that needs surfacing or routing to the bound role on an active worktree.

## Reaction modes

The per-class rows below use a four-mode vocabulary:

- `silent` — daemon logs it; no journal entry.
- `terse-tick` — one `tick` entry; no liaison action.
- `surface-bulletin` — `tick` entry plus an entry on `journal/README.md` under the relevant section.
- `escalate-message` — `message` to liaison or a more specific role.

## Reactions per event class

- `PushEvent` — three sub-cases:
  - push to `main`: `silent`, record only (already covered by the adjacent merge `PullRequestEvent`).
  - push to a topic branch that has an open PR: `silent`; the PR-side `synchronize` event carries the same signal.
  - push to a topic branch with no open PR (a non-bot push): `terse-tick`, no liaison action. Escalate to `escalate-message` only if the same branch accumulates more than 3 pushes in 10 minutes without ever opening a PR, which suggests a contributor stuck on local iteration.
- `PullRequestEvent` — route by action and actor:
  - `opened` by a non-garden actor: `surface-bulletin` under "New PRs to triage".
  - `opened` by the garden's bot (heuristic: head SHA matches a recent bot dispatch's reported HEAD, or the dispatch root for this monitor cycle pre-asserts it): `silent`, already tracked.
  - `closed (merged=true)`: `terse-tick`; if the PR is one this garden has a worktree for, append a "merged upstream" note to the worktree index entry.
  - `closed (merged=false)`: `terse-tick`; if this garden authored it, `escalate-message` to liaison.
  - `reopened`, `edited`: `silent`.
  - `synchronize`: `silent` unless the PR is bound to an active garden worktree, in which case the bound role (fixer / weaver / shepherd) should re-check CI.
- `PullRequestReviewEvent` (submitted, edited, dismissed):
  - On a PR the garden has a worktree for:
    - Reviewer is `dckc` and state is `changes_requested` or `commented`: `escalate-message` to steward (the steward needs to dispatch the fixer).
    - Reviewer is `dckc` and state is `approved`: `surface-bulletin`.
    - Any other reviewer: `surface-bulletin`.
  - On a PR the garden does **not** have a worktree for: `silent`.
- `PullRequestReviewCommentEvent` — `silent` on its own; only surface as part of the parent `PullRequestReviewEvent`'s tick.
- `IssuesEvent` — route by action:
  - `opened`: `terse-tick`, `surface-bulletin` under "New issues".
  - `assigned` / `labeled`: `silent`.
  - `closed`: `silent` unless this garden authored the issue.
  - `reopened`, `edited`: `silent`.
- `IssueCommentEvent` — route by author:
  - From `dckc` on a PR this garden has a worktree for: `escalate-message` to steward (likely needs fixer routing).
  - From the garden's own bot (heuristic: comment within a few minutes of a garden-originated push to the same PR): `silent`.
  - From any other source: `silent`.
- `ReleaseEvent` — `terse-tick`, `surface-bulletin` with the release tag. Low-frequency, signals an upstream cut.
- `CreateEvent` / `DeleteEvent` (branches/tags):
  - branch created by the garden's bot: `silent`.
  - tag created (release): see `ReleaseEvent`.
  - branch deleted (dependabot cleanup, post-merge): `silent`.
- `ForkEvent`, `WatchEvent`, `MemberEvent` — `silent`.
- Other event classes — `escalate-message` to liaison with the raw type and a one-line context; do not silently drop.

## Notes from the field

- 2026-05-17 — Initial creation modeled from monitor-endo. Maintainer changed from kriskowal to dckc; escalation rules added for fixer dispatch on PullRequestReviewEvent (changes_requested / commented from dckc) and IssueCommentEvent (from dckc on a worktree PR).
