---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: autonomous-loop-pacing

Choose the next `ScheduleWakeup` delay (or the cron / `/loop` interval) for an agent that runs in an autonomous loop. The skill exists because the wrong delay either burns prompt cache for nothing or starves real work.

Adopted from `references/endo-but-for-bots/skills/autonomous-loop-pacing.md`; adjusted for this garden's idiom (the `<<autonomous-loop-dynamic>>` sentinel, the steward's per-cycle procedure, and the per-dispatch worktree triple).

## When to use

`<<autonomous-loop-dynamic>>` invocations let the steward continue working between maintainer messages, with the steward deciding when to wake up. Use it whenever the steward has background tasks or external events to watch (monitor daemons, review-queue daemon, scheduled engagements) and the maintainer is not in the loop.

Cron and `/loop` triggers have the same shape from the steward's point of view; the cadence below applies regardless of which substrate fires the next tick. `CronCreate` is session-independent and is appropriate for genuinely calendar-keyed sweeps; `ScheduleWakeup` preserves the session's working tree and in-flight git state and is appropriate for per-cycle pacing.

## How

After a checkpoint of useful work, schedule the next tick:

```
ScheduleWakeup({
  delaySeconds: <60..3600>,
  reason: "<one-sentence explanation>",
  prompt: "<<autonomous-loop-dynamic>>",
})
```

To **stop** the loop, just don't schedule another wakeup. The steward's role file requires "always schedule a next fire unless explicitly told to stop", so stopping is rare; idle delays should grow rather than the loop ending.

## Choosing delaySeconds (cache-window rules)

The Anthropic prompt cache has a 5-minute TTL. Sleeping past 300 seconds means the next wake-up reads the full conversation context uncached, which is slower and more expensive. The natural breakpoints:

- **Under 5 minutes (60s to 270s)**: cache stays warm. Use for **active polling**: a CI matrix that's about to settle, a subagent the steward expects back within minutes, a monitor daemon reporting NEW lines from a maintainer the steward needs to react to quickly.
- **5 minutes (300s)** is the worst choice: cache miss without amortizing the wait. Either drop to 270s (stay warm) or commit to 1200s+ (one cache miss buys a much longer wait). Do not pick 300s.
- **20 to 30 minutes (1200s to 1800s)**: **active mode** without a tighter trigger. Pays one cache miss per hour, not twelve. This is the steward's default active cadence when one of the active-mode triggers below fires.
- **1 hour (3600s)**: **idle mode**. Genuinely idle waits where nothing is expected to change between ticks.

## Active vs idle mode

The steward picks **active mode** (delaySeconds ≤ 1800) when any of these is true at cycle close:

- A subagent dispatched this cycle (or a prior cycle) has not returned yet.
- The CI rollup on any in-flight PR is still propagating (a job is `IN_PROGRESS` or `QUEUED`).
- The maintainer (kriskowal) touched any open PR or issue within the look-back window of the recent skim (default 24h).
- A PR is currently `awaiting maintainer re-review`.
- The merge queue (the conductor's drain queue) is non-empty.
- A monitor daemon's log has unread `NEW` lines since the prior cycle, or the review-queue daemon has unread `ADD`/`REMOVE` lines.
- The bulletin's *Awaits maintainer decision* section has items the maintainer has not yet acted on.

Otherwise the steward picks **idle mode** (between 1800s and 3600s). Bias shorter (1800s) when contributor engagement is plausible, longer (3600s) when the project is quiet.

**Hard upper bound: 3600s (the `ScheduleWakeup` runtime cap).** Earlier garden generations ran with a 9-hour cap via a different substrate; this garden's cap is whatever `ScheduleWakeup` allows. If a genuinely longer wait is needed (e.g. a Monday-morning sweep that fires Sunday afternoon), schedule the closest substrate-allowed wakeup and let that tick decide whether to fire the engagement or reschedule.

## Always schedule; the loop is indefinite

The steward does not self-terminate. A cycle that produces no dispatches is not a stop signal; the next cycle still fires per the cadence rules. The maintainer kills the loop by sending a `TaskStop`, by killing the cron job, or by saying so. Otherwise: always schedule.

## Pitfalls

- "Idle 5-minute poll" is the most common mis-pick. Resist it. Either 270s (you're actively expecting movement) or 1200s+ (you're not).
- Don't keep an active-mode loop running indefinitely. When the active-mode triggers all clear, drop to idle. The cache-miss cost is one tick of slowness; the alternative (staying warm forever) is burning compute on nothing.
- `Bash` calls during a wakeup count against the same context budget as maintainer-driven calls. Keep ticks short; the per-cycle procedure exists to bound the work.
- Cron and ScheduleWakeup are not mutually exclusive but you usually want one substrate per loop. Picking both creates two source-of-truth questions (which fired this tick? which cadence applies?).

## Notes from the field

- _2026-05-13_: adopted from `references/endo-but-for-bots/skills/autonomous-loop-pacing.md`. The reference assumed a 9-hour cap via a non-`ScheduleWakeup` substrate; this garden's cap is `ScheduleWakeup`'s 3600s ceiling. The "What to do during a tick" section in the reference was trimmed because this garden's steward already has a complete per-cycle procedure in `roles/steward/AGENT.md` § Per-cycle procedure; the cadence skill should not duplicate it.
