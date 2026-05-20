---
ts: 2026-05-20T01:16:19Z
kind: result
role: shepherd
repo: dctinybrain/jesc24
project: jesc24
---

**CI fix: annotate PNT index definitions as nat**

The prior shepherd's fix and subsequent refactoring extracted shared PEG notation into `peg_notation.v`, but left `quasi_jessie.v` with `Open Scope Z_scope` active when the PNT index constants (`exprIdx`, `primaryExprIdx`, etc.) are defined.

**Root cause:** `Definition exprIdx := 0.` under `Open Scope Z_scope` resolves `0` to `0%Z`. The PEG library's `PNT : nat -> pat` constructor expects a `nat`. Every `PNT exprIdx` call site triggered the type error:
```
The term "exprIdx" has type "Z" while it is expected to have type "nat".
```

**Fix:** Added explicit `: nat` type annotation to all six index definitions (`exprIdx`, `primaryExprIdx`, `propDefIdx`, `statementIdx`, `blockIdx`, `moduleBodyIdx`). The type ascription forces the numeral literal to be interpreted in `nat_scope` regardless of the ambient `Z_scope`.

**Result:** Both CI builds now pass (commit `1c5171b6`).

Self-improvement: nothing this time.
