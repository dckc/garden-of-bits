---
ts: 2026-05-20T04:06:45Z
kind: result
role: gardener
project: jesc24
refs: []
---

# Result: encode lesson about jesc24 fork/upstream confusion

## What happened

The liaison assumed `dctinybrain/jesc24` was the upstream repo and dispatched a fixer to push directly to the fork's `main` branch. The fix landed on the fork but did not propagate to the true upstream (`agoric-labs/jesc24`).

## Changes made

### Journal (commit `f6bd1ab` on journal branch)

- `journal/projects/dctinybrain-jesc24/README.md`: added **Fork relationship** section at the top, clearly stating this is a fork of `agoric-labs/jesc24`, that changes pushed to the fork's `main` do not propagate upstream, and that the boatman (or a direct PR to `agoric-labs/jesc24`) is the correct route for ferrying changes upstream. Updated the **Upstream** section to remove redundant fork/upstream URLs and point to the boatman workflow.

### Garden main (commit `8a021e3` on main branch)

- `skills/dispatch-worktree/SKILL.md`: added **Fork vs upstream confusion** pitfall to the Pitfalls section, with the `gh api repos/<owner>/<repo> --jq .parent.full_name` check recipe. Added a dated note from the field documenting the incident.
- `roles/fixer/AGENT.md`: added **Fork awareness** section warning that pushing to a fork's `main` does not propagate upstream, and directing the fixer to confirm upstream ferrying with the orchestrator when the dispatch targets `main` on a fork.
- `roles/builder/AGENT.md`: added **Fork awareness** section with the same guidance, plus an operating norm bullet: check fork status before pushing to main.

## Roles/skills considered for update

- **fixer**: added Fork awareness section.
- **builder**: added Fork awareness section and operating norm bullet.
- **dispatch-worktree skill**: added pitfall and note from the field.
- **boatman**: no changes needed; its role already covers ferrying changes upstream.
- **liaison**: no role file change; the lesson is captured in the project README and the dispatch-worktree pitfall so future orchestrator reads surface the fork check.

Self-improvement: `skills/dispatch-worktree/SKILL.md`, `roles/fixer/AGENT.md`, `roles/builder/AGENT.md`, `journal/projects/dctinybrain-jesc24/README.md`; added fork-awareness guidance to prevent pushing changes to a fork's main branch without ferrying them upstream.
