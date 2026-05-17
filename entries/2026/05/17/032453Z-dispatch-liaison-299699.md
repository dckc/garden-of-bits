---
ts: 2026-05-17T03:24:53Z
kind: dispatch
role: liaison
to: designer
worktree: dispatches/designer--299699
refs: []
---

# Dispatch designer: flesh out web-server visualization for garden activity

Design a spec for a web server that visualises what's happening in the garden.
The garden has a journal (`journal/entries/`), worktree index
(`journal/worktrees/<host>/`), a bulletin board (`journal/README.md`), active
PR state, and daemon monitor logs — the web server should surface all of this.

Deliverable: a design document covering data sources, architecture,
endpoints/views, and a sample visualisation. No code.
