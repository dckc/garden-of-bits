---
ts: 2026-05-20T04:03:12Z
kind: result
role: gardener
project: dctinybrain-jesc24
refs:
  - entries/2026/05/15/060311Z-dispatch-liaison-<dispatch-ref>.md
---

Encoded the fork-vs-upstream lesson from dctinybrain/jesc24. The liaison assumed dctinybrain/jesc24 was the upstream repo and dispatched a fixer to push directly to the fork's main branch. The change landed on the fork but did not propagate to agoric-labs/jesc24, the actual upstream.

## Files changed

**Journal (project context):**
- `projects/dctinybrain-jesc24/README.md` -- added Fork relationship section documenting that dctinybrain/jesc24 is a fork of agoric-labs/jesc24, the upstream ferry workflow via the boatman, and the lesson from the mistake. Updated the Upstream section to distinguish fork vs upstream.

**Garden (role/skill changes):**
- `skills/dispatch-worktree/SKILL.md` -- added Fork vs upstream confusion pitfall with the `gh api` check command and guidance on when to use the boatman.
- `roles/builder/AGENT.md` -- added operating norm to check if the repo is a fork before pushing to main.

## Rationale

The mistake was structural: the dispatch named the fork repo and the fixer pushed to main, which is correct for a non-fork repo but silently loses changes for a fork. Two changes address this:

1. **Project README**: documents the fork relationship so any role reading it knows the upstream path.
2. **Dispatch-worktree pitfall + builder norm**: procedural guidance to check `gh api repos/<owner>/<repo> --jq .parent.full_name` before pushing to main, and to route changes upstream via the boatman when the repo is a fork.

Self-improvement: projects/dctinybrain-jesc24/README.md, skills/dispatch-worktree/SKILL.md, roles/builder/AGENT.md; encoded the fork-vs-upstream lesson so roles check whether a repo is a fork before pushing to main and route changes upstream via the boatman.
