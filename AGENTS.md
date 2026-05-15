---
created: 2026-05-15
updated: 2026-05-15
author: gardener
---

# Garden agents for opencode

The garden's role files at `roles/<name>/AGENT.md` are the authoritative
operating instructions for each role. The opencode agent definitions under
`.opencode/agents/` wrap those role files with opencode-specific config
(mode, permission, model).

## Default agent

The `liaison` is the default primary agent. When you run opencode in the
garden root, you are the liaison. Read `roles/liaison/AGENT.md` for the
full operating instructions.

## Subagent dispatch

Use the `Task` tool to dispatch subordinate roles. The garden creates a
per-dispatch worktree triple per `skills/dispatch-worktree/SKILL.md`. The
dispatch prompt names the role, the dispatch root, and the task.

## Skills

Garden skills are registered via `skills.paths: ["skills"]` in
`opencode.json`. Load a skill with the `skill` tool when a task matches its
description.

## Permissions

- liaison (primary): excess authority; ask before acting.
- steward (subagent): bounded authority; edit denied for roles, skills,
  and top-level docs.

## References

- `CLAUDE.md`: garden layout and dispatch contract.
- `WORKTREES.md`: worktree lifecycle.
- `roles/COMMON.md`: standing instructions for all subagents.
- `roles/<name>/AGENT.md`: role-specific instructions.
