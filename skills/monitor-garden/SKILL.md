---
created: 2026-05-13
updated: 2026-05-13
author: liaison, gardener
---

# Skill: monitor-garden

Per-event-class reaction rules for the [monitor](../../roles/monitor/AGENT.md) when dispatched against `kriskowal/garden`. The base role and its polling discipline live in `roles/monitor/AGENT.md` and `skills/github-activity-poll/SKILL.md`; this skill is consulted on each `NEW`-line wake to decide whether and how to react. The garden is **this repo**, so the skill is issue-focused: it watches for external contributors or the maintainer opening, reopening, or commenting on issues, and surfaces those events as a liaison-proxy dispatch so the in-session liaison can decide how to react.

## Project

- Slug: `garden`
- Upstream: `kriskowal/garden` (https://github.com/kriskowal/garden)
- Default branch: `main`
- Daemon cadence: 60s.

## Posture

The garden is **this repo**. The maintainer and the in-session liaison drive non-issue activity directly: pushes to `main` and `journal` are routine, and pull requests are not used against this repo (per `CLAUDE.md` § Conventions § No PR workflows for the garden's own repo). The monitor's job is therefore narrow: detect issue activity from external contributors or the maintainer, surface it as a liaison-proxy dispatch, and let the liaison decide how to react. Most non-issue event classes are silent because the maintainer and the liaison originate them.

## Dispatch role asymmetry

The steward dispatches a `liaison` subagent on a `NEW` line from this daemon, not a `monitor` subagent. The dispatch shape is the same as any other monitor wake (a per-dispatch worktree triple, no project worktree, the daemon's log tail as the event source) but the role is `liaison` and the purpose slug is `react-to-garden-issue-<N>` rather than `react-to-<repo>-events`. Concretely the steward's `Dispatch` step calls `scripts/dispatch-prepare.sh liaison react-to-garden-issue-<N>` and passes the resulting dispatch root to `Agent` with the liaison's standing instructions.

The reason for the asymmetry: issue activity on `kriskowal/garden` is meta-evolution work, and the liaison is the only role with the authority to act on it (revise roles or skills, edit top-level docs, originate cross-repo authorizations, decide whether to dispatch a gardener). A monitor subagent would have to immediately escalate to a liaison-addressed `message` anyway; routing the dispatch straight to the liaison collapses that round trip and keeps the meta-evolution decision in the role that holds it. This skill is sibling-but-distinct from the other four standing-monitor reaction skills (`monitor-endo`, `monitor-endo-but-for-bots`, `monitor-agoric-sdk`, `monitor-cosgov`), all of which dispatch the `monitor` role on a `NEW` line.

## Reactions per event class

- `IssuesEvent/opened` — **loud**. Surface to a liaison-proxy dispatch with the issue number, title, opener, and a one-line body excerpt. The liaison decides whether the issue warrants a gardener dispatch (a new role or skill), an inline reply (with maintainer authorization), or no action.
- `IssuesEvent/reopened` — **loud**. Same shape as `opened`. A reopen signals that a previously resolved concern has new context; the liaison reviews.
- `IssuesEvent/closed` — **silent** by default. The closer is typically the maintainer or the liaison itself, and the journal already records the closing dispatch. Surface only as a `terse-tick` if the closer is an external contributor and the issue had liaison-acknowledged work pending.
- `IssuesEvent/edited` — **silent**. Title and body churn is common; if the edit changes routing the next `IssueCommentEvent` carries the signal.
- `IssuesEvent/labeled|unlabeled|assigned|unassigned` — **silent**. The garden does not yet route by label, so label churn is noise; assignment changes are similarly without routing consequence today. Revisit if a labeling convention emerges.
- `IssueCommentEvent/created` — **loud** when the comment is on an open issue; the liaison-proxy dispatch carries the comment author, body excerpt, and issue ref. **Quiet** when the comment is on a closed issue, with one exception: if the maintainer comments on a closed issue and the comment plausibly reopens the thread (a fresh question, a new constraint, a request to revisit), treat it as `loud`. The daemon log line is the only signal; the dispatched liaison reads the full comment and decides.
- `IssueCommentEvent/edited|deleted` — **silent**. Edits to a prior comment are typically polishing; deletions are rare and the next comment in the thread carries the routing signal if any.
- `PullRequestEvent/*`, `PullRequestReviewEvent/*`, `PullRequestReviewCommentEvent/*` — **silent**, but with an escalation. Per the no-PR-workflows convention, PRs against the garden are not expected; if one appears, surface as a `message` to liaison anyway (defensive). The liaison decides whether to close the PR with an explanation, fold the contribution into a direct push to `main`, or accept it as a one-off exception.
- `PushEvent` — **silent**. Pushes to `main` and `journal` are the maintainer's and the liaison's routine output; the steward's standing-monitors discipline does not need them surfaced.
- `CreateEvent`, `DeleteEvent` (branches/tags) — **silent**. Routine. The garden does not run a release cadence (no PR workflows), so branch and tag churn is rare and unremarkable when it happens.
- `ReleaseEvent` — **terse-tick**. The garden does not cut releases under the no-PR-workflows convention, but if one appears it warrants noting; the tick body records the tag and the actor. No liaison-proxy dispatch unless the release indicates a posture change.
- `ForkEvent`, `WatchEvent`, `MemberEvent` — **silent**. External interest in the garden is not actionable from a monitor wake; the liaison cannot meaningfully react to a star or a fork.
- `PublicEvent`, `GollumEvent`, `CommitCommentEvent` — **silent**. The garden does not currently use the wiki, does not toggle visibility, and does not invite commit-level commenting; if any of these fire, the next event class will carry the meaningful signal.
- Other event classes — **escalate-message** to liaison with the raw type and a one-line context; do not silently drop.

## Notes from the field

(append dated entries as reaction rules are learned)

- 2026-05-13 — Initial skill landed by the gardener dispatch at `journal/entries/2026/05/13/045631Z-dispatch-liaison-266ec2.md`. The garden gets its first standing monitor at the same time as this skill, so all per-class rows are first-pass: issue-loud, non-issue-silent, with the liaison-proxy dispatch as the only loud routing. The asymmetric `liaison` dispatch role (the steward dispatches a liaison subagent, not a monitor) is the distinguishing feature among the five standing monitors and is documented in *Dispatch role asymmetry* above.
