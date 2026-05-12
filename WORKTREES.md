---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Worktree management

All worktrees the garden uses live under the garden root. Two kinds:

1. **Journal** (`journal/`). A worktree of *this* repo on the orphan branch `journal`. Created once per machine. Never delete unless intentionally archiving the garden's history.
2. **Fork worktrees** (`worktrees/<owner>-<repo>/<name>/`). Worktrees added from a bare clone at `worktrees/<owner>-<repo>.git/`. Created and collected on demand.

## Bootstrap (run once)

Run from the garden root:

```sh
# Initial commit on garden main (if not already present), needed before adding worktrees.
git add -A
git commit -m "garden: initial scaffold"

# Create the journal as an orphan-branch worktree.
git worktree add --detach journal
git -C journal checkout --orphan journal
git -C journal rm -rf . 2>/dev/null || true
mkdir -p journal/entries
git -C journal commit --allow-empty -m "journal: initialized"
```

After bootstrap:

- `journal/` is at the orphan branch `journal`, sharing zero history with `main`.
- `git branch` shows both `main` and `journal`.
- `git worktree list` shows both checkouts.

## Adding a fork worktree

Run from the garden root:

```sh
# Clone bare once per fork:
git clone --bare https://github.com/<owner>/<repo>.git \
  worktrees/<owner>-<repo>.git

# Once per bare clone: tell git to ignore our metadata directory in every
# worktree created from it. The per-worktree `.git` is a *file* (worktree
# pointer), not a directory, so the usual `<worktree>/.git/info/exclude`
# trick does not work; append to the bare clone's shared exclude instead.
echo '.garden/' >> worktrees/<owner>-<repo>.git/info/exclude

# For each working checkout:
NAME="<purpose-slug>--<role>--$(date -u +%Y%m%d-%H%M%S)"
git --git-dir=worktrees/<owner>-<repo>.git worktree add \
  worktrees/<owner>-<repo>/$NAME <branch>

# Then the dispatcher writes the journal index entry at
# journal/worktrees/<host>/<name>.md (see "Worktree state lives in the journal" below).
```

## Naming convention

```
worktrees/<owner>-<repo>/<purpose-slug>--<role>--<YYYYMMDD-HHMMSS>
```

- `<owner>-<repo>` mirrors the upstream slug, e.g. `anthropics-claude-code`.
- `<purpose-slug>`: kebab-case, what this worktree exists for (`fix-pagination`, `watch-main`, `try-rewrite`).
- `<role>`: primary occupying role (`monitor`, `implementer`, `reviewer`).
- timestamp: UTC, ensures uniqueness across concurrent dispatchers without coordination.

Example: `worktrees/anthropics-claude-code/watch-main--monitor--20260512-142345/`.

The `--` separators are deliberate: filenames contain no other double-dashes, so a quick `awk -F'--'` parses fields cleanly.

## Worktree state lives in the journal

Every fork worktree has a single authoritative state file: an entry in the journal index at:

```
journal/worktrees/<hostname>/<worktree-name>.md
```

There is no per-worktree TOML. Agents read and update the journal entry directly, fetch / rebase / push per `skills/journal-sync/SKILL.md`. Concurrent edits from different machines merge cleanly because each worktree has its own file.

See `journal/worktrees/README.md` for the schema (path, repo, branch, role, status, heartbeat, task, prs across multiple repos) and the lifecycle (create / heartbeat / status change / PR binding / collect). Collection sets `status: collected`; the entry is retained for historical lookup.

Inside the worktree itself, `.garden/` may still hold role-private high-frequency state (e.g., the `.garden-monitor/<repo>/` polling state used by the github-activity-poll skill). That state stays local to the worktree, never committed upstream, never authoritative for cross-machine state. Add `.garden/` to the bare clone's `info/exclude` (per the bare-clone setup above) so the role-private state is invisible to the upstream's working tree.

## Lifecycle and collection

A worktree is **collectable** when ALL of:

- The journal index entry's `status` is not `active` and not `reserved`,
- `git -C <worktree> status --porcelain` is empty (no uncommitted changes),
- `git -C <worktree> log @{u}..` is empty, or the branch is local-only and has been merged or abandoned,
- The journal index entry's `last_heartbeat` is older than 1 hour (default idle threshold; tunable per role).

Collection procedure:

1. Write a `worktree` journal entry (`kind: worktree`, body: "collected `<name>`, last activity `<ts>`, reason `<...>`").
2. From the garden root: `git --git-dir=worktrees/<owner>-<repo>.git worktree remove <path>`.
   Never `rm -rf`. Git tracks the worktree in its admin tree, and `worktree remove` keeps that consistent.

If `worktree remove` complains about uncommitted changes you did not expect, stop and investigate. That may be in-progress work the metadata is wrong about.

## Reservation

An agent that wants exclusive access to a worktree sets `status: reserved` in its journal index entry before it begins work, and back to `active` or `idle` when done. Other agents skip reserved worktrees when looking for collectable candidates or when they would otherwise consider piggybacking on an existing checkout.

Reservation is cooperative (no lock), so reserve only as long as you need.
