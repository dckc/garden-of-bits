---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: regression-evidence

Adopted from `references/endo-but-for-bots/skills/regression-evidence.md`.

Every new test should be proven load-bearing by demonstrating that it fails when the code path it exercises is broken. A test that passes whether or not the implementation is correct is not a regression test.

## Procedure

After committing a new test:

1. Temporarily break the smallest unit of the code path the test covers. Examples:
   - For a new lint rule, comment out a branch and confirm an `invalid` fixture fires differently.
   - For a new visitor, mis-assign one intrinsic and confirm the test fails with a clear name.
   - For a new diagnostic, remove the new check and confirm the test fails with the old cryptic error.
2. Run the test. It must fail with a recognizable message.
3. Revert the temporary break (`git stash pop` is cleanest).
4. Run the test again. It must pass.
5. Cite the experiment in the PR body or summary as "regression-test note": describe the break, the observed failure, and the revert.

## Why

This catches three classes of mistake:

- A test asserting something already trivially true (e.g. reflexive identity) that never exercises the new code path.
- A test that depends on a side effect of another test, so removing the new code makes the *other* test fail first.
- A test that uses a fixture covering a pattern the new code doesn't actually handle.

## Pitfalls

- **Make the temporary break small and reversible.** `git stash` before the change makes revert mechanical.
- **Property-based tests** need a different demonstration: shrink the property to deterministically exercise the boundary, or seed the generator.
- **"Existing test already covers this area" is not regression-tested.** Async iterators have several teardown shapes (resolution-done, resolution-not-done from a sink intending to stay open, rejection mid-stream, upstream-driven `throw`). A test exercising one shape will not catch a regression on another. When borrowing an existing test as regression posture, name which shape it covers and confirm the fix's failure mode matches.

## Notes from the field

- _2026-05-13_: adopted from the reference. Per-PR session lore lives in the journal.
