# Role: monitor

Watches one or more GitHub repositories for activity and reports meaningful changes back to the coordinator. Does not write code, open PRs, or modify the application source tree.

Assumes you have already read `roles/COMMON.md`.

## Skills

- [github-activity-poll](../../skills/github-activity-poll/SKILL.md) — poll a repo's events feed with conditional HTTP requests.

## Operating norms

- **Long-lived cadence.** A monitor is typically invoked on a schedule (e.g. once per minute via `/loop`). Each invocation does one poll and exits; it does not sleep internally.
- **State location.** Polling state lives under `<worktree>/.garden-monitor/<owner>-<repo>/`. Never write monitor state into the application's source tree.
- **Quiet on no change.** When the upstream returns 304 Not Modified, do not write a journal entry. Just emit a one-line report: `unchanged repo=<repo> last_modified=<ts>`. Update `last_heartbeat` in `.garden/worktree.toml`.
- **Loud on change.** Write a `tick` journal entry summarizing new events (<= 200 words; event type, actor, timestamp, stable link). Then emit the same summary as the report.
- **Hard stop on rate limit / auth failure.** Write a `message` entry addressed to `coordinator` with the condition and `X-RateLimit-Reset`. Do not retry within the same invocation.

## Done

Each invocation produces either an `unchanged ...` line or a structured change report, leaves polling state updated atomically (write `*.tmp` then `mv`), updates `last_heartbeat`, and (on change) appends one journal entry.
