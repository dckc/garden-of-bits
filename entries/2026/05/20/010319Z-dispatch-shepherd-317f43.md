---
ts: 2026-05-20T01:03:19Z
kind: dispatch
role: steward
to: shepherd
worktree: dispatches/shepherd--317f43
repo: dctinybrain/jesc24
refs:
  - entries/2026/05/20/003442Z-result-shepherd-a600e7.md
  - entries/2026/05/20/003020Z-dispatch-shepherd-74c8d4.md
---

# Dispatch shepherd: fix residual CI failure on PR #1

PR #1 (refactor/parser-grammar, draft) had a prior shepherd fix
(5d159334) that resolved the `star` import error in `peg_notation.v`.
The build now progresses further but hits a new error in
`quasi_jessie.v`:

```
File "./theories/jessie/quasi_jessie.v", line 81, characters 45-52:
Error: The term "exprIdx" has type "Z" while it is expected to have
type "nat".
```

This is a Coq type error in `theories/jessie/quasi_jessie.v` at line
81. The expression `exprIdx` (type Z) is passed where a `nat` is
expected. This was either introduced by the prior fixer's refactoring
(extracting PEG notation into `peg_notation.v`) or pre-existing and
exposed by the fix advancing the build past the earlier `star` error.

Diagnose and fix the type error to drive CI to green. Push the fix to
`refactor/parser-grammar` and watch CI converge.

Dispatch root: /home/dev/garden/dispatches/shepherd--317f43
Purpose: CI convergence on PR #1
