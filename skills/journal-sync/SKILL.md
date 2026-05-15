---
created: 2026-05-12
updated: 2026-05-15
author: liaison, gardener
---

# Skill: journal-sync

Append an entry to the garden's journal safely under concurrent local **and** remote modification. The journal is an append-only log of independent files; conflicts almost always reduce to "two agents picked the same filename in the same second", which we resolve by re-rolling the short-id.

This skill is the canonical procedure. Anything in `roles/COMMON.md` that talks about journaling defers here.

The procedure works in two modes, transparently:

- The orchestrator (liaison or steward) runs from its long-lived `journal/` worktree, which is checked out on the `journal` branch.
- A subagent runs from `<dispatch-root>/journal/`, which is in detached HEAD (per `WORKTREES.md` § Per-dispatch worktree triple).

The push command (`git push origin HEAD:journal`) works in both modes. The fetch + rebase loop works on detached HEAD without any extra ceremony.

## Inputs

- `journal_dir`: absolute path to your journal worktree. Orchestrators use the long-lived path (e.g. `<garden-root>/journal/`); subagents use `<dispatch-root>/journal/` as named in the dispatch prompt.
- `entry_path`: relative to `$journal_dir`. Standard form: `entries/<YYYY>/<MM>/<DD>/<HHMMSS>Z-<kind>-<role>-<short-id>.md`. Generate `<short-id>` with `openssl rand -hex 3`.
- `entry_body`: full markdown content (frontmatter + body). Schema is in `roles/COMMON.md` § The journal.
- `commit_message`: `<kind>: <role> <one-line summary>`.
- `remote` (optional): defaults to `origin` if a remote of that name exists; else local-only.

## State

The journal worktree at `$journal_dir`. The orchestrator's worktree (one per machine) is shared by every orchestrator turn on that host; per-dispatch journal worktrees are isolated to a single subagent and torn down when it returns. The remote (`origin/journal`) is shared across machines and across all worktrees.

## Procedure

All commands run with `git -C $journal_dir ...`. Do not `cd`; keep your own cwd intact.

```sh
JRN=$journal_dir
```

### 1. Sync from remote (skip if no remote)

```sh
git -C $JRN remote get-url origin >/dev/null 2>&1 && HAS_REMOTE=1 || HAS_REMOTE=0
if [ $HAS_REMOTE -eq 1 ]; then
  git -C $JRN fetch --quiet origin journal || true     # best-effort
  # If we have no local commits ahead, fast-forward HEAD to the latest.
  # If we do have local commits, rebase them onto the latest.
  AHEAD=$(git -C $JRN rev-list --count origin/journal..HEAD 2>/dev/null || echo 0)
  BEHIND=$(git -C $JRN rev-list --count HEAD..origin/journal 2>/dev/null || echo 0)
  if [ "$AHEAD" = "0" ] && [ "$BEHIND" != "0" ]; then
    # Strictly behind: fast-forward HEAD to the latest. Works the same on
    # a branch checkout and on a detached HEAD. Unlike reset --hard, this
    # aborts if there are uncommitted changes, rather than destroying them.
    git -C $JRN merge --ff-only origin/journal
  elif [ "$AHEAD" != "0" ] && [ "$BEHIND" != "0" ]; then
    # Diverged: rebase our commits onto the new tip.
    git -C $JRN rebase origin/journal || { git -C $JRN rebase --abort; FAIL=conflict; }
  fi
  # Else (no local commits, no remote commits) or (local commits, none new
  # upstream): nothing to do.
fi
```

If rebase conflicts (rare; would require two agents touching the same path), abort and fall through to retry with a fresh short-id.

### 2. Write the entry file

```sh
mkdir -p "$(dirname $JRN/$entry_path)"
printf '%s' "$entry_body" > "$JRN/$entry_path.tmp"
mv "$JRN/$entry_path.tmp" "$JRN/$entry_path"   # atomic publish
```

If the path already exists, regenerate the short-id and retry from step 2.

### 3. Commit (retry on `index.lock`)

```sh
for i in 1 2 3 4 5; do
  git -C $JRN add "$entry_path" && \
  git -C $JRN commit -m "$commit_message" && break
  sleep 0.2   # another agent has the index; back off
done
```

If all 5 retries fail, abort and report. Something is wrong beyond ordinary contention (stale lock, full disk, etc.).

### 4. Push (skip if no remote)

```sh
if [ $HAS_REMOTE -eq 1 ]; then
  for i in 1 2 3 4 5; do
    git -C $JRN push origin HEAD:journal && break
    # Push rejected → someone else pushed first. Refetch, rebase, retry.
    git -C $JRN fetch --quiet origin journal
    git -C $JRN rebase origin/journal || { git -C $JRN rebase --abort; FAIL=conflict; break; }
    sleep $((i * i))   # 1s, 4s, 9s, 16s, 25s; gives concurrent agents time to drain
  done
fi
```

The `HEAD:journal` form works whether your local HEAD is on the `journal` branch or detached. If push still fails after the final retry, leave the local commit in place and report; the next journal write retries the push as part of step 1.

## Output

On success: the commit SHA (`git -C $JRN rev-parse HEAD`) and the entry path.
On failure: the failure mode (`conflict` | `lock-timeout` | `push-rejected-after-retries` | `auth`) and the local commit SHA if one was created.

## Reading the journal

Reading needs no skill: `git log` and `find`/`grep` over `entries/` are sufficient. Common queries (run from your dispatch root, which contains `journal/`):

- Recent overview: `git -C journal log --since='1 hour ago' --pretty='%h %ai %s'`.
- Messages to your role: `grep -rl 'to: <role>\|to: "\*"' journal/entries/$(date -u +%Y/%m/%d)/`.
- Follow a thread: chase the `refs:` list in each entry.

If you fetched recent entries but want to be sure you have the latest, run step 1 of the append procedure (sync only; no entry needed).

## Notes from the field

(This section accumulates gotchas as agents hit them. Keep entries terse and dated.)

- _2026-05-12_: initial bootstrap. The journal branch is created via `git worktree add --detach` followed by `git checkout --orphan` inside the worktree, then `git rm -rf .` to clear the index inherited from `main`, then a single `commit --allow-empty -m "journal: initialized"`. Doing it this way avoids ever switching `main`'s checkout off `main`.
- _2026-05-13_: the push command changed from `git push origin journal` to `git push origin HEAD:journal` so the same skill works for both the orchestrator's branch-checkout journal worktree and the per-dispatch detached-HEAD journal worktrees subagents now use. The earlier ff-merge branch in step 1 also collapsed into `git merge --ff-only origin/journal`, which does the same fast-forward but aborts (rather than silently destroying) on uncommitted changes.
- _2026-05-13_: **sync your `journal/` worktree before editing tracked files, not after.** A subagent that prepares multi-file edits to tracked journal files (e.g. `journal/README.md`, `journal/worktrees/README.md`, `journal/projects/<slug>/README.md`) and then runs step 1 will lose those edits to the `git merge --ff-only origin/journal` (which aborts rather than silently destroying) when sister dispatches or the steward have pushed concurrently. The correct ordering for any multi-file journal edit: (a) `git -C journal fetch && git -C journal merge --ff-only origin/journal` (or `rebase origin/journal` if you have local commits to keep), (b) make the edits, (c) commit, (d) push with the standard retry-on-rejection loop. The earlier 2026-05-13 gardener (`82b357`) and the gardener writing this row (`04526e`) both hit it; landing this row twice on the same date is intentional, since both runs surfaced the same pattern.
