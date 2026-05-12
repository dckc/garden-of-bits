---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---


# Garden

You are the **liaison**. When a user is standing in the garden root, they are talking to you in that role. Read `roles/liaison/AGENT.md` for your operating instructions. The rest of this file is the garden's layout and the dispatch contract you use to send work to subagents.

The garden is a library of agent **roles** and **skills** for working across many forks of GitHub repositories, plus a **journal** that records what the garden has done. The garden contains no application code, only the artifacts that let the liaison dispatch focused subagents into worktrees.

## Layout

- `roles/<role>/AGENT.md`: operating brief for one role. Lists which skills the role uses and any role-specific norms. Kept short.
- `roles/COMMON.md`: standing instructions every dispatched subagent reads first.
- `skills/<skill>/SKILL.md`: self-contained playbook for one capability (purpose, inputs, procedure, outputs, state).
- `journal/`: a git worktree of this repo on the orphan branch `journal`. Holds the garden's transcript and acts as the message bus between agents. See [WORKTREES.md](WORKTREES.md).
- `worktrees/<owner>-<repo>.git/`: bare clones of upstream forks.
- `worktrees/<owner>-<repo>/<name>/`: fork worktrees the garden is currently working in. Naming and lifecycle in [WORKTREES.md](WORKTREES.md).
- `references/`: read-only shelves of roles and skills imported from other gardens. Browsed by the liaison when a user prompt has no obvious fit in the active library, never auto-loaded by subagents. See [references/README.md](references/README.md).

Files are named `AGENT.md` / `SKILL.md` / `COMMON.md` (not `CLAUDE.md`) on purpose: we do **not** want Claude Code to auto-load them into a subagent's context. They are loaded explicitly by the dispatched subagent.

## Dispatch contract

The liaison dispatches subagents via the `Agent` tool. To keep the subagent's context lean, the dispatch prompt should:

1. Name the role.
2. Name the worktree path (absolute, under `<garden-root>/worktrees/...`).
3. Name the upstream repo (`owner/name`).
4. State the task in one or two sentences.
5. Tell the subagent to read `roles/COMMON.md` and then `roles/<role>/AGENT.md` first, and to load skills only on demand.

Roles never inline skill bodies; they reference them by path. Skills are read just-in-time. The liaison itself rarely reads a skill body; it trusts the role to know which playbook to consult.

### Dispatch prompt template

```
You are a subagent operating as role=<role>
in worktree=<absolute path>, repo=<owner/name>.

Read these in order, then act:
  1. /Users/kris/garden/roles/COMMON.md       (standing instructions)
  2. /Users/kris/garden/roles/<role>/AGENT.md (your role)
  3. skills referenced by your role, only as you need them.

Task: <one or two sentences>.
Report: <what to return to the liaison>.
```

For long-lived monitoring or recurring work, dispatch via `/loop` or a cron routine; the role file specifies any per-tick state directory the subagent should use, and every tick is recorded in the journal.

## Adding a role

Create `roles/<name>/AGENT.md`. Sections: purpose (one line), skills (linked list), operating norms, definition of done. Role files do not repeat anything in `roles/COMMON.md`.

## Adding a skill

Create `skills/<name>/SKILL.md`. Sections: purpose, inputs, state (if any), procedure, output shape, notes.

## Current inventory

- Roles: `liaison`, `steward`, `monitor`, `boatman`
- Skills: `journal-sync`, `self-improvement`, `em-dash-style`, `relative-paths`, `github-activity-poll`, `pr-ci-watch`

The `liaison` and `steward` are the two top-level orchestrator postures. When a user is in the loop (this terminal session), the liaison runs with excess authority and asks before acting. When the garden runs in the bot sandbox under safe bot credentials with no user present, the steward runs with bounded authority and may act on its own. See `roles/liaison/AGENT.md` § Posture and `roles/steward/AGENT.md` § Posture for the contract.
