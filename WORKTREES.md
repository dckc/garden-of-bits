# Worktree management

All worktrees the garden uses live under the garden root. Two kinds:

1. **Journal** — `journal/`. A worktree of *this* repo on the orphan branch `journal`. Created once per machine. Never delete unless intentionally archiving the garden's history.
2. **Fork worktrees** — `worktrees/<owner>-<repo>/<name>/`. Worktrees added from a bare clone at `worktrees/<owner>-<repo>.git/`. Created and collected on demand.

## Bootstrap (run once)

```sh
# Initial commit on garden main (if not already present), needed before adding worktrees.
git -C /Users/kris/garden add -A
git -C /Users/kris/garden commit -m "garden: initial scaffold"

# Create the journal as an orphan-branch worktree.
git -C /Users/kris/garden worktree add --detach /Users/kris/garden/journal
git -C /Users/kris/garden/journal checkout --orphan journal
git -C /Users/kris/garden/journal rm -rf . 2>/dev/null || true
mkdir -p /Users/kris/garden/journal/entries
git -C /Users/kris/garden/journal commit --allow-empty -m "journal: initialized"
```

After bootstrap:

- `journal/` is at the orphan branch `journal`, sharing zero history with `main`.
- `git -C /Users/kris/garden branch` shows both `main` and `journal`.
- `git -C /Users/kris/garden worktree list` shows both checkouts.

## Adding a fork worktree

```sh
# Clone bare once per fork:
git clone --bare https://github.com/<owner>/<repo>.git \
  /Users/kris/garden/worktrees/<owner>-<repo>.git

# For each working checkout:
NAME="<purpose-slug>--<role>--$(date -u +%Y%m%d-%H%M%S)"
git -C /Users/kris/garden/worktrees/<owner>-<repo>.git worktree add \
  /Users/kris/garden/worktrees/<owner>-<repo>/$NAME <branch>

# Then the dispatcher writes .garden/worktree.toml (see below).
```

## Naming convention

```
worktrees/<owner>-<repo>/<purpose-slug>--<role>--<YYYYMMDD-HHMMSS>
```

- `<owner>-<repo>` mirrors the upstream slug, e.g. `anthropics-claude-code`.
- `<purpose-slug>` — kebab-case, what this worktree exists for: `fix-pagination`, `watch-main`, `try-rewrite`.
- `<role>` — primary occupying role: `monitor`, `implementer`, `reviewer`.
- timestamp — UTC, ensures uniqueness across concurrent dispatchers without coordination.

Example: `worktrees/anthropics-claude-code/watch-main--monitor--20260512-142345/`.

The `--` separators are deliberate: filenames contain no other double-dashes, so a quick `awk -F'--'` parses fields cleanly.

## Metadata file

Every fork worktree has `.garden/worktree.toml` written by the creator:

```toml
purpose        = "Watch main for new commits"
role           = "monitor"
repo           = "anthropics/claude-code"
branch         = "main"                       # upstream branch this worktree tracks
created_at     = "2026-05-12T14:23:45Z"
created_by     = "<dispatching session id>"
status         = "active"                     # active | idle | collectable | reserved
last_heartbeat = "2026-05-12T14:25:00Z"       # updated by the occupying agent
```

Add `.garden/` to the worktree's local-only excludes (`.git/info/exclude`) so the role-private metadata never lands in an upstream PR.

## Lifecycle and collection

A worktree is **collectable** when ALL of:

- `status` is not `active` and not `reserved`,
- `git -C <worktree> status --porcelain` is empty (no uncommitted changes),
- `git -C <worktree> log @{u}..` is empty, or the branch is local-only and has been merged or abandoned,
- `last_heartbeat` is older than 1 hour (default idle threshold; tunable per role).

Collection procedure:

1. Write a `worktree` journal entry (`kind: worktree`, body: "collected `<name>`, last activity `<ts>`, reason `<...>`").
2. `git -C /Users/kris/garden/worktrees/<owner>-<repo>.git worktree remove <path>`.
   Never `rm -rf` — git tracks the worktree in its admin tree and `worktree remove` keeps that consistent.

If `worktree remove` complains about uncommitted changes you did not expect, stop and investigate — that may be in-progress work the metadata is wrong about.

## Reservation

An agent that wants exclusive access to a worktree sets `status = "reserved"` in the metadata before it begins work, and back to `active` or `idle` when done. Other agents skip reserved worktrees when looking for collectable candidates or when they would otherwise consider piggybacking on an existing checkout.

Reservation is cooperative — there is no lock — so reserve only as long as you need.
