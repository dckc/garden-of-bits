---
created: 2026-05-13
updated: 2026-05-13
author: gardener
---

# Skill: scheduling

How roles register future work, where the schedule lives, and how the [timekeeper](../../roles/timekeeper/AGENT.md) consumes it. The schedule tree under `journal/schedule/` is the single source of truth; the timekeeper is its only mutator on the firing side; any role may write a new event file.

## When to use

- A role needs to fire a dispatch at a future wall-clock time (a periodical, a refresh, a maintenance sweep). Write an event file per *Register an event* below.
- The timekeeper is consuming the schedule on a cycle. Walk per *Layout* below; fire per *Firing an event*.
- A maintainer asks for a one-off scheduled action. Same shape; `recurrence: one-shot`.

## Layout

```
journal/schedule/
  README.md                                  # index with abstracts per scheduled event
  <owner-or-garden>/                         # one directory per upstream owner, or `garden/` for garden-internal events
    <UTC-trigger-timestamp>--<short-id>.md   # one file per event
  _fired/
    <owner-or-garden>/
      <UTC-trigger-timestamp>--<short-id>.md # archived after the timekeeper fires the event
```

- `<owner-or-garden>` is the upstream owner slug (e.g. `endojs`, `agoric`), or the literal `garden` for events whose target is the garden itself (a journal-only dispatch, no fork worktree).
- `<UTC-trigger-timestamp>` is `YYYYMMDDTHHMMSSZ` compact form (e.g. `20260513T070000Z`), computed via `next-trigger.sh` (see *The helper script* below).
- `<short-id>` is six hex chars (`openssl rand -hex 3`), the same shape the journal entries use.

Each fired event is atomically moved into `_fired/` with the same relative path; the archive is the history of what fired and when. Recurring events leave a new event file at the next trigger before the prior file is archived.

The `README.md` at the root carries one bullet per pending event (and one bullet per *fired* event, separated): the trigger timestamp, the dispatch role + purpose, and the short id. See `skills/context-library/SKILL.md` for the abstract-at-the-top discipline; the README is a context-tree index.

## Event file shape

```markdown
---
trigger: 2026-05-13T07:00:00Z              # UTC ISO-8601, the instant the event fires
intent: "00:00 America/Los_Angeles"        # human-readable intent the trigger was computed from
recurrence: daily-at-00:00-America/Los_Angeles   # rule shape (see below), or `one-shot`
dispatch:
  role: journalist                         # the role the timekeeper dispatches at trigger time
  purpose: daily-progress-summary          # the purpose-slug for the dispatch root
  arguments:                               # per-dispatch arguments, forwarded into the dispatch prompt
    window: "prior 24 hours"
    output: "journal/periodicals/<YYYY>/<MM>/<DD>.md"
fired: null                                # null until the timekeeper fires; ISO-8601 after
created: 2026-05-13
author: gardener
---

# <one-line title for the event>

<one or two paragraphs describing what the event does, why it exists, and what its dispatch should produce>
```

The body is prose for the next reader (the timekeeper, a maintainer auditing the schedule). The frontmatter is the machine contract.

## Recurrence rule shape

Recurrence is a short kebab-case string. The `next-trigger.sh` script parses it and emits a UTC ISO-8601 timestamp.

Supported shapes:

- `one-shot` (no recurrence; the event fires once and is archived).
- `daily-at-<HH:MM>-<timezone>` (e.g. `daily-at-00:00-America/Los_Angeles`, `daily-at-09:00-UTC`).
- `weekly-on-<weekday>-at-<HH:MM>-<timezone>` (e.g. `weekly-on-monday-at-08:00-UTC`; weekday is lowercase English).
- `hourly-at-<MM>-<timezone>` (e.g. `hourly-at-00-UTC` for the top of each UTC hour).

The timezone is an IANA name (`America/Los_Angeles`, `UTC`, `Europe/Paris`). The script uses Python's `zoneinfo`, which handles DST transitions correctly. Other shapes (`every-N-hours`, `monthly-on-<day>-at-...`) may be added as new use cases arrive; document them here when added.

## The helper script

`skills/scheduling/next-trigger.sh` (this directory) computes the next UTC trigger from a recurrence rule and a reference time.

```sh
skills/scheduling/next-trigger.sh <recurrence-rule> [<reference-iso-8601>]
```

- `<recurrence-rule>`: a shape from *Recurrence rule shape* above.
- `<reference-iso-8601>`: optional reference time (UTC ISO-8601). Defaults to `now` in UTC. The script computes the first occurrence *strictly after* the reference.

Output on stdout: a UTC ISO-8601 timestamp (`2026-05-13T07:00:00Z`) and the compact form (`20260513T070000Z`) on consecutive lines. Stderr is silent on success.

Why a script and not in-prompt arithmetic: DST transitions and weekday math are routine sources of drift bugs. The script is the single correct path; no role computes a timestamp by hand.

## Register an event

Any role may register a future event. The procedure:

1. **Pick the recurrence rule.** Use one of the shapes in *Recurrence rule shape* above, or `one-shot`.
2. **Compute the first trigger.** Run `skills/scheduling/next-trigger.sh <rule>` from the dispatch root. Capture both the ISO-8601 form (for `trigger:` frontmatter) and the compact form (for the filename).
3. **Generate a short id.** `openssl rand -hex 3`.
4. **Write the event file** at `journal/schedule/<owner-or-garden>/<compact-ts>--<short-id>.md` with the frontmatter and body shape from *Event file shape* above. Use the journal-sync skill's standard append procedure.
5. **Update `journal/schedule/README.md`** with one bullet for the new event under *Pending events*: trigger, dispatch role + purpose, short id, one-line abstract.
6. **Commit and push** as part of the calling role's normal journal-sync flow.

The timekeeper is not signaled directly; it will pick up the new event on its next cycle. If the trigger is sooner than the timekeeper's next scheduled wakeup, the timekeeper may fire the event late (by up to one wakeup interval). This is by design; latency budgets are encoded in the timekeeper's cadence, not in cross-role signaling.

## Firing an event (timekeeper)

The timekeeper's per-cycle procedure (`roles/timekeeper/AGENT.md` § Per-cycle procedure) covers the firing flow. Summarized here for cross-reference:

1. Read the event file's frontmatter.
2. Prepare a per-dispatch worktree triple via `skills/dispatch-worktree/dispatch-prepare.sh <role> <purpose>`.
3. Write a `dispatch` journal entry naming the event file and the dispatch root.
4. Invoke `Agent` with a prompt that names `DISPATCH_ROOT`, the event file's path, and the dispatch's arguments.
5. On return, write a `result` journal entry.
6. Tear the dispatch root down via `skills/dispatch-worktree/dispatch-teardown.sh "$DISPATCH_ROOT"`.
7. **Recurrence rollover.**
   - If `recurrence: one-shot`: move the event file to `journal/schedule/_fired/<original-relative-path>` and append a `fired:` field to its frontmatter.
   - Else: run `skills/scheduling/next-trigger.sh <rule> <current-trigger>` to compute the next trigger; write the next event file with a fresh short-id at the computed timestamp; then move the current file to `_fired/`.

The rollover order matters: write the *next* file before archiving the *current* one. If the cycle is interrupted between the two steps, the schedule is still consistent (the next event exists; only the archive lags), and the next cycle's housekeeping (an idempotent re-survey) clears the lag.

## Output

`next-trigger.sh`:

- stdout line 1: UTC ISO-8601 (`2026-05-13T07:00:00Z`).
- stdout line 2: compact form (`20260513T070000Z`).
- exit 0 on success, 1 on parse failure, 2 on usage error.

Schedule edits write event files and update the README; the journal-sync skill handles commit and push.

## State

The schedule tree under `journal/schedule/` is the only durable state. The `_fired/` archive is append-only history. The timekeeper holds no in-memory state across cycles.

## Notes from the field

(Terse and dated. Append; do not rewrite history.)

- _2026-05-13_: authored alongside `roles/timekeeper/AGENT.md` and the first scheduled event (a daily midnight Pacific progress summary). The recurrence-rule shape is a flat kebab string parsed by `next-trigger.sh`; the alternative considered was a structured frontmatter object (`frequency:`, `at:`, `timezone:`). The flat string won on the round trip: it appears in filenames, in conversation, and in journal entries as one atom, and the script does the parsing once. If more complex recurrences arrive (cron-like minute-by-minute patterns), the structured form is the obvious next step; document the migration here when it lands.
