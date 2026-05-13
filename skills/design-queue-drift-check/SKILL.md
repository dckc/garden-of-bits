---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: design-queue-drift-check

Adopted from `references/endo-but-for-bots/skills/design-queue-drift-check.md`.

Re-classify a project's `Spec'd-but-not-started` design queue (e.g. `process/DESIGNS-WITHOUT-PR.md` or its journal-mirror equivalent) so a marshal-equivalent's eligibility filter stops sending builders into walls. Used by the [groom](../../roles/groom/AGENT.md) as a lighter sub-mode that skips the full velocity / roadmap / dependency-graph procedures.

## When to use

- A marshal-equivalent returned a `needs-groom-first` outcome for the second cycle running.
- A builder dispatch surfaced a pre-flight impasse and the orchestrator asks "is the rest of the queue similarly rotted?"
- A periodic mini-pass (cheaper than a full grooming pass) is due and the maintainer has not asked for the velocity / roadmap rerun.

This is a triage pass, not a full grooming pass. It updates only the design-queue file. The full velocity, roadmap, and dependency-graph procedures from `roles/groom/AGENT.md` are explicitly skipped; those are a separate engagement.

## The two drift patterns

### Drift pattern A: design vs. later code refactor

The design's `Status: In Progress` (or its "Done" sub-items) may have been invalidated by a later commit that undid the design's premise.

Walk the design's referenced packages and `git log --oneline -- <key file>` from the design's `Updated` date forward. If a later refactor reversed any "Done" sub-item or invalidated assumptions, the design needs a designer revision before a builder can act.

Reference example: `daemon-agent-network-identity.md` claimed items 1 and 2 `*(Done)*` but a commit ~3 weeks after the design's last update explicitly removed the sentinel those items introduced. A subsequent builder dispatch surfaced this at impasse cost.

### Drift pattern B: compose-A+B+C with unsatisfied phase dependency

For designs that compose multiple capabilities, check the dependency chain at the *phase* level, not just the `Status` field. A dependency may be `In Progress` with an open PR but only ship Phase 1 of what the dependent needs.

Reference example: `endoclaw-proactive-messages.md` depended on `endoclaw-timer`. The timer PR shipped only Phase 1 (host-side `onTick`); the proactive design needed Phase 2 mail-delivered ticks (explicitly deferred in the timer design's "Not yet implemented" list). A surface-level Status check missed it.

## Procedure

1. **Stand in the dispatch's `project/` worktree.** The orchestrator prepared it on the roadmap branch.
2. **Read the queue's prior snapshot.** Note the snapshot timestamp; designs that acquired PRs since the snapshot must be removed first.
3. **Filter out designs that already have a PR.** For each entry, check the design's metadata (`Status: PR #N`) and search for any open or merged PR matching the design slug:

    ```sh
    gh pr list -R <owner>/<repo> --state all \
      --search "<slug-keywords>" --json number,state,title
    ```

    Move merged or in-flight entries to a "removed since snapshot" note in the file's intro paragraph; do not re-classify them.

4. **For each remaining design**, perform both drift checks. Keep the per-design analysis tight (1 to 3 sentences each); this is a triage pass, not a full design review.

    For drift pattern A:
    - Read the design's `## Status` section (if present) for sub-items marked "Done".
    - Identify the design's primary touched file(s) by scanning the design body for explicit file references plus any `Status: PR #N` cross-references.
    - `git log --oneline --since=<design-Updated-date> <remote>/<impl-branch> -- <file>` to spot post-design refactors that touch the same concept.
    - Sample a handful of files per design; do not exhaustively grep.

    For drift pattern B:
    - Read the design's `## Dependencies` / `## Depends On` section.
    - For each dependency, check its design file's Status and any in-flight PR's commit messages or PR body for which phase shipped.
    - If a dependency is `In Progress` with an open PR, the dependent design's pseudo-code may be calling an API the PR's actual implementation does not expose.

    Also flag **structural** misclassifications: a document framed as "ideas and directions" or as a parent index is not a single-PR target regardless of its `Status` field. Move it to `blocked-on-design-revision` (needs a focused sub-design extracted) or recommend moving it to the project's aspirational / reference group.

5. **Re-classify** each design into one of:

    - **eligible-for-builder**: both checks pass; a marshal-equivalent can dispatch a builder.
    - **blocked-on-design-revision**: drift A failed, or the document is structurally an idea-bag / parent index. Needs a designer (not builder) to reconcile design with current code or extract a focused sub-design.
    - **blocked-on-dependency**: drift B failed; needs the named dependency's actual phase to ship before the design is actionable.
    - **blocked-on-maintainer-decision**: the design has explicit open questions for the maintainer that the builder cannot guess.

6. **Restructure the section** with a sub-heading per classification, one-sentence "why" per design citing the offending commit SHA (drift A) or the unsatisfied phase (drift B). Bump the snapshot timestamp.

7. **Restate the eligibility ranking** at the bottom of the section, filtered to `eligible-for-builder` entries only and ranked by the prior groom's roadmap-priority signal (smaller surface area as a tiebreaker between equal-priority entries). The marshal-equivalent previously had to skip past blocked designs; the new ranking is filtered.

8. **Append "Suggested follow-ups"** for each `blocked-on-design-revision` entry that needs a designer dispatch (so the orchestrator sees them as candidates for the next cycle).

9. **Commit and push** per the groom's direct-push pattern (see `roles/groom/AGENT.md` step 11):

    ```sh
    git commit -m "process(groom): re-classify Spec'd-but-not-started with drift checks" \
      <queue-file>
    until git push <remote> HEAD:<branch> --force-with-lease; do
      git fetch <remote> <branch> && git rebase <remote>/<branch>
    done
    ```

10. **The orchestrator tears down the worktree** when you return.

## Scope discipline

- Do not redesign or revise the design files themselves; this pass updates only the queue file.
- Do not dispatch builders or designers; the marshal-equivalent will pick from your re-classified eligible list on the next cycle.
- Skip the velocity-recalibration / roadmap-projection / dependency-graph procedures from `roles/groom/AGENT.md`. Those are a separate full-grooming pass.
- Cap at ~30 minutes of work; if a design is genuinely ambiguous (could be drift B or could be eligible depending on how the dep's API actually shipped), classify as `blocked-on-maintainer-decision` and move on.

## Pitfalls

- **PR-acquired entries hide in the queue.** A snapshot dated days before the pass may list designs that acquired PRs since. Filter these out before classifying so the eligibility count is honest.
- **"Ideas and directions" documents are not the marshal's responsibility.** A document that says "pick one facet and write a focused design for it" is not implementable as one PR. Classify it `blocked-on-design-revision` and recommend it move to the project's aspirational / reference group.
- **The design's `Status: In Progress` lies in two directions.** It can lie low (work shipped, no one updated the field) and it can lie high (work undone by a refactor, no one updated the field). Drift A catches the second case; a separate resync check catches the first.

## Session origin

Introduced 2026-05-06 in the reference garden after two consecutive builder dispatches hit pre-flight impasses on drift A and drift B respectively. The full grooming-pass procedure did not include a classification dimension for these failures; the marshal-equivalent's eligibility filter therefore kept dispatching against rotted entries. The drift-check pass replaces the surface-level "Status is not In Progress and Dependencies are Complete" check with the two-pattern check above.

## Notes from the field

- _2026-05-13_: adopted from the reference. The reference's wording assumed `~/endo-wt/` and the `bots-ssh garden` branch; the active garden uses the per-dispatch worktree triple (the orchestrator prepares `project/`) and names the remote and branch in the dispatch brief.
