---
ts: 2026-05-15T05:09:00Z
kind: result
role: gardener
refs:
  - entries/2026/05/15/050732Z-dispatch-liaison-04de64.md
---

# Result: Gardener designs opencode agent config for liaison and steward

Layout recommendation: **Hybrid**.

| File | Purpose |
|---|---|
| `opencode.json` | opencode project config; default agent, instructions, skills path |
| `AGENTS.md` | conventions doc (parallel to CLAUDE.md), following garden naming pattern |
| `.opencode/agents/liaison.md` | liaison agent file (primary, user-facing) |
| `.opencode/agents/steward.md` | steward agent file (subagent, autonomous) |

Rationale: opencode.json is required for project-level opencode config.
AGENTS.md follows the garden's naming convention (AGENT.md / SKILL.md /
COMMON.md — not CLAUDE.md). Agent prompt bodies are short; they delegate to
the existing role files at `roles/<name>/AGENT.md`. Files in `.opencode/` are
an opencode convention, not a garden-named file, so they don't violate the
garden's anti-auto-load rule.

The gardener created draft contents for all four files (in the dispatch root;
not yet landed). The liaison should review with the user before committing to
main.

Self-improvement: nothing this time.
