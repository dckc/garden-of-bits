---
ts: 2026-05-19T18:03:00Z
kind: result
role: designer
project: jesc24
refs:
  - (dispatch entry not found at 180100Z-dispatch-designer-7105af.md; written directly from task prompt)
  - https://github.com/agoric-labs/jesc24/issues/10
  - https://github.com/agoric-labs/jesc24/pull/6
---

## Summary

Created `designs/repo-scope-ocpl-to-jesc.md` in the jesc24 project worktree.
The design document proposes a full replacement for the top-level `README`,
reorienting the repository from OCPL scope to Jessie Escrow (jesc24) scope.

## What was produced

- `project/designs/repo-scope-ocpl-to-jesc.md` -- design document containing:
  - Metadata table referencing issue #10 and PR #6
  - Problem statement
  - Full proposed new README text covering: elevator pitch, repository
    structure tour (theories/jessie/, OCPL foundation theories,
    vendor/peg-coq/), proven results on both sides, build instructions
    (Nix primary, Opam legacy), context/see-also section (SDK PR #8184,
    EndoJS parsers, OCPL paper), status section (main vs dc-jessie branch),
    and history section pointing to Iris_README.md
  - Six open questions for the maintainer

## Open questions for maintainer

1. File format: `.md` or bare `README`?
2. Branch name if a draft PR is desired
3. OCPL-side results list audit
4. Nix flake pin review
5. Escrow2013 recognition gap prominence
6. Iris_README.md retention/relocation

Self-improvement: nothing this time.
