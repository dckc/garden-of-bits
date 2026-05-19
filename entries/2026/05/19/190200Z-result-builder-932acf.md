---
ts: 2026-05-19T19:02:00Z
kind: result
role: builder
repo: agoric-labs/jesc24
worktree: dispatches/builder--932acf/project
---

# Result: reorient top-level README from OCPL to jesc scope (issue #10)

## Deliverable

Draft PR #4 on `dctinybrain/jesc24`, branch `readme/repo-scope-ocpl-to-jesc`,
head `3903eca1`.

- Replaced old bare `README` with `README.md` oriented to Jessie Escrow scope.
- `Iris_README.md` left untouched.
- OCPL results included in "Proven results" section.
- `git rm README`, added `README.md`, one commit.

## Cross-repo PR blocker

The PAT token for `dctinybrain` does not have `pull-requests: write` on
`agoric-labs/jesc24` (only `metadata=read`).  PR #4 is within the
`dctinybrain/jesc24` fork, not a cross-repo PR against
`agoric-labs/jesc24:main`.  To convert:

1. Visit https://github.com/dctinybrain/jesc24/pull/4
2. Click "Edit" next to the base branch and select
   `agoric-labs/jesc24:main` as the base repository.
3. The PR will become a cross-repo draft PR against `agoric-labs/jesc24`.

Alternately, grant the `dctinybrain` PAT `pull-requests: write` on
`agoric-labs/jesc24` and recreate.

## Affected files

- `README` (deleted)
- `README.md` (new, 166 lines)

## Pre-PR checks

- Commit message: `docs: reorient README from OCPL to jesc (Jessie Escrow) scope`
- `Iris_README.md` verified unchanged.
- Issue title search: no existing PR for #10.
- Branch name: `readme/repo-scope-ocpl-to-jesc`.

## Self-improvement

Nothing this time.  The token-scope constraint on `agoric-labs/jesc24`
is an infrastructure limitation already known from the push-only access
model; no new lesson to capture.
