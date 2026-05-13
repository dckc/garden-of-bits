---
created: 2026-05-13
updated: 2026-05-13
author: gardener
---

# Skill: journalism

The user-of-the-journal manual. An agent reading this skill should know how to find anything in the journal in one or two queries. Authored by the gardener; maintained by the [journalist](../../roles/journalist/AGENT.md) as the journal's conventions evolve.

The [journalist](../../roles/journalist/AGENT.md) role is the *maintainer-of-the-journal*'s duties (the bulletin-section dispatcher, the renderer); this skill is the *user-of-the-journal*'s manual (how anyone reads what is there). Pair this skill with `skills/journal-sync/SKILL.md` (for safe append) and `skills/context-library/SKILL.md` (for hierarchy conventions).

## Where the journal lives

The journal is a git worktree on the orphan `journal` branch of the garden repo. From any dispatch root the path is `journal/`. From the garden root on a host the path is also `<garden-root>/journal/`. The branch never merges with `main`; entries are append-only.

Layout summary:

```
journal/
  README.md                         # the maintainer dashboard (bulletin + ongoing work)
  entries/<YYYY>/<MM>/<DD>/...      # append-only journal entries
  worktrees/<host>/<name>.md        # per-worktree authoritative state
  agents/                           # terminated long-living subagent archive
  projects/<slug>/                  # per-project context tree (context-library)
  pr-deps/                          # PR dependency registry
  inboxes/<host>/<role>.md          # inbox-drain state files
```

## Entry kinds and frontmatter

Every entry under `entries/` is a markdown file with YAML frontmatter. The kinds (`kind:` field) are:

- `dispatch`: a role kicked off a subagent. Names the dispatch root and the task.
- `tick`: a per-cycle or per-event note from a recurring role (monitor, journalist, steward, scholar).
- `result`: a closing record. Cites the `dispatch` it answers via `refs:`.
- `message`: cross-role communication. Carries a `to:` field (target role or `*` for broadcast).
- `worktree`: a state change on a long-lived worktree (create, collect, status flip).

Other useful frontmatter fields:

- `ts:` (always): ISO-8601 UTC timestamp.
- `role:` (always): the role producing the entry.
- `project:` (optional): short slug matching `journal/projects/<slug>/`. Recommended whenever an entry is about a specific project.
- `worktree:` (sometimes): the worktree the entry is about (long-lived or per-dispatch).
- `to:` (messages): target role or `*`.
- `refs:` (often): list of entry paths the new entry threads from.

The schema is canonical at `garden/roles/COMMON.md` § The journal. Read that when authoring an entry; this skill is for reading.

## Common queries

All queries run from a dispatch root or from the garden root; both contain `journal/`.

### Recent overview

```sh
git -C journal log --since='1 hour ago' --pretty='%h %ai %s'
```

Walk the commit log. Each commit is one entry's append; the subject line names the kind, role, and one-line summary.

### Entries for a project

```sh
grep -rl '^project: <slug>' journal/entries/
```

Returns every entry tagged with the project slug. Sort by path (chronological) to recover history; the most recent entry is the current source of truth. For project-specific *static* context (URLs, identity conventions, rules of engagement), prefer `journal/projects/<slug>/` over the entry stream; entries record events, the project tree records facts.

### Messages addressed to your role

```sh
grep -rl 'to: <role>\|to: "\*"' journal/entries/$(date -u +%Y/%m/%d)/
```

For systematic draining across cycles, the steward and the in-session liaison use the `inbox-drain` script (see `skills/inbox-drain/SKILL.md`) which tracks `last_drained_commit` per host per role.

### A specific thread

Start from any entry, read its `refs:` list. Each ref is a previous entry; follow the chain backward to the originating event. The thread is a partial order, not a linear log: a single dispatch may produce several `result` entries; a single `result` may cite multiple `dispatch` entries.

```sh
# show one entry's frontmatter
head -20 journal/entries/<path>

# find entries that cite a given entry (forward thread)
grep -rl '<entry-relative-path>' journal/entries/
```

### Entries of one kind

```sh
git -C journal log --since='1 week ago' --pretty='%h %s' | grep '^[0-9a-f]* result:'
```

The commit subject prefix is `<kind>:` followed by the role and summary. Useful for "show me all the `result` entries this week."

### Daemon-tick survey

Monitor and review-queue daemons produce `tick` entries on event-bearing wakes. To survey a daemon's recent activity:

```sh
grep -l 'role: monitor' journal/entries/$(date -u +%Y/%m/%d)/*.md \
  | xargs grep -l 'project: <slug>'
```

For cross-day surveys, walk `entries/<YYYY>/<MM>/<DD>/` directories explicitly.

## The `journal/projects/` index

The seed projects live under `journal/projects/<slug>/`:

```
journal/projects/
  README.md                          # index of all projects with one-line abstracts
  <slug>/README.md                   # per-project entry; rules of engagement, identity
  <slug>/<topic>.md                  # per-topic detail when the project has accumulated it
```

Per the [context-library](../context-library/SKILL.md) skill, each README opens with a specific abstract. An agent looking for project-specific facts:

1. Reads `journal/projects/README.md` to identify the project.
2. Reads `journal/projects/<slug>/README.md`'s abstract; if it matches the query, reads the body. If not, returns.
3. If the project README points to a `<topic>.md`, descends only when the topic's abstract matches the query.

The scholar (`roles/scholar/AGENT.md`) grows `<topic>.md` files from `project:`-tagged entries; the project README is the index. Per-project entries in `entries/` are still the chronological record; `projects/` is the curated index that turns event entries into addressable context.

## The `inbox-drain` script

For role-addressed messages across cycles, use the script rather than re-grepping each cycle:

```sh
skills/inbox-drain/inbox-drain.sh <role>
```

The script tracks `last_drained_commit` per host per role at `journal/inboxes/<host>/<role>.md` and prints one line per new `to: <role>` or `to: *` entry since the last drain. See `skills/inbox-drain/SKILL.md` for the full contract.

## Breadcrumb conventions for the journalist's curated trees

For curated trees the [journalist](../../roles/journalist/AGENT.md) and [scholar](../../roles/scholar/AGENT.md) maintain (`journal/projects/`, future trees), the [context-library](../context-library/SKILL.md) discipline applies:

- Each directory carries a `README.md` with a one-line abstract per child.
- Each document opens with a prose abstract specific enough to use as a stop condition.
- The abstract is a contract: a reader whose query does not match the abstract abandons the search at that level.

If you are walking such a tree and the abstract does not deliver on its promise, that is a defect; flag it as a self-improvement message to the journalist (the maintainer of the tree).

## What this skill is not

- Not a writing guide. Writing entries is `skills/journal-sync/SKILL.md`. Writing the bulletin is the journalist's role. Writing project context is the scholar's role.
- Not a search engine. Queries are `grep` and `git log`; the skill names the common shapes but does not replace them.
- Not exhaustive. The journal's conventions evolve; the journalist updates this skill as patterns settle.

## Notes from the field

(Terse and dated. Append; do not rewrite history.)

- _2026-05-13_: authored by the gardener as the canonical user-of-the-journal manual. Co-introduced with `roles/librarian/AGENT.md` (the dispatch-on-demand consumer of this skill), `roles/scholar/AGENT.md` (the grower of `journal/projects/`), and `skills/context-library/SKILL.md` (the hierarchical-doc conventions).
