---
ts: 2026-05-20T06:36:10Z
kind: tick
role: monitor
repo: dctinybrain/jesc24
project: jesc24
---

**PR #7 opened**: "chore: move Iris/OCPL materials to vendor/iris-coq/" by dctinybrain at 04:42:55Z on feat/vendor-iris-coq branch. 

**Scope**: Organizational refactor moving 172 files (171 additions, 171 deletions). Moves Iris/OCPL Coq materials (`theories/`, `docs/`, `Iris_README.md`, `ProofMode.md`, etc.) into `vendor/iris-coq/` directory with updated `_CoqProject` and `README` path references. No Coq source code changes, logical path `iris` preserved.

**Status**: Draft PR with 2 successful CI runs completed. References design from PR #5 (designs/repo-org-vendor-iris-ocpl.md).

**Routing**: Per skills/monitor-dctinybrain-jesc24 § PullRequestEvent/opened by non-garden actor → surface-bulletin under "New PRs to triage". This is routine structural reorganization requiring review.