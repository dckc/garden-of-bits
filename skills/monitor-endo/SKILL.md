---
created: 2026-05-12
updated: 2026-05-13
author: gardener, monitor, liaison
---


# Skill: monitor-endo

> **DORMANT as of 2026-05-13.** This skill is not currently active. The `endojs/endo` standing monitor was collected per the monitoring safety constraint in `roles/COMMON.md` § Monitoring safety constraint (mirrored in `CLAUDE.md`): repositories whose comments and pull requests are not gated against untrusted contributors are not safe to monitor, because daemon log lines and event bodies enter the LLM's context. `endojs/endo` does not currently meet that bar. The precipitating dispatch is at [`journal/entries/2026/05/13/053822Z-dispatch-liaison-44e029.md`](../../../journal/entries/2026/05/13/053822Z-dispatch-liaison-44e029.md). The rules below are preserved verbatim for the record in case the constraint reverses; re-enabling this monitor requires explicit maintainer authorization recorded in a journal `message` entry, after which the role-author re-adds the row to `roles/steward/AGENT.md` § Standing monitors, restores the active mapping in `roles/monitor/AGENT.md`, and removes this banner.

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

### Senior contributors (erights et al.)

The endo project README's *Authority structure* section (`journal/projects/endo/README.md` § Authority structure on the `journal` branch) names erights as a senior contributor whose authority meets or exceeds kriskowal's on a defined topic set. The monitor surfaces accordingly:

- A `PullRequestReviewEvent`, `PullRequestReviewCommentEvent`, or `IssueCommentEvent` from `erights` (login matches the GitHub account, verified by `gh pr view` if ambiguous) on a **topic-matching PR** is `surface-bulletin` plus an `escalate-message` to liaison. Do not auto-dispatch a fixer; that remains a kriskowal-directive privilege per `roles/COMMON.md` § External-repo etiquette on the `main` branch.
- On a PR that is **not** topic-matching, an erights event downgrades to the row that would otherwise apply (typically `silent` for review events on PRs the garden does not have a worktree for).
- The rule defers to the project README's *Authority structure* section for the canonical topic list and the practical-rule framing; do not duplicate the list here.

**Topic-match heuristic (keyword-first with file-path fallback):**

1. **Keyword check (cheap, daemon-payload-friendly).** On wake, look at the PR title (for `PullRequestEvent`-derived rows the daemon line carries it; otherwise `gh pr view <N> --json title,labels`). The PR is topic-matching if the title or any label contains any of: `pass-style`, `ses`, `hardened`, `harden`, `marshal`, `pattern`, `eventual-send`, `captp`, `ocapn`, `capability`. Case-insensitive substring match.
2. **File-path fallback (if keyword check is inconclusive).** Run `gh pr view <N> --json files --jq '.files[].path'`. The PR is topic-matching if any path is under `packages/{pass-style,ses,marshal,patterns,eventual-send,captp,hex}/`. (The `hex` package is included because it is a captp / pass-style helper.)
3. **Result.** Topic-matching if either step matches; otherwise not.

The keyword step is fast and works from the daemon-line payload alone; the file-path step is the safety net for PRs whose title is generic (a refactor, a typo fix) but whose diff touches a topic package. If a real event reveals the heuristic is wrong (false positive or false negative), capture the fix in the *Notes from the field* row below.

## Notes from the field

- 2026-05-13 — Initial reaction rules landed from the endo monitor's first proposal (`journal/entries/2026/05/13/023003Z-message-monitor-bbcc25.md`), following three ticks that surfaced every event class with the table all-`(unset)`. Active-participation framing (sister-inverse to cosgov's observation-only) plus per-actor heuristics (boatman head-SHA match, fixer-push timing window) replaced the open-ended unset rows.
