---
ts: 2026-05-17T03:05:00Z
kind: dispatch
role: steward
to: fixer
project: jesc24
worktree: dispatches/fixer--131649
repo: dctinybrain/jesc24
refs:
  - entries/2026/05/17/020751Z-dispatch-steward-8ecdc7.md
  - entries/2026/05/17/020900Z-result-steward-8ecdc7.md
---

# Dispatch fixer: address dckc's latest review comments on PR #1 (round 2)

dckc reviewed the latest PR state (commit 58837d5a) and left 4 substantive
unresolved inline comments after resolving earlier threads (02:42-02:46Z).
The comments span quasi_json.v and quasi_jessie.v.

dckc's unresolved comments:

1. **quasi_jessie.v line 183** (02:50:30Z): "ah. now I understand PNT better.
   In this `grammar` definition, change these back to..." with a code
   suggestion proposing `(* 0 expr ... *)` comments for grammar entries.

2. **quasi_json.v line 82** (02:53:53Z): "use section instead of ascii art as
   discussed" -- the file still uses ASCII-art comment headers.

3. **quasi_json.v line 85** (02:55:24Z): code suggestion to change a comment
   to `(* These token patterns come from quasi-json.js.ts. *)`. The current
   comment references higher-layer concepts the JSON file should not know
   about.

4. **quasi_json.v line 78** (02:58:29Z): "refactor this file to use the same
   style as discussed for `quasi_jessie.v`. Feel free to make a
   `peg_notation.v` file for the `JessiePegNotation` goodies. Refactor
   `quasi_justin.v` too. All 3 files should use the same style."

Also note: CI is FAILURE (Build ocpl-coq workflow; error at quasi_json.v
line 77: "Syntax Error: Lexer: Undefined token"). This appears to be a
pre-existing build issue unrelated to the fixer's changes (makeCounter /
dc-jessie baseline has the same failure).

Forwarded authorization: dckc's substantive COMMENTED reviews and inline
comments authorize replying on each comment thread, editing the affected
source files and making a `peg_notation.v` module if appropriate, and
posting a top-level summary citing each addressing SHA.
