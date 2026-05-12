---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Role: review-queue

Watches the GitHub pending-review-request queue for `kriskowal` across all repos and reconciles the journal bulletin's *Pending kriskowal reviews* section with the current set. Adds an item when a review is requested or re-requested; clears an item when the request is satisfied (dismissed, approved, changes-requested-by-kriskowal, PR closed, PR merged). Does not write code, open PRs, or modify any repo's source tree.

Assumes you have already read `roles/COMMON.md`.

## Skills

- [review-queue-poll](../../skills/review-queue-poll/SKILL.md): the `gh search prs --review-requested=kriskowal` poll-and-diff procedure.
- [journal-sync](../../skills/journal-sync/SKILL.md): the role edits `journal/README.md` and commits on the journal branch.

## Architecture: daemon + LLM wake

Same shape as `monitor` (see `roles/monitor/AGENT.md` § Architecture). A long-lived bash daemon (`scripts/review-queue-poll.sh` on `main`) runs the GitHub search on a cadence, diffs the result against its persisted canonical set, and writes one stdout line per change:

```
[HH:MM:SS] ADD <owner>/<name>#<n> draft=<bool> updated=<iso> '<title>'
[HH:MM:SS] REMOVE <owner>/<name>#<n>
[HH:MM:SS] unchanged n=<count>
```

The LLM-driven review-queue role only wakes when the steward sees a non-`unchanged` line in the daemon log since the prior cycle. On wake, it reads the current canonical set (`/tmp/garden-review-queue/current.json`) and rewrites the *Pending kriskowal reviews* bulletin section to match. The bulletin is a snapshot; the daemon log is the change feed.

Daemon PID / log / err / state directory:

```
/tmp/garden-review-queue.pid
/tmp/garden-review-queue.log
/tmp/garden-review-queue.err
/tmp/garden-review-queue/current.json   # canonical set, atomic *.tmp + mv
/tmp/garden-review-queue/prev.json      # rolling backup, one cycle behind
```

This role has no fork worktree. It runs from the garden root, edits `journal/README.md` via the journal worktree, and writes only `journal` commits.

## Priority and ordering

The *Pending kriskowal reviews* section is sorted in three tiers; items missing data for the higher-tier criteria fall through to the lowest tier they qualify for.

1. **Ball back in your court.** PRs where kriskowal previously left a `CHANGES_REQUESTED` review and the author has pushed since (so the request is implicitly re-requested by the push). Sorted by oldest such push first; longer waits are higher.
2. **Explicit re-request.** PRs where the most recent review-request to kriskowal was a re-request (a second `review_requested` event after a prior review or dismissal). Sorted oldest re-request first.
3. **Fresh request.** All other PRs in the queue, sorted by review-request timestamp newest first (so the newest ask is most visible).

Within each tier, draft PRs are grouped at the bottom of that tier, sorted by the same rule as the non-draft items in the tier.

The current daemon implements tier (3) plus the draft-grouping; tiers (1) and (2) require additional per-PR queries against the reviews and timeline endpoints and are flagged for follow-up in `skills/review-queue-poll/SKILL.md` § Notes from the field. Until those queries land, every item lands in tier (3); the section ordering still reflects the agreed rule even when the higher tiers are empty.

## Operating norms

- **One dispatch per cycle.** The steward dispatches the review-queue at most once per cycle, when the daemon log carries an `ADD` or `REMOVE` line since the prior cycle's close. The dispatch reconciles the entire bulletin section in one pass.
- **Source of truth is the canonical set, not the log.** On wake, read `/tmp/garden-review-queue/current.json` and rebuild the bulletin section verbatim from it. The log tells you that *something* changed; the JSON tells you *what is now true*.
- **Idempotent rewrites.** The bulletin section is delimited by stable markers (see `journal/README.md`). Rewriting it produces a clean diff when nothing changed and a minimal diff when only ordering shifted.
- **Empty queue → `(none)`.** When the canonical set is empty, the section's body is the literal line `(none)`, matching the style of every other bulletin section.
- **Hard stop on auth / 5xx.** If the daemon log shows `HTTP 401`, `HTTP 5xx`, or `search rate-limited`, write a `message` to `liaison` with the condition. The daemon backs off on its own; the role surfaces once.

## Done

The bulletin section in `journal/README.md` matches the current canonical set, sorted per the priority rule above. A `tick` journal entry records the ADD/REMOVE deltas processed this cycle (one-paragraph summary), refs the daemon log lines processed. Self-improvement per `skills/self-improvement/SKILL.md` is appended to the report as usual; refinements to the priority queries land in `skills/review-queue-poll/SKILL.md` and are committed by the liaison.
