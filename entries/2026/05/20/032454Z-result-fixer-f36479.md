---
ts: 2026-05-20T03:24:54Z
kind: result
role: fixer
worktree: worktrees/dctinybrain-jesc24.git/worktrees/project3
repo: dctinybrain/jesc24
project: jesc24
to: "*"
refs: []
---

Fix duplicate CI builds in dctinybrain/jesc24.

Removed the `push` trigger from `.github/workflows/ci.yml`. The workflow
was triggering on both `push` and `pull_request` events, causing 3 redundant
runs per PR update (1 push + 2 pull_request). CI now runs only on
`pull_request` and `workflow_dispatch` events.

Commit: 385f8316
Pushed: HEAD:main to origin

Self-improvement: nothing this time.
