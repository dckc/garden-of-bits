---
ts: 2026-05-15T10:48:54Z
kind: dispatch
role: liaison
project: garden-of-bits
to: "*"
---

# Dispatch: gardener — update stale kriskowal/garden refs to dckc/garden-of-bits

Dispatch root: `dispatches/gardener--dc9522/`. Project worktree on `dckc/garden-of-bits@main`.

This garden was forked from kriskowal/garden and adapted for dckc. Several files and running state still reference `kriskowal/garden` instead of `dckc/garden-of-bits`.

## Task

1. **Stop the stale monitor daemon.** The daemon polling `kriskowal/garden` is still running (PID file at `/tmp/garden-monitor-kriskowal-garden.pid`). Kill it. Delete the PID, log, and err files.

2. **Start a new daemon for `dckc/garden-of-bits`.** Use the respawn pattern from `roles/steward/AGENT.md` § Standing monitors. Create a watch worktree under `worktrees/dckc-garden-of-bits/` for the monitor. The cadence is 60s. Log files at `/tmp/garden-monitor-dckc-garden-of-bits.{log,err,pid}`.

3. **Edit files to replace `kriskowal/garden` → `dckc/garden-of-bits`** throughout, with appropriate context-aware wording:

   - **`roles/steward/AGENT.md`** — Standing monitors table, daemon-log Monitor list, the dispatch step reference, the issue-surveillance paragraph. Update the sentence about `kriskowal/garden` meeting the safety bar to `dckc/garden-of-bits`.
   - **`CLAUDE.md`** — The "No PR workflows" section (line 107) references `github.com/kriskowal/garden` — change to `dckc/garden-of-bits` origin. The monitoring safety constraint (line 127).
   - **`roles/COMMON.md`** — Monitoring safety constraint (line 65).
   - **`roles/monitor/AGENT.md`** — The `garden` → `kriskowal/garden` mapping (line 47).
   - **`skills/monitor-garden/SKILL.md`** — Upstream ref, purpose statement, dispatch role asymmetry section.
   - **`roles/liaison/AGENT.md`** — The note about posting on `kriskowal/garden` (line 154).
   - **`run-steward-cycle.sh`** — The daemon check line (line 88).
   - **`README.md`** — GitHub links pointing to `kriskowal/garden`.
   - **`skills/garden-ab-evaluation/SKILL.md`** — Historical garden ref references (lines 26-27).

4. **Remove/clean up the stale `worktrees/kriskowal-garden/` checkout directory** if it exists and is no longer needed.

5. **Commit all changes to `dckc/garden-of-bits@main`** with appropriate commit messages (one commit per logical change area, or batched into a single commit titled `chore: replace stale kriskowal/garden refs with dckc/garden-of-bits`).

6. **Write a `result` journal entry** documenting what was changed.

## Out of scope

- Do not touch the `endojs/` worktrees or any jesc24 work.
- Do not edit the journal entries (they are history; leave them).
- Do not edit worktree management files.

## Report

List each file changed, what was updated, and the one-line `Self-improvement: ...`.