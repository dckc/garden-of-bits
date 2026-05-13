---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: dependency-graph-maintenance

Adopted from `references/endo-but-for-bots/skills/dependency-graph-maintenance.md`.

Keep a project's design dependency graph (the Mermaid block in `designs/README.md` § "Dependency Graph") consistent with the design files. Used by the [groom](../../roles/groom/AGENT.md) when reconciling roadmap structure.

## When to use

When grooming `designs/README.md` § "Dependency Graph", or when a new design enters the corpus and its relationships need to be threaded into the existing Mermaid graph.

## Inputs

- The current Mermaid block in `designs/README.md` § "Dependency Graph".
- Each design file's "Dependencies" section (if present), which lists prerequisite designs by relative path.
- The project's PR-mirror or merge log for cross-referencing whether prerequisite designs have already shipped.

## Procedure

1. **Enumerate edges from the design files.** For each design with a "Dependencies" section, parse the relative-path links and build an adjacency list `(this-design, prerequisite)`.
2. **Diff against the Mermaid graph.** Edges in the design files but missing from the graph need to be added. Edges in the graph but missing from any design file are suspect: either the design omitted documenting the dep, or the dep is wrong. Open a question for the maintainer rather than guessing.
3. **Reconcile transitively-completed prerequisites.** A design whose only remaining prerequisite is `**Complete**` can move from "blocked" to "ready" in any project board the team uses; the graph itself does not change but the README narrative may.
4. **Detect cycles.** Run a topological sort over the adjacency list. A cycle is a real bug in either the design files or the graph; surface it as an open question.
5. **Update the Mermaid block.** Insert new nodes alphabetically within their milestone subsection. Insert edges as `prereq --> this`. Use `:::done` style hints for completed designs only if the existing graph already does.

## Output

A diff to the Mermaid block. Plus, for every divergence between design files and the graph, an entry in the open-questions note per `skills/groom-open-questions/SKILL.md`.

## Pitfalls

- **The Mermaid graph is large** (≈100 nodes in a mature project); a syntactically broken edit breaks rendering for the whole graph. Render locally before committing.
- **Do not use redundant node IDs.** Mermaid silently merges same-named nodes from different subgraphs. Prefix node IDs by milestone (e.g. `m2_ocapn_noise_network`).
- **"Soft" dependencies** (e.g., "this works better after X" but does not strictly require X) should not be edges. Keep the graph to hard prerequisites; flexibility lives in the milestone ordering, not in graph edges.
- **A design reordered between milestones may need its edges re-classified.** Check whether the target milestone of the prerequisite is still earlier than this design's milestone.

## Notes from the field

- _2026-05-13_: adopted from the reference. No structural changes; the procedure was already project-agnostic.
