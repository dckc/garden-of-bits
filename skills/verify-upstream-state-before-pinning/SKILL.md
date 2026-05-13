---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: verify-upstream-state-before-pinning

Adopted from `references/endo-but-for-bots/skills/verify-upstream-state-before-pinning.md`.

## Trigger

A reviewer or dispatch prompt asks to pin an external dependency to a specific version, capture a sha256, or embed metadata about an upstream artifact.

## Why

Dispatching prompts and reviewer suggestions often quote a version or release date the agent guessed from training data, not from a fresh fetch of the upstream. The guess is frequently months stale. Committing the guess ships wrong metadata in workflow comments and can silently mismatch a download cache.

## What to do

1. Fetch the upstream's directory listing or release page yourself. `curl`, `gh release list`, or the project's downloads index, depending on the source.
2. Read the actual current release: name, date, URL, sha256.
3. Compute the sha256 from a fresh download (`curl -fsSL <url> | sha256sum`); do not trust a sha256 from elsewhere.
4. Embed the version and sha256 as workflow-level env vars so a future bump is a two-line change.
5. Key any download cache by both the version *and* the sha256 so a stale blob cannot shadow a version bump.
6. Cite the verification source in the commit message body (the directory listing URL, the release page).

## Notes from the field

- _2026-05-13_: adopted from the reference.
