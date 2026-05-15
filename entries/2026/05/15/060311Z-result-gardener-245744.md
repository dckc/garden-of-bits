---
ts: 2026-05-15T06:03:11Z
kind: result
role: gardener
project: dctinybrain-jesc24
refs:
  - entries/2026/05/15/060311Z-dispatch-liaison-<dispatch-ref>.md
---

Encoded the Coq build environment lesson from dctinybrain/jesc24 PR #1.

## Files created/modified

**Journal (project context):**
- `projects/dctinybrain-jesc24/README.md` -- build toolchain facts, opam switch details, repo layout, rules of engagement.

**Skill (dispatch-worktree):**
- `skills/dispatch-worktree/dispatch-prepare.sh` -- added Coq build file detection (`_CoqProject`) with warning, and a generic project-hook sourcing mechanism.
- `skills/dispatch-worktree/project-hooks/dctinybrain-jesc24.sh` -- first project hook; prints opam switch info and writes `.garden/opam-env.sh` into the dispatch root for the subagent to source.
- `skills/dispatch-worktree/SKILL.md` -- documented both additions in Notes from the field.

## Rationale

Two approaches in one, per the dispatch instruction:

1. **Coq warning (simple approach)**: `dispatch-prepare.sh` detects `_CoqProject` in the project root and prints a reminder to run `eval $(opam env)`. Catches the generic case for any Coq project without needing a per-project hook.

2. **Project hooks (extensible approach)**: a `project-hooks/<owner>-<repo>.sh` file is sourced by `dispatch-prepare.sh` when a matching project worktree is created. The hook runs in a subshell and can print warnings, write files to the dispatch root, or validate the environment. The dctinybrain-jesc24 hook writes `.garden/opam-env.sh` so the subagent has the exact `opam switch` and `eval $(opam env)` commands ready.

The hook mechanism is project-agnostic; future projects with unusual build environment requirements add their own hook file without further dispatch-prepare.sh changes.

Self-improvement: projects/dctinybrain-jesc24/README.md, skills/dispatch-worktree/dispatch-prepare.sh, skills/dispatch-worktree/project-hooks/dctinybrain-jesc24.sh, skills/dispatch-worktree/SKILL.md; encoded the opam env lesson so fixers dispatched against Coq projects remember to eval $(opam env) before coqc.
