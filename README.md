# Garden

A library of agent **roles** and **skills** for working across many forks of GitHub repositories, plus a **journal** that records what the garden has done.

## The journal

The journal lives on the orphan `journal` branch of this repo. It is the garden's transcript and message bus, append-only and machine-readable.

**[Browse the journal on GitHub](https://github.com/kriskowal/garden/tree/journal)**

The journal's [`README.md`](https://github.com/kriskowal/garden/blob/journal/README.md) is the maintainer dashboard: a bulletin board for items that need a human's attention plus a summary of ongoing work. Agents post and clear bulletin items as conditions arise and resolve; the maintainer reads the dashboard and acts in the upstream system.

## Layout

- [`roles/<role>/AGENT.md`](./roles/) — operating brief for one role. Each role file lists which skills it uses and any role-specific norms.
- [`skills/<skill>/SKILL.md`](./skills/) — self-contained playbooks for individual capabilities (purpose, inputs, procedure, outputs, state).
- [`CLAUDE.md`](./CLAUDE.md) — the garden's top-level orientation: layout, the dispatch contract, and a current inventory of roles and skills.
- [`WORKTREES.md`](./WORKTREES.md) — worktree lifecycle: the standing journal worktree, fork worktrees, and the per-dispatch worktree triple every subagent runs in.
- [`references/<source>/`](./references/) — read-only shelves of roles and skills imported from other gardens, browsed when no active role fits a new request.

Role and skill files use `AGENT.md` / `SKILL.md` / `COMMON.md` naming on purpose: Claude Code only auto-loads `CLAUDE.md`, so the root `CLAUDE.md` orients the orchestrator while role and skill files stay out of the auto-loaded set — each dispatched subagent reads only the files its role brief explicitly names.

## Not application code

The garden contains no application code, only the artifacts that let orchestrating agents dispatch focused subagents into worktrees of other repositories. Both `main` and `journal` are pushed directly to `origin`; no PR workflows are used for the garden's own repo.
