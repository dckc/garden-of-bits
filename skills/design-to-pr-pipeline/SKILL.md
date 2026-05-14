---
created: 2026-05-14
updated: 2026-05-14
author: gardener
---

# Skill: design-to-pr-pipeline

Inventory the project's roadmap branch for design documents that lack a tracking PR, and dispatch a builder to open the initial PR for the next uncovered design. Used by the [steward](../../roles/steward/AGENT.md) on its per-cycle pass per `roles/steward/AGENT.md` § Design-to-PR pipeline, and by the [liaison](../../roles/liaison/AGENT.md) when a user-in-session asks "what's the next uncovered design".

This skill is the *queue maintenance* skill (designs ↔ PRs). [`skills/design-queue-drift-check/SKILL.md`](../design-queue-drift-check/SKILL.md) is the *eligibility filter* (classify designs as eligible / blocked-on-revision / blocked-on-dependency / blocked-on-maintainer-decision). The two compose: drift-check classifies, queue-pipeline dispatches a builder for the eligible head.

## When to use

- The steward's per-cycle pass reaches the *Dispatch* step and the design-PR-drafting cap is free.
- The liaison wants the inventory to surface uncovered designs for a user question.
- A maintainer directive names a specific design and asks for the tracking PR to be opened.

## Inputs

- `project_slug`: short kebab-case name of the project (e.g. `endo-but-for-bots`).
- `repo`: `<owner>/<name>` of the project's bot fork (today `endojs/endo-but-for-bots`).
- `roadmap_branch`: the project's roadmap branch where designs live (today `llm`).
- `design_paths`: the project's design directories (today `designs/` at the repo root plus `packages/*/designs/`).

The steward names these in the cycle's *Dispatch* step; the per-project facts live in the journal under the project slug rather than hardcoded here, so other projects adopting this discipline only need to supply the inputs.

## State

This skill is stateless across invocations; the inventory is computed fresh each cycle against the current state of the roadmap branch and the current set of open and merged PRs. The "what counts as covered" rule below decides per-design without persistent state.

The steward's per-cycle journal entry records the inventory result (uncovered count, the design slug dispatched if any) so future cycles can grep the journal for "what we knew last cycle" without re-running the procedure.

## What counts as covered

A design at path `<design-file>` on the roadmap branch is **covered** when any of the following is true:

1. **Open PR cross-references the design path.** `gh pr list -R <repo> --state open --search '<design-slug>'` returns at least one PR whose title, body, or any commit message references the design file path (`designs/<slug>.md`, or the full path including the package directory). The cross-reference must be load-bearing (a "this PR implements `designs/<slug>.md`" line, or a commit message naming the design path); a passing mention in a checklist is not enough.
2. **Merged PR cross-references the design path.** Same search against `--state merged`. A merged PR that implemented the design is the natural terminus of the chain; the steward does not re-dispatch a new tracking PR for it.
3. **The design's own metadata names a PR.** Some designs carry a `Status: PR #N` line in the document body. If `gh pr view <N> -R <repo>` returns a PR that is still open or merged, count the design as covered.

Closed-without-merge PRs do **not** cover a design. A closed-not-merged PR is evidence the prior attempt was abandoned; the design re-enters the uncovered set and the next cycle's dispatch starts a fresh tracking PR.

The "load-bearing reference" rule exists because design slug names recur as English nouns ("the timer design") in many places; a checklist that lists "timer" as one of twenty items is not a tracking PR for the timer design. The match has to be the canonical path (`designs/<slug>.md` or its package-scoped equivalent).

## Procedure

Run from the steward's parent context, not from inside a dispatched subagent's worktree (the procedure dispatches its own builder; doing so from inside a builder dispatch would nest).

### 1. Walk the design paths on the roadmap branch

```sh
gh api repos/<owner>/<name>/contents/designs?ref=<roadmap_branch> --jq '.[] | select(.type=="file") | .path'
```

Repeat for each `packages/*/designs/` path the project uses. Concatenate into a candidate list. Each candidate is the relative path to one design document (e.g. `designs/timer.md`, `packages/runtime/designs/proactive-messages.md`).

### 2. For each candidate, check coverage

For each design path, run the cheap search:

```sh
SLUG=$(basename <design-file> .md)
gh pr list -R <repo> --state all --search "$SLUG" \
  --json number,title,state,body,headRefName \
  --limit 20
```

Walk the result. A PR counts as covering the design if its title, body, or `headRefName` contains the canonical design path (or the slug with the canonical-path qualifier in context). Use the *What counts as covered* rule above.

For closed-not-merged PRs, do not count them as covering; record the closed PR number in the cycle journal entry so the maintainer can audit if the abandoned attempt should be revived rather than re-started.

### 3. Compute the uncovered set

The uncovered set is `candidates - covered`. Sort by the design's last-modified timestamp on the roadmap branch (newest first), then by file path as a tiebreaker. The first entry is the next-owed design.

### 4. Check the concurrency cap

The cap is **one builder for design-PR-drafting in flight across the estate at a time**. Check the journal for an open dispatch with purpose slug `draft-initial-pr-<design-slug>` that has not yet produced a `result`. If one is open, the cap is taken; this cycle dispatches no new builder.

```sh
# from the steward's per-cycle context, journal worktree at journal/
grep -lE '^purpose: *draft-initial-pr-' journal/entries/$(date -u +%Y/%m)/ 2>/dev/null \
  | while read f; do
      base=$(basename "$f" | sed 's/.md$//')
      short=$(echo "$base" | grep -oE '[a-f0-9]{6}$')
      # Look for a matching result entry
      if ! grep -lE "$short" journal/entries/$(date -u +%Y/%m/%d)/*-result-*.md \
         >/dev/null 2>&1; then
        echo "in-flight: $f"
      fi
    done
```

The shape above is illustrative; the steward may use any equivalent check (the journal is structured enough that "open dispatch with matching purpose slug and no result entry" is straightforward).

### 5. Dispatch the builder (cap free + uncovered set non-empty)

If the uncovered set is non-empty and the cap is free, prepare the dispatch:

```sh
DISPATCH_ROOT=$(skills/dispatch-worktree/dispatch-prepare.sh builder \
  draft-initial-pr-<design-slug> <owner>/<name> <roadmap_branch>)
```

Then write the `dispatch` journal entry naming the design path, the roadmap branch, the expected report shape, and the `DISPATCH_ROOT`. The dispatch prompt names the design path and tells the builder this is a tracking PR for an uncovered design.

### 6. The builder's brief

The builder's task in this dispatch differs from the regular feature-implementation builder in two ways:

- **Base branch is the roadmap branch** (today `llm`), not `master`. The tracking PR lives on the roadmap branch alongside the design itself.
- **The initial PR is a stub.** The builder opens a draft PR whose head commit is one of: (a) a re-statement of the design's acceptance criteria as a checklist in the PR body, (b) a placeholder slug-branch with a one-line README addition naming the design, or (c) an initial-pass skeleton (function signatures, types, no implementation) that compiles and runs the design's stated tests in failing state. The builder picks (a), (b), or (c) based on the design's shape; (a) is the cheapest, (c) is the most useful when the design's acceptance criteria are precise.

The builder's `result` entry names the new PR number; the steward marks the design as covered in the next cycle's inventory because the open PR now cross-references the design path.

### 7. Empty uncovered set

If the uncovered set is empty, the cycle records `design-to-pr scan: 0 designs owed` in the cycle summary and continues. No dispatch.

## Output

A `dispatch` journal entry (if the cap is free and the uncovered set is non-empty) and the subsequent `result` entry when the builder returns. The cycle-summary entry records the inventory result either way:

```
design-to-pr scan: <N> designs uncovered; dispatched builder for <design-slug>
design-to-pr scan: <N> designs uncovered; cap taken by in-flight <prior-design-slug>
design-to-pr scan: 0 designs uncovered
```

## Notes from the field

- _2026-05-14_: skill landed. The maintainer's framing: "New designs have landed. The steward is responsible for noticing that new designs have landed and to keep at one builder subagent busy drafting the initial PR at a time, until all designs are accounted for. That entails linking the design to a PR on the llm branch." The "what counts as covered" rule is initial; the maintainer's interim provisional rule (an open or merged PR whose title, body, or commit messages reference the design file path) is the starting point, and this skill tightens it to require the canonical path rather than a slug-only mention. The "initial PR shape" sub-choices (stub-checklist, placeholder-readme, skeleton) are first-pass; observed evidence on what fits each design's shape will accumulate in future entries here.
