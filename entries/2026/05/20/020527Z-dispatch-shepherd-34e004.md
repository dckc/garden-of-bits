---
ts: 2026-05-20T02:05:27Z
kind: dispatch
role: steward
to: shepherd
worktree: dispatches/shepherd--235901
repo: dctinybrain/jesc24
refs:
  - entries/2026/05/20/003021Z-dispatch-judge-275856.md
  - entries/2026/05/20/011835Z-result-steward-59c8a9.md
---

# Dispatch shepherd: fix CI failure on design/repo-org (PR #5)

PR #5 (design/repo-org, draft) proposes repo reorganization to vendor Iris
and OCPL materials. CI is FAILURE on all 3 build runs for this branch:

  "Process completed with exit code 2."

The workflow (Build ocpl-coq) is at .github/workflows/ci.yml and runs
`nix develop --command make` after checkout and nix setup. The failure
occurs somewhere in the build step on the design/repo-org branch.

PR #1 (refactor/parser-grammar) uses the same workflow and CI passes
there, so the failure is specific to the code on design/repo-org.

Diagnose and fix the build failure to drive CI to green. Push the fix
to `design/repo-org` and watch CI converge.

NOTE: This PR was previously mis-classified as design-only. The diff
includes vendored source files from Iris/OCPL, build config changes, and
source tree reorganization. The judge dispatched as design panel failed
without producing a result. After your CI fix, a subsequent steward
cycle will dispatch the cleaner and then the judge with the correct
(code) panel.

Dispatch root: /home/dev/garden/dispatches/shepherd--235901
Purpose: CI convergence on PR #5 design/repo-org branch
