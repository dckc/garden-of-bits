# Skill: journal-sync

Append an entry to the garden's journal safely under concurrent local **and** remote modification. The journal is an append-only log of independent files; conflicts almost always reduce to "two agents picked the same filename in the same second", which we resolve by re-rolling the short-id.

This skill is the canonical procedure. Anything in `roles/COMMON.md` that talks about journaling defers here.

## Inputs

- `entry_path` — relative to `/Users/kris/garden/journal/`. Standard form: `entries/<YYYY>/<MM>/<DD>/<HHMMSS>Z-<kind>-<role>-<short-id>.md`. Generate `<short-id>` with `openssl rand -hex 3`.
- `entry_body` — full markdown content (frontmatter + body). Schema is in `roles/COMMON.md` § The journal.
- `commit_message` — `<kind>: <role> <one-line summary>`.
- `remote` (optional) — defaults to `origin` if a remote of that name exists on the journal branch; else local-only.

## State

The journal worktree at `/Users/kris/garden/journal/` (orphan branch `journal`). Shared by all agents on this machine; if a remote is configured, shared across machines too.

## Procedure

All commands run with `git -C /Users/kris/garden/journal`. Do not `cd` — keep your own cwd intact so you can return to your worktree.

```
JRN=/Users/kris/garden/journal
```

### 1. Sync from remote (skip if no remote)

```
git -C $JRN remote get-url origin >/dev/null 2>&1 && HAS_REMOTE=1 || HAS_REMOTE=0
if [ $HAS_REMOTE -eq 1 ]; then
  git -C $JRN fetch --quiet origin journal || true   # best-effort
  # Fast-forward if we're strictly behind. Rebase only if we have local commits.
  LOCAL_AHEAD=$(git -C $JRN rev-list --count origin/journal..HEAD 2>/dev/null || echo 0)
  if [ "$LOCAL_AHEAD" = "0" ]; then
    git -C $JRN merge --ff-only origin/journal || true
  else
    git -C $JRN rebase origin/journal || { git -C $JRN rebase --abort; FAIL=conflict; }
  fi
fi
```

If rebase conflicts (rare — would require two agents touching the same path), abort and fall through to retry with a fresh short-id.

### 2. Write the entry file

```
mkdir -p "$(dirname $JRN/$entry_path)"
printf '%s' "$entry_body" > "$JRN/$entry_path.tmp"
mv "$JRN/$entry_path.tmp" "$JRN/$entry_path"   # atomic publish
```

If the path already exists, regenerate the short-id and retry from step 2.

### 3. Commit (retry on `index.lock`)

```
for i in 1 2 3 4 5; do
  git -C $JRN add "$entry_path" && \
  git -C $JRN commit -m "$commit_message" && break
  sleep 0.2   # another agent has the index; back off
done
```

If all 5 retries fail, abort and report — something is wrong beyond ordinary contention (stale lock, full disk, etc.).

### 4. Push (skip if no remote)

```
if [ $HAS_REMOTE -eq 1 ]; then
  for i in 1 2 3 4 5; do
    git -C $JRN push origin journal && break
    # Push rejected → someone else pushed first. Refetch, rebase, retry.
    git -C $JRN fetch --quiet origin journal
    git -C $JRN rebase origin/journal || { git -C $JRN rebase --abort; FAIL=conflict; break; }
    sleep $((i * i))   # 1s, 4s, 9s, 16s, 25s — gives concurrent agents time to drain
  done
fi
```

If the final attempt still fails, leave the local commit in place and report. The next journal write will retry the push as part of step 1.

## Output

On success: the commit SHA (`git -C $JRN rev-parse HEAD`) and the entry path.
On failure: the failure mode (`conflict` | `lock-timeout` | `push-rejected-after-retries` | `auth`) and the local commit SHA if one was created.

## Reading the journal

Reading needs no skill — `git log` and `find`/`grep` over `entries/` are sufficient. Common queries:

- Recent overview: `git -C /Users/kris/garden/journal log --since='1 hour ago' --pretty='%h %ai %s'`
- Messages to your role: `grep -rl 'to: <role>' /Users/kris/garden/journal/entries/$(date -u +%Y/%m/%d)/`
- Follow a thread: chase the `refs:` list in each entry.

If you fetched recent entries but want to be sure you have the latest, run step 1 of the append procedure (sync only — no entry needed).

## Notes from the field

(This section accumulates gotchas as agents hit them. Keep entries terse and dated.)

- _2026-05-12_ — initial bootstrap. The journal branch is created via `git worktree add --detach` followed by `git checkout --orphan` inside the worktree, then `git rm -rf .` to clear the index inherited from `main`, then a single `commit --allow-empty -m "journal: initialized"`. Doing it this way avoids ever switching `main`'s checkout off `main`.
