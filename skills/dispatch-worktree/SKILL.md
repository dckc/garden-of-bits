---
created: 2026-05-13
updated: 2026-05-14
author: gardener
---

# Skill: dispatch-worktree

The per-dispatch worktree triple: how to prepare one before invoking `Agent`, how it is torn down on return, and what the contract guarantees. The architecture rationale lives in `WORKTREES.md` § Per-dispatch worktree triple; this skill is the procedural detail and the home of the prepare and teardown scripts (`dispatch-prepare.sh`, `dispatch-teardown.sh`, sibling to this `SKILL.md` file).

## When to use

Every `Agent` invocation runs in its own per-dispatch worktree triple. The orchestrator (liaison or steward) runs the prepare script immediately before invoking `Agent` and the teardown script immediately after the subagent returns (or stalls). The subagent never creates or destroys worktrees itself.

Standing monitor and review-queue daemons are the documented exception (`WORKTREES.md` § Standing exceptions). They are not per-dispatch entities and are not torn down between dispatches.

## Inputs

For `dispatch-prepare.sh`:

- `<role>`: the dispatching role (`monitor`, `boatman`, `review-queue`, `gardener`, etc.).
- `<purpose-slug>`: short kebab-case slug describing this specific dispatch (`react-to-pr-3253`, `forward-handoff-122`, `reconcile-bulletin`).
- `<owner>/<repo> <branch>`: optional; when given, a third sub-worktree `project/` is added at the named branch off the bare clone at `worktrees/<owner>-<repo>.git/`.

For `dispatch-teardown.sh`:

- `<dispatch-root>`: the absolute path the prepare script printed on stdout.

## Procedure

### Prepare

```sh
DISPATCH_ROOT=$(skills/dispatch-worktree/dispatch-prepare.sh <role> <purpose> [<owner>/<repo> <branch>])
```

The script creates:

```
dispatches/<role>--<short-id>/
  garden/    # detached worktree of garden's main branch
  journal/   # detached worktree of garden's journal branch
  project/   # (only when applicable) detached worktree of the fork@branch
```

All three sub-worktrees are detached HEAD so the subagent can `git fetch` and rebase or reset its own HEAD freely. The short-id is six hex chars; the orchestrator reuses it for the matching `dispatch` journal entry's filename so the two cross-reference cleanly.

The directory name omits the purpose slug and the UTC timestamp on purpose. Earlier the scheme included both (`<role>--<purpose>--<UTC-YYYYMMDD-HHMMSS>--<short-id>`), but absolute paths assembled from a deep dispatch root plus a deep project tree (e.g. `dispatches/<long>/project/packages/daemon/tmp/<slug>/endo.sock`) overran the 108-char `sockaddr_un` limit Linux applies to UNIX domain sockets and made the endo daemon's tests unrunnable inside a dispatch worktree. The full role / purpose / timestamp metadata lives in the matching `dispatch` journal entry (the authoritative index); the directory is only a unique handle. The purpose argument the orchestrator passes is still consumed by this script (it is included in the dispatch journal entry that the orchestrator writes next), it just does not flow into the directory name.

If a project repo and branch are named but no bare clone exists at `worktrees/<owner>-<repo>.git/`, the script rolls back partial state and exits non-zero with a hint to clone the fork first. The orchestrator either clones the fork (per `WORKTREES.md` § Adding a fork worktree) and retries, or reports the missing fork to the user.

### Teardown

```sh
skills/dispatch-worktree/dispatch-teardown.sh "$DISPATCH_ROOT"
```

Idempotent. Removes `garden/`, `journal/`, and (if present) `project/` worktrees via `git worktree remove --force`, then removes the dispatch root directory. Missing pieces are tolerated.

`git worktree remove` is preferred over `rm -rf` because git tracks each worktree in its admin tree; a bare `rm` would leak that entry and require a follow-up `git worktree prune`.

## Output

`dispatch-prepare.sh` prints the absolute dispatch root path on stdout. The orchestrator passes that path into the subagent's dispatch prompt (see `CLAUDE.md` § Dispatch prompt template).

`dispatch-teardown.sh` is silent on success; reports a one-line note on missing pieces.

## State

The scripts are stateless. State that survives across dispatches lives in the journal (the entries the subagent writes) or in the bare clones (`worktrees/<owner>-<repo>.git/`). The dispatch root itself holds no durable state; it is wholly recreated and torn down per dispatch.

## Contract guarantees

- Each dispatch sees its own `garden/` and `journal/`. Concurrent dispatches do not share these working trees.
- Each dispatch sees its own `project/` when applicable. Concurrent dispatches on the same fork worktree do not share working trees (each gets its own checkout off the shared bare clone).
- The orchestrator's own `garden/` checkout (on `main`) and its long-lived `journal/` worktree (on the `journal` branch) are not touched by the prepare or teardown scripts. The orchestrator is not in detached HEAD; only the per-dispatch sub-worktrees are.
- Concurrent prepare invocations do not collide because each script-call generates a fresh timestamp + short-id pair.

## Pitfalls

- **Stranded dispatch roots.** If the orchestrator forgets to call teardown (e.g., crashes before its post-Agent step), the dispatch root persists. The next steward cycle's housekeeping pass can collect stale roots whose age exceeds a threshold; for now, manual cleanup is the answer.
- **The bare clone is required for project worktrees.** Cloning a fork is a separate one-time step (`WORKTREES.md` § Adding a fork worktree). The prepare script will not create one for you.
- **Detached HEAD on the sub-worktrees.** A subagent that runs `git checkout <branch>` inside its sub-worktree breaks the detached-HEAD assumption and may conflict with concurrent worktrees on the same branch. Per `roles/COMMON.md` § Your dispatch root and `skills/journal-sync/SKILL.md`, push using `git push origin HEAD:<branch>` instead.

## Notes from the field

(Terse and dated. Append; do not rewrite history.)

- _2026-05-13_: scripts moved from `scripts/` to this skill directory (`skills/dispatch-worktree/{dispatch-prepare,dispatch-teardown}.sh`) as part of the broader scripts-into-skills reorganization. The architecture summary in `WORKTREES.md` § Per-dispatch worktree triple is unchanged; this skill is the new home of the procedural detail and the scripts themselves. The four other per-dispatch sibling scripts (`monitor-poll.sh`, `review-queue-poll.sh`, `inbox-drain.sh`) also moved into their respective skill directories in the same pass.
- _2026-05-14_: dispatch-root naming shortened from `<role>--<purpose>--<UTC-YYYYMMDD-HHMMSS>--<short-id>` to `<role>--<short-id>`. Trigger was a fixer working on PR #135 in `endojs/endo-but-for-bots` who could not run the daemon's `endo.test.js` locally: the absolute UNIX-socket path `/home/<user>/dispatches/<long-name>/project/packages/daemon/tmp/<test-slug>/endo.sock` overran the 108-char `sockaddr_un` limit, so every daemon test failed `ENOENT` before any assertion ran. The fix is to drop the purpose slug and the timestamp from the directory name; both still live in the matching `dispatch` journal entry, which is the authoritative index. Diagnosis at `entries/2026/05/14/090813Z-message-liaison-1bc419.md`.
