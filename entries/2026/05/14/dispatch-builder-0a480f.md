---
ts: 2026-05-14T23:30:00Z
kind: dispatch
role: builder
project: agoric-labs/jesc24
refs:
  - issue https://github.com/agoric-labs/jesc24/issues/7
---

# Dispatch: builder — refactor parser to read like grammar

Root: `/home/connolly/projects/garden/dispatches/builder--0a480f`

Task: Refactor `theories/jessie/quasi_jessie.v` (and related files) on the
`dc-jessie` branch so the grammar definitions read like PEG notation.
Separate grammar from AST construction; factor combinators into their own
file; make the grammar the primary description of the language.

Branch: `refactor/parser-grammar` (based on `dc-jessie`)
Repo: `agoric-labs/jesc24`
