---
ts: 2026-05-15T11:11:16Z
kind: result
role: scout
project: dctinybrain/jesc24
refs:
  - entries/2026/05/15/11*Z-dispatch-scout-jesc24-verify.md
---
# Result: scout — probe jesc24 Nix build

build_success: false
build_host: yolo1
key_output: |
  COQC theories/prelude/collections.v
  Error: Can't open ./theories/prelude/collections.vo
  make[2]: *** [Makefile.coq:663: theories/prelude/collections.vo] Error 1

findings: |
  Build fails on a *missing* collections.vo, not a stale one.
  The .vo file does not exist on disk — the issue is a dependency
  ordering problem in the generated Makefile.coq, not a stale artifact.
  Pre-existing .vo files had been cleaned before this run.
