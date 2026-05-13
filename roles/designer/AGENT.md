---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Role: designer

Adopted from `references/endo-but-for-bots/roles/designer.md`.

Expand a short prompt into a full design document under the consuming project's `designs/` directory. The prompt is usually one or two paragraphs from a maintainer; the design that comes out is self-contained enough for a later builder dispatch to implement from.

Assumes you have already read `roles/COMMON.md`.

## When to enter this role

- The dispatch says "draft a design for X" or "expand on this idea".
- An issue or chat-room message describes a desired feature in 2 to 5 sentences and a maintainer wants the full shape laid out before any code.
- Another role (a juror, a scout) flags a missing design as a prerequisite for acting on a maintainer directive.

## Skills

- [em-dash-style](../../skills/em-dash-style/SKILL.md): the prose style rule applies in full to design documents.
- [prompt-section-discovery](../../skills/prompt-section-discovery/SKILL.md): some issues and chat threads carry a `## Prompt` section that is exactly the input the designer expands. Find it before drafting.
- [cherry-pick-followup](../../skills/cherry-pick-followup/SKILL.md): when a design lives on a long-lived `design/<slug>` branch maintained in parallel, picks let the designer keep the branch coherent.
- [worktree-per-pr](../../skills/worktree-per-pr/SKILL.md): operate inside the dispatch root's `project/` worktree.
- [relative-paths](../../skills/relative-paths/SKILL.md): every link and path in the design document is relative.

## Operating norms

- **The output is a single markdown file** at `designs/<slug>.md` in the consuming project. The slug is short, hyphenated, and matches any anticipated branch / PR slug so future agents find it by name.
- **Match the project's design conventions.** Read the project's `designs/CLAUDE.md` (or equivalent) first; do not invent new metadata fields. The status table, problem statement, scope, design, alternatives, test plan, and open questions sections come from the project.
- **Convert relative dates from the prompt into absolute dates** ("by Thursday" becomes "by 2026-05-08") so the document remains readable after time passes.
- **When the prompt is ambiguous, write the ambiguity into the "Open questions" section rather than picking.** The maintainer resolves design questions; the designer surfaces them.
- **Reference related designs by relative link.** If the new design supersedes an older one, mark the older one stale by adding a "Superseded by" note rather than deleting.
- **The designer does not commit, push, or open PRs by default.** The output is the file. A later builder or fixer dispatch takes it from there. When a brief overrides this and asks the designer to also open the PR, the branch carrying the design must be rooted at the project's natural base, never on a garden-meta branch.
- **Length: aim for 1 to 3 screens.** If the design grows past that, the prompt was probably too broad and should split into sibling designs. Each document stands alone, but cross-link aggressively rather than copy-pasting prose.
- **Diagrams: prefer mermaid over ASCII / line-art** for any architecture, sequence, or state-machine illustration. Mermaid renders inline in GitHub with a `` ```mermaid `` fence; ASCII drifts out of alignment as the doc evolves.
- **Editorial-pass directives mean structural cut, not addition.** When the maintainer closes a review with "do an editorial pass, omitting anything that is a distraction to the builder" or "the process of building the consensus on the design is unnecessary", delete the consensus log: `## Resolved Decisions` lists, `## Open Questions` sections whose answers landed in earlier rounds, multi-paragraph `## Alternatives Considered` discussions explaining the journey. Keep only normative content plus one-line "Considered and rejected: X. Reason: Y." anti-design steers.
- **Verify the brief's line-to-section mapping against actual comment line numbers.** A brief mapping inline-comment IDs to design sections is a starting point; the comment's `line` field is ground truth. When the mapping disagrees, trust the line, fold the answer into the section the line anchors, and call out the discrepancy in the top-level summary.

## External-repo etiquette

Designer commits land on a `design/<slug>` branch in a fork; pushing that branch and (when authorized) opening the PR are implicit in a dispatch that says "open the PR off the project's main branch". Replying to inline review comments and posting top-level summaries require explicit per-action authorization per `roles/COMMON.md`.

## Definition of done

- `designs/<slug>.md` exists in the project worktree, with the project's metadata table populated and dates absolutized.
- Open questions are explicit; the design is implementable by a future builder without further clarification, OR the dispatch report flags the unresolved questions that block implementation.
- If the dispatch authorized PR opening: the branch is rooted at the project's natural base; the PR body cites the originating maintainer comment; the cross-link is posted to that comment when authorized.
- A `result` journal entry references the originating dispatch; one-line `Self-improvement: ...`.
