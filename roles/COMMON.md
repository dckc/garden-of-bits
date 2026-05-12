# Subagent standing instructions

These apply to every dispatched subagent regardless of role. Read this first, then your role file at `roles/<role>/AGENT.md`. Your cwd is your assigned worktree, not the garden — always reference garden artifacts by absolute path.

## Where things are

- Garden root: `/Users/kris/garden/`
- Skills: `/Users/kris/garden/skills/<skill>/SKILL.md` (load on demand)
- Journal: `/Users/kris/garden/journal/` (git worktree of this repo on the orphan branch `journal`)
- Worktree management doc: `/Users/kris/garden/WORKTREES.md`
- Your assigned fork worktree: in the dispatch prompt; also `pwd` will report it.

## The journal

The journal is the garden's transcript and message bus. It is a worktree of the garden repo on an orphan branch — its history is independent of `main`, so journal commits never enter PRs or pollute code-side blame.

### Entry layout

```
/Users/kris/garden/journal/entries/<YYYY>/<MM>/<DD>/<HHMMSS>Z-<kind>-<role>-<short-id>.md
```

- `<HHMMSS>Z` — UTC time of day, zero-padded.
- `<short-id>` — 6 hex chars, random or from your session id. Makes filename collisions effectively impossible across concurrent agents.

### Entry shape

```markdown
---
ts: 2026-05-12T14:23:45Z
kind: tick                          # dispatch | tick | message | result | worktree
role: monitor                       # role producing the entry
worktree: worktrees/anthropics-claude-code/watch-main--monitor--20260512-142345
repo: anthropics/claude-code        # upstream, when applicable
to: "*"                             # for messages: target role, or "*" for broadcast
refs:
  - entries/2026/05/12/142200Z-dispatch-coordinator-a7f2c1.md
---

<one paragraph or short structured body>
```

### Writing an entry

Follow `skills/journal-sync/SKILL.md`. It handles the local commit retry loop and, if a remote is configured for the journal branch, the fetch/rebase/push retry loop. Do not roll your own — concurrent appends are subtle and the skill is the single source of truth.

### Reading recent entries

- Overview: `git -C /Users/kris/garden/journal log --since='1 hour ago' --pretty='%h %s'`
- Messages addressed to your role: grep frontmatter — `grep -rl 'to: <your-role>\|to: "\*"' /Users/kris/garden/journal/entries/$(date -u +%Y/%m/%d)/`
- A specific prior entry referenced from your dispatch: read the path verbatim.

## Worktree conventions (summary)

Full doc in `/Users/kris/garden/WORKTREES.md`. Minimum you need to know:

- Your worktree contains `.garden/worktree.toml` with metadata (purpose, role, repo, status, heartbeat).
- Read it on start. Update `last_heartbeat` once per tick if you are a long-lived role; update `status` if you change state (`active` → `idle` when done, `reserved` if you need exclusive access).
- Role-private state goes under `<worktree>/.garden/` or a role-specific dotfolder (e.g. `.garden-monitor/`). Never commit it to the upstream branch.
- Do not rename, move, or remove your worktree. Lifecycle is the coordinator's and reaper's job.

## Reporting

When done with a one-shot task, write a `result` entry to the journal **and** return a concise summary in your final message. The journal is durable; your final message is convenience for whoever dispatched you.

When you are interrupted or hit a blocker you cannot resolve, write a `message` entry addressed to `coordinator` describing what you tried and what you need.
