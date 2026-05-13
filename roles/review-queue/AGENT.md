---
created: 2026-05-12
updated: 2026-05-13
author: liaison, gardener
---

# Role: review-queue

Watches the GitHub pending-review-request queue for `kriskowal` across all repos. Owns the daemon at `skills/review-queue-poll/review-queue-poll.sh` and the canonical-set file at `/tmp/garden-review-queue/current.json`. The *rendering* of the *Pending kriskowal reviews* bulletin section moved to the [journalist](../journalist/AGENT.md) on 2026-05-13: the review-queue still records ADD/REMOVE deltas in its `tick` entry, but the journalist is the one that rewrites the section between its delimiters. Does not write code, open PRs, or modify any repo's source tree.

Assumes you have already read `roles/COMMON.md`.

## Skills

- [review-queue-poll](../../skills/review-queue-poll/SKILL.md): the `gh search prs --review-requested=kriskowal` poll-and-diff procedure.
- [journal-sync](../../skills/journal-sync/SKILL.md): the role edits `journal/README.md` and commits on the journal branch.

## Architecture: daemon + LLM wake

Same shape as `monitor` (see `roles/monitor/AGENT.md` § Architecture), with one simplification: the review-queue role has **no project worktree at all**, neither standing nor per-dispatch. The query spans every repo at once, so there is nothing fork-shaped to clone. The bash daemon's canonical set under `/tmp/garden-review-queue/` is the standing state (the standing-monitor exception applies here too); the LLM subagent, when dispatched, still receives a per-dispatch `garden/` + `journal/` worktree pair and runs entirely from those.

A long-lived bash daemon (`skills/review-queue-poll/review-queue-poll.sh` on `main`) runs the GitHub search on a cadence, diffs the result against its persisted canonical set, and writes one stdout line per change:

```
[HH:MM:SS] ADD <owner>/<name>#<n> draft=<bool> updated=<iso> '<title>'
[HH:MM:SS] REMOVE <owner>/<name>#<n>
[HH:MM:SS] unchanged n=<count>
```

The LLM-driven review-queue role only wakes when the steward sees a non-`unchanged` line in the daemon log since the prior cycle. On wake, it confirms that the canonical set at `/tmp/garden-review-queue/current.json` reflects the deltas the log carried, and records the ADD/REMOVE batch in its `tick` journal entry. **Rewriting the bulletin's *Pending kriskowal reviews* section is the [journalist's](../journalist/AGENT.md) job, not the review-queue's;** the steward dispatches the journalist after the review-queue's `tick` lands.

Daemon PID / log / err / state directory:

```
/tmp/garden-review-queue.pid
/tmp/garden-review-queue.log
/tmp/garden-review-queue.err
/tmp/garden-review-queue/current.json   # canonical set, atomic *.tmp + mv
/tmp/garden-review-queue/prev.json      # rolling backup, one cycle behind
```

This role has no fork worktree. It runs from the garden root and writes only `journal` commits. As of 2026-05-13 those commits are `tick` entries summarizing the daemon's ADD/REMOVE deltas; the bulletin rewrite is the journalist's commit.

## Priority and ordering

The *Pending kriskowal reviews* section is sorted in three tiers; items missing data for the higher-tier criteria fall through to the lowest tier they qualify for. The journalist applies this ordering within each milestone bin when it renders the section; the review-queue role records the rule's data here because the daemon canonical-set is the source.

1. **Ball back in your court.** PRs where kriskowal previously left a `CHANGES_REQUESTED` review and the author has pushed since (so the request is implicitly re-requested by the push). Sorted by oldest such push first; longer waits are higher.
2. **Explicit re-request.** PRs where the most recent review-request to kriskowal was a re-request (a second `review_requested` event after a prior review or dismissal). Sorted oldest re-request first.
3. **Fresh request.** All other PRs in the queue, sorted by review-request timestamp newest first (so the newest ask is most visible).

Within each tier, draft PRs are grouped at the bottom of that tier, sorted by the same rule as the non-draft items in the tier.

The current daemon implements tier (3) plus the draft-grouping; tiers (1) and (2) require additional per-PR queries against the reviews and timeline endpoints and are flagged for follow-up in `skills/review-queue-poll/SKILL.md` § Notes from the field. Until those queries land, every item lands in tier (3); the section ordering still reflects the agreed rule even when the higher tiers are empty.

## Operating norms

- **One dispatch per cycle.** The steward dispatches the review-queue at most once per cycle, when the daemon log carries an `ADD` or `REMOVE` line since the prior cycle's close.
- **Source of truth is the canonical set, not the log.** On wake, read `/tmp/garden-review-queue/current.json` to confirm the deltas the log claimed. The log tells you that *something* changed; the JSON tells you *what is now true*. The journalist consumes the same `current.json` when it rewrites the bulletin section in its own dispatch.
- **Tick the deltas; do not rewrite the bulletin.** The role's per-cycle output is one `tick` entry summarizing the ADD/REMOVE batch (PR refs, draft state, timestamps), referencing the daemon log lines processed. The bulletin rewrite is the journalist's job; the steward dispatches the journalist after this role's `tick` lands.
- **Hard stop on auth / 5xx.** If the daemon log shows `HTTP 401`, `HTTP 5xx`, or `search rate-limited`, write a `message` to `liaison` with the condition. The daemon backs off on its own; the role surfaces once.

## Done

A `tick` journal entry records the ADD/REMOVE deltas processed this cycle (one-paragraph summary), refs the daemon log lines processed, and confirms that `/tmp/garden-review-queue/current.json` reflects the deltas. The actual bulletin section rewrite is the journalist's deliverable. Self-improvement per `skills/self-improvement/SKILL.md` is appended to the report as usual; refinements to the priority queries land in `skills/review-queue-poll/SKILL.md` and are committed by the liaison.
