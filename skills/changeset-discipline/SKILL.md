---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: changeset-discipline

Adopted from `references/endo-but-for-bots/skills/changeset-discipline.md`.

A changeset (e.g., `@changesets/cli`'s `.changeset/<adjective-noun-thing>.md`) is written only when the change is user-observable.

## When to write one

- A new exported API.
- A change in observable behavior of an existing exported API.
- A bug fix the user could have noticed.
- A breaking change (removed export, changed signature, stricter validation).
- A migration step the user must perform on upgrade.

## When not to

Skip entirely (don't write a "no-op" entry) if all of:

- The change does not enable the user to do anything new.
- The change does not obligate the user to perform any migration.
- The user could not detect the change by reading the package's documentation, signatures, or behavior.

Examples that do *not* need a changeset: removing an unused devDependency; moving tests into a sibling synthetic test package; renaming an internal-only file under `src/`; adding a private internal subpath gated by a test export condition; refactoring a fixture; updating a comment, JSDoc, or README that describes already-existing behavior; CI workflow tweaks; build- or lint-only changes.

A noisy changelog full of "removed unused devDep" or "moved tests" entries trains downstream consumers to ignore the changelog, which makes the genuinely user-facing entries harder to notice.

## When in doubt, ask

A changeset is easier to add than to remove (after publish, the entry ships forever). When unsure, ask the maintainer in the PR description rather than defaulting to writing one. The PR description's `[Documentation]` line should say "no changeset (internal hygiene)" when omission is deliberate.

## Notes from the field

- _2026-05-13_: adopted from the reference. The project-specific origin (kriskowal on PR #209 / #210) was dropped; the discipline applies wherever Changesets is in use. Per-project conventions (the file path under `.changeset/`, the YAML front-matter shape) belong in a journal entry tagged with the relevant project slug.
