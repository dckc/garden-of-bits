---
ts: 2026-05-20T02:51:08Z
kind: dispatch
role: steward
to: cleaner
worktree: dispatches/cleaner--7fc41e
repo: dctinybrain/jesc24
refs:
  - entries/2026/05/20/024922Z-result-shepherd-e44410.md
  - entries/2026/05/20/020527Z-dispatch-shepherd-34e004.md
  - entries/2026/05/20/003021Z-dispatch-judge-275856.md
---

# Dispatch cleaner: coverage pass for PR #5 (design/repo-org)

PR #5 (design/repo-org, draft) is a builder-created PR proposing repo
reorganization to vendor Iris and OCPL materials. The overhauled files
and vendored source live under `theories/jessie/` and `vendor/`. The
shepherd fixed 3 CI failures (quasi_json.v lexer, quasi_justin.v notation,
quasi_jessie.v Z vs nat); CI is now GREEN (3/3 success at 44f29383).

This PR was previously mis-classified as design-only (judge--275856 was
dispatched as a design panel and failed). It is NOT design-only; it
touches source files and build configuration. Run the standard code-PR
cleaner pass:

1. Read the PR diff at `git diff main...HEAD` in the project worktree.
2. Identify the packages touched (primarily `theories/jessie/`).
3. Write integration tests for any reachable but unexercised surface.
4. Delete unreachable code per the four "dead code" criteria in
   skills/coverage-driven-testing/SKILL.md.
5. Push coverage commits to `design/repo-org`.
6. Watch CI converge to green on your HEAD.
7. Write a `result` entry.

IMPORTANT constraints:
- Do NOT un-draft the PR. The judge does that later.
- Do NOT comment on or close any PR or issue. Push is implicit.
- The PR is a Coq 8.9 project. Build via `nix develop --no-pure-eval`
  then `make`.

Dispatch root: /home/dev/garden/dispatches/cleaner--7fc41e
Purpose: coverage pass for PR #5 (design/repo-org)
