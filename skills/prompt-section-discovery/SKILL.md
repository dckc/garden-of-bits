---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: prompt-section-discovery

Adopted from `references/endo-but-for-bots/skills/prompt-section-discovery.md`.

When investigating a directory of issue mirrors, design documents, or transcripts, search for embedded meta-instructions (the `## Prompt` convention) that a follow-up agent is meant to read.

## How

```sh
grep -lE "^## Prompt$" issues/*.md
grep -nE "^## Prompt$" issues/*.md -A 5 | head -40
```

Treat the body of each `## Prompt` section as a directive from the maintainer.

## Pitfalls

- **Prose use of "Prompt"** in commentary is not a directive. Use the anchored regex `^## Prompt$` to avoid false positives.
- **Editor casing variants.** A case-insensitive variant catches lowercase: `grep -iE "^## prompt$"`.
- **The convention is project-specific.** In other codebases the marker might be `## Instructions`, `## Action`, or a YAML front-matter key. Check repository conventions first.

## Notes from the field

- _2026-05-13_: adopted from the reference. The "fill in the blank" and "explicit dispatch" examples were dropped; project-specific examples are recoverable from the journal.
