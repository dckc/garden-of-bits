---
ts: 2026-05-15T05:07:32Z
kind: dispatch
role: liaison
to: gardener
refs:
  - conversation with user 2026-05-15
---

# Dispatch: gardener designs opencode agent configs for garden roles

Dispatch root: `dispatches/gardener--04de64/`.

Task: The garden's role files (AGENT.md under `roles/`) map to opencode's agent
concept. Design and create opencode agent configuration for the garden's roles,
starting with liaison and steward. Settle the form: should we use an
OPENCODE.md convention file (parallel to CLAUDE.md), an AGENTS.md file
(following garden naming convention), opencode.json + .opencode/agents/ files,
or a hybrid? Consult the garden's CLAUDE.md § Opencode adaptation, the naming
conventions in CLAUDE.md § Layout (files named AGENT.md / SKILL.md / COMMON.md
on purpose), the existing role files for liaison and steward, and the
customize-opencode skill (loaded via the skill tool) for the opencode agent
schema. Deliverable: the recommended file layout AND the created config files.

Report: the chosen file layout, what each file contains, and the rationale for
the form.
