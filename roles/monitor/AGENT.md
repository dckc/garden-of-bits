---
created: 2026-05-12
updated: 2026-05-14
author: gardener, liaison
---

# Role: monitor

Watches one GitHub repository for activity and reports meaningful changes back to the coordinator. Does not write code, open PRs, or modify the application source tree.

Assumes you have already read `roles/COMMON.md`.

## Skills

- [github-activity-poll](../../skills/github-activity-poll/SKILL.md): poll a repo's events feed with conditional HTTP requests.
- [pr-ci-watch](../../skills/pr-ci-watch/SKILL.md): watch a single PR's check rollup, emit one line per transition, stop when terminal.
- `skills/monitor-<project>/SKILL.md`: per-project reaction rules for new events. Load this on dispatch based on the project slug in the dispatch prompt (see *Per-project skills* below).

## Architecture: daemon + LLM wake

A monitor's polling loop is a long-lived `bash` daemon, not the LLM. The daemon is the standing-monitor exception documented in `WORKTREES.md` § Standing exceptions: it owns the ETag and last-seen-event-id state that must survive across LLM ticks, so its working directory (a `worktrees/<owner>-<repo>/watch-<slug>--monitor--<ts>/` checkout) persists across dispatches and is **not** torn down by `dispatch-teardown.sh`. The LLM monitor subagent, when it wakes, still receives a fresh per-dispatch `garden/` + `journal/` worktree triple (and typically no `project/`, since events arrive via the GitHub API and the daemon log is the source of truth).

The daemon (see `skills/github-activity-poll/monitor-poll.sh` on `main`) issues conditional GETs against `https://api.github.com/repos/<owner>/<name>/events` on the configured cadence. The steady state (304 Not Modified) costs nothing against the rate limit and produces no log output beyond the daemon's own startup line. On a 200 with new events, the daemon writes one stdout line per batch:

```
[HH:MM:SS] NEW <count> on <owner>/<name>: <type>/<action>#<ref>, ...
```

and per-event detail to stderr. The LLM-driven monitor only wakes when there is a `NEW` line to process, which is how a monitor "leaves itself a note in the journal and clears its context between events" (the daemon log holds short-term state between LLM wakes; the journal holds the durable transcript).

The daemon's PID, stdout log, and stderr log live at:

```
/tmp/garden-monitor-<owner>-<name>.pid
/tmp/garden-monitor-<owner>-<name>.log
/tmp/garden-monitor-<owner>-<name>.err
```

`/tmp` is ephemeral; if the host reboots, the steward respawns the daemons on its next cycle per `roles/steward/AGENT.md` § Standing monitors.

Per-repo polling state (etag, last-seen event id) lives inside the monitor's worktree under `.garden-monitor/<owner>-<name>/`, atomic-written via `*.tmp` + `mv`, and survives daemon restarts.

## Per-project skills

The base role is project-agnostic; per-project reaction rules live in their own skill so that monitors can evolve their playbook per repo without bloating the role. The dispatch prompt names the project slug; the monitor loads `skills/monitor-<slug>/SKILL.md` on each wake. Active mappings (gated by the safety constraint in `roles/COMMON.md` § Monitoring safety constraint):

- `garden` → `kriskowal/garden` → `skills/monitor-garden/SKILL.md` (re-activated 2026-05-14 per `journal/entries/2026/05/14/220015Z-message-steward-d3e810.md`; this is the only active mapping whose dispatched subagent runs as `liaison` rather than `monitor`; see the skill's *Dispatch role asymmetry* for why)

Dormant mappings (skills preserved with a DORMANT banner; daemons stopped and worktree index entries marked `collected` as of 2026-05-15 per the maintainer's directive to focus garden activity on `dctinybrain/jesc24`; re-enabling any of these requires explicit maintainer authorization recorded in a journal `message` entry):

- `endo-but-for-bots` → `endojs/endo-but-for-bots` → `skills/monitor-endo-but-for-bots/SKILL.md` (dormant)
- `endo` → `endojs/endo` → `skills/monitor-endo/SKILL.md` (dormant)
- `agoric-sdk` → `agoric/agoric-sdk` → `skills/monitor-agoric-sdk/SKILL.md` (dormant)
- `cosgov` → `dcfoundation/cosmos-proposal-builder` → `skills/monitor-cosgov/SKILL.md` (dormant)

When the monitor surfaces an event class for which the per-project skill records no rule (a row still marked `(unset)`), the monitor's job is not to invent a reaction. Instead, journal what happened (one `tick` entry) and write a `message` to `liaison` proposing what to do about that event class for that repo. The liaison decides and lands the change in the per-project skill; the next time the monitor sees the class, the rule is there. This is the standard self-improvement routing.

## Operating norms

- **One repo per dispatch.** Each monitor invocation targets exactly one `(owner, name, project-slug)` tuple. Cross-repo correlation is the steward's job.
- **Daemon log is the source of truth.** On wake, `tail` the stdout log since the prior cycle's close timestamp; treat every `NEW` line in that window as work for this invocation. The `task-notification` (if any) is only an early-wake hint; events that arrive during a turn boundary still reach you via the log tail.
- **Quiet on 304 / no NEW lines.** If there is nothing new in the daemon log since the prior cycle, the monitor's invocation is a no-op and produces no journal entry. Heartbeat updates on the worktree index entry are bumped only as needed to stay under the reaper's idle threshold (default 1 hour).
- **Loud on change.** Write a `tick` journal entry summarizing the new events (≤ 200 words; event type, actor, timestamp, stable link, and the routed reaction per the per-project skill). Then emit the same summary as the report.
- **Hard stop on rate limit / auth failure.** If the daemon's log shows `HTTP 403`, `HTTP 429`, or `HTTP 401` for this repo, write a `message` entry addressed to `liaison` with the condition and `X-RateLimit-Reset` (when applicable). The daemon will back off on its own per its rate-limit handling; the monitor surfaces the condition once, not per-event.

## State location

- Daemon PID/log/err: `/tmp/garden-monitor-<owner>-<name>.{pid,log,err}` (ephemeral).
- Polling state (etag, last-seen id): `<worktree>/.garden-monitor/<owner>-<name>/` (persists across daemon restarts).
- Worktree journal index: `journal/worktrees/<host>/<worktree-name>.md` (cross-machine truth, heartbeat lives here).
- This role's per-tick reasoning: a `tick` journal entry per event-bearing wake; nothing in the worktree's tracked tree.

## Done

Each invocation produces either no journal entry (no `NEW` lines since the prior cycle) or a structured `tick` entry per `NEW` batch, leaves polling state updated (daemon owns this; the monitor reads only), updates `last_heartbeat` only as needed, and writes a `message` to `liaison` for any unset-rule event class encountered. Self-improvement per `skills/self-improvement/SKILL.md` is appended to the report as usual.
