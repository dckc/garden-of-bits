---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Subagent standing instructions

These apply to every dispatched subagent regardless of role. Read this first, then your role file at `roles/<role>/AGENT.md`. Your cwd is your assigned worktree, not the garden. Always reference garden artifacts by absolute path.

The §_Improving your role and skills_ section below is common to **every** role including the liaison; the worktree-specific sections (heartbeat, `.garden/worktree.toml`) only apply to subagents dispatched into a fork worktree.

## Improving your role and skills

The final task of every engagement, common to every role including the liaison. Follow `skills/self-improvement/SKILL.md` for what to look for, where to route the lesson, the threshold rules, and the one-line report format. The skill is canonical: do not embed self-improvement details in role files.

Commit role/skill changes on `main` with a message that names the lesson, not just the file changed.

## Style

Two prose-style rules apply to every document you author or edit in the garden, including journal entry bodies. Both are skills:

- `skills/em-dash-style/SKILL.md`: avoid em-dashes in prose; rewrite as period, parentheses, or colon.
- `skills/relative-paths/SKILL.md`: paths within one document tree are relative; absolute paths are reserved for the cross-tree case (a document instructing an agent in another tree, like this file does for subagents reading it from worktrees).

Vendored content under `references/<source>/` is exempt from both rules: references are read-only snapshots.

## Document frontmatter

Every persistent document in the garden (role files, skill files, top-level docs) carries YAML frontmatter at the top with creation, last-updated, and author fields:

```yaml
---
created: 2026-05-12          # ISO date the document was first written
updated: 2026-05-12          # ISO date of the most recent meaningful edit
author: liaison              # role that last meaningfully revised it; comma-separated for joint work
---
```

When you edit a document, update `updated`. If your authorship changes the document's center of gravity, prepend yourself to `author`. Trivial fixes (typos, link repair) do not warrant an authorship change.

The journal does **not** use this frontmatter. Entries already carry `ts:` and `role:`, and they are append-only so `updated` is moot.

## Project context

Project specifics (repo URLs, fork ownership, account/credential conventions, project-specific preferences) live in the **journal**, not in role or skill files. The garden's role/skill layer is project-agnostic and stays small; per-project facts accumulate as `message` entries with a `project:` slug.

To find what the garden knows about a project: `grep -rl '^project: <slug>' /Users/kris/garden/journal/entries/`. The most recent matching entry is the current source of truth; older entries are history.

## Where things are

- Garden root: `/Users/kris/garden/`
- Skills: `/Users/kris/garden/skills/<skill>/SKILL.md` (load on demand)
- Journal: `/Users/kris/garden/journal/` (git worktree of this repo on the orphan branch `journal`)
- Worktree management doc: `/Users/kris/garden/WORKTREES.md`
- Your assigned fork worktree: in the dispatch prompt; also `pwd` will report it.

## The journal

The journal is the garden's transcript and message bus. It is a worktree of the garden repo on an orphan branch. Its history is independent of `main`, so journal commits never enter PRs or pollute code-side blame.

### Entry layout

```
/Users/kris/garden/journal/entries/<YYYY>/<MM>/<DD>/<HHMMSS>Z-<kind>-<role>-<short-id>.md
```

- `<HHMMSS>Z`: UTC time of day, zero-padded.
- `<short-id>`: 6 hex chars, random or from your session id. Makes filename collisions effectively impossible across concurrent agents.

### Entry shape

```markdown
---
ts: 2026-05-12T14:23:45Z
kind: tick                          # dispatch | tick | message | result | worktree
role: monitor                       # role producing the entry
worktree: worktrees/anthropics-claude-code/watch-main--monitor--20260512-142345
repo: anthropics/claude-code        # upstream, when applicable
project: endo                       # optional, short slug; lets agents grep entries by project
to: "*"                             # for messages: target role, or "*" for broadcast
refs:
  - entries/2026/05/12/142200Z-dispatch-liaison-a7f2c1.md
---

<one paragraph or short structured body>
```

The `project:` field is optional but recommended whenever an entry is about a specific project. Search by `grep -l '^project: <slug>' ...` to recover all entries for a project. Project slugs are short kebab-case names that match the canonical upstream repo name (e.g. `endo`, `agoric-sdk`), not the fork owner.

### Writing an entry

Follow `skills/journal-sync/SKILL.md`. It handles the local commit retry loop and, if a remote is configured for the journal branch, the fetch/rebase/push retry loop. Do not roll your own; concurrent appends are subtle and the skill is the single source of truth.

### Reading recent entries

- Overview: `git -C /Users/kris/garden/journal log --since='1 hour ago' --pretty='%h %s'`
- Messages addressed to your role: `grep -rl 'to: <your-role>\|to: "\*"' /Users/kris/garden/journal/entries/$(date -u +%Y/%m/%d)/`
- A specific prior entry referenced from your dispatch: read the path verbatim.

## Worktree conventions (summary)

Full doc in `/Users/kris/garden/WORKTREES.md`. Minimum you need to know:

- Your worktree contains `.garden/worktree.toml` with metadata (purpose, role, repo, status, heartbeat).
- Read it on start. Update `last_heartbeat` once per tick if you are a long-lived role; update `status` if you change state (`active` → `idle` when done, `reserved` if you need exclusive access).
- Role-private state goes under `<worktree>/.garden/` or a role-specific dotfolder (e.g. `.garden-monitor/`). Never commit it to the upstream branch.
- Do not rename, move, or remove your worktree. Lifecycle is the liaison's and reaper's job.

## Reporting

When done with a one-shot task, write a `result` entry to the journal **and** return a concise summary in your final message. The journal is durable; your final message is convenience for whoever dispatched you. Both end with a one-line `Self-improvement: ...` per `skills/self-improvement/SKILL.md` (or `Self-improvement: nothing this time.`).

When you are interrupted or hit a blocker you cannot resolve, write a `message` entry addressed to `liaison` describing what you tried and what you need.
