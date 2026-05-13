---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: benchmark-comparative-report

Adopted from `references/endo-but-for-bots/skills/benchmark-comparative-report.md`.

A comparative microbenchmark report needs four parts: test bed, methodology, numbers, caveats.

## Shape

1. **Test bed disclosure**: CPU model, RAM, OS, Node (or runtime) version, architecture, harness file path. Without this, ratios are reproducible but absolute numbers are not.
2. **Methodology**: workloads, iteration counts, warm-up calls, number of independent process launches, statistic reported (median, mean, etc.).
3. **Numbers**: a small markdown table of throughput per condition, with a derived speedup-ratio column where relevant.
4. **Caveats**: noise sources, what the ratio is measuring vs. what it is *not* measuring.

## Why a ratio, not absolutes

CI runners and developer workstations are noisy benchmark environments. Absolute numbers carry significant per-run spread; the ratio of two implementations is much more stable, *provided* they share warm-up, allocation pattern, and call-site shape.

Acknowledge this in the report: "the test bed is a developer workstation, not an isolated performance lab; absolute numbers carry meaningful noise (±15% on the bulk-bytes workload across 10 runs); the X/Y ratio is more stable, since both implementations share warm-up, allocation, and call-site shape."

## Workload structure

Run multiple workloads, not just one. Different bottlenecks surface at different scales (inner-loop throughput, per-call overhead, rejection rates at distribution boundaries). When the inner-loop ratio doesn't match the per-call ratio, the gap tells you where the fixed costs live.

## Naive expectation vs measured

Always state the naive expectation and explain why the measured ratio differs. A 20/12 cipher-round ratio suggests 1.67x; if measured ratios cluster at 1.3x, the gap is per-block fixed costs (state init, finalization, the conversion arithmetic) which are identical between the two and dilute the inner-loop savings.

## Posting

Post the report as a PR comment via `gh pr comment <N> --body "$(cat BENCH.md)"`. Keep under ~700 words; large benchmark dumps are noisy. Reference a `BENCH.md` file in-repo for full methodology if it grows.

## Pitfalls

- **Don't compare numbers from different machines** without restating the test bed for each.
- **Don't report mean over a small sample.** Outliers dominate. Use median over ≥10 runs, each a fresh process launch.
- **Stay in scope.** A PRNG ratio is not a cipher recommendation. State the trade-off as what was measured, not as a generalised endorsement.

## Authorization note

Posting on an upstream PR requires explicit per-action authorization in the dispatch prompt. See `roles/COMMON.md` § External-repo etiquette.

## Notes from the field

- _2026-05-13_: adopted from the reference.
