---
ts: 2026-05-20T03:15:00Z
kind: dispatch
role: fixer
project: dctinybrain/jesc24
short-id: 2f533e
---

# Dispatch: fixer eliminates duplicate CI builds (issue #12)

The jesc24 CI workflow (`.github/workflows/ci.yml`) triggers on both `push` and `pull_request` events. When a PR is opened or updated, this causes 3 redundant runs: one for the push event and two for pull_request events (because multiple PRs share the same branch). This wastes CI minutes and clutters the checks UI.

Task: Modify the CI workflow to eliminate duplicate builds. The simplest fix is to remove the `push` trigger since PRs already trigger `pull_request` events. If push-only builds are needed (e.g. for direct pushes to main), add a condition to skip the workflow when the push is to a branch with an open PR.

## Report:
- What was changed in the CI workflow
- Evidence that duplicate builds are eliminated
- PR opened against dctinybrain/jesc24 main branch
