---
created: 2026-05-15
updated: 2026-05-15
author: gardener
---

# Skill: design-dependency-walk

Walk a chosen design's dependency chain to find an actionable starting point. Given a candidate design that may depend on other unfinished designs (and those on yet more), return one of four verdicts: build this design directly, stack on its in-flight PRs, build a deeper dep first, or no candidate in the chain is actionable. Used by the [general-contractor](../../roles/general-contractor/AGENT.md) during the *Refill* step of its per-cycle procedure; reusable by any future role (or one-off liaison turn) that needs to convert "the maintainer named this design" into "this is the next concrete slot of work."

Composes with `skills/design-to-pr-pipeline/SKILL.md` (which produces the candidate set) and `skills/design-queue-drift-check/SKILL.md` (which filters the set's eligibility). This skill is the **chain-walker**: given one candidate that has passed the prior two filters, follow its declared dependencies until a verdict lands.

## When to use

- A contractor cycle is refilling an empty slot and has picked one design from the eligible-for-builder set. Before dispatching a builder, run the walk to confirm the design is actually buildable now or to redirect to a deeper dep.
- A liaison in-session wants to answer the user's "what's blocking this design from starting" question. The walk's verdict is the answer.
- A future steward extension wants the same answer for its autonomous design-to-PR pipeline; consult this skill rather than re-deriving the logic.

## Inputs

- `seed_design_path`: the design document the caller is starting from (e.g., `designs/timer.md`, `packages/runtime/designs/proactive-messages.md`).
- `roadmap_branch`: today `llm` on `endojs/endo-but-for-bots`. Where the design documents live.
- `impl_base_branch`: today `master` on the same repo. Where the implementations land.
- `active_slot_designs`: the list of `design_path` values currently owned by other slots (so the walk does not redirect to a design another slot is already building). The contractor passes its in-memory slot table.

## State

None. The walk is a pure read against the roadmap branch and the open / merged PR list.

## Verdict shape

The walk returns one of four verdicts:

- **start-here**: the seed design (or, after walking, some ancestor design the walk redirected to) is actionable. All of its declared dependencies are either merged (a closed PR with the implementation) or have no implementation surface (a pure-design dep whose own implementation has already shipped under the same chain). The caller dispatches a builder against this design directly.
- **stack-on-PRs**: the seed (or walked ancestor) depends on N open implementation PRs. The dispatch's base branch is the merge of `<impl_base_branch>` and those N PR heads, per `skills/stacked-pr-build/SKILL.md`. The verdict names the open PR numbers and their head SHAs so the caller can pin the stack.
- **start-with-dep**: the walk reached a dependency that has neither a started design nor an open PR. The caller dispatches a builder against the dep instead (and the seed design re-enters the queue for a future cycle once the dep ships).
- **no-actionable-design**: every node in the walk is blocked (cycle in the dep graph, blocked-on-maintainer-decision dep, or every candidate's deps are themselves blocked). The caller leaves the slot empty this cycle and records the reason in the slot file's prose body.

The verdict's payload is a small structured record:

```yaml
verdict: start-here | stack-on-PRs | start-with-dep | no-actionable-design
design_path: <path>                   # the design the caller should build (seed, walked ancestor, or dep)
stack_prs:                            # populated only for stack-on-PRs
  - { number: <int>, head_sha: <sha>, design_path: <path> }
walked_chain:                         # the chain from seed to verdict-design, for the slot's prose body
  - <path>
  - <path>
note: <one-line summary>              # human-readable verdict explanation
```

## Procedure

The walk is a recursive DFS over the design's declared `## Dependencies` (or `## Depends On`) sections, with explicit cycle detection and a per-node classification step.

### 1. Parse the seed design's dependencies

Read the seed design document from the roadmap branch:

```sh
gh api repos/<owner>/<name>/contents/<seed_design_path>?ref=<roadmap_branch> \
  --jq '.content' | base64 -d > /tmp/<slug>.md
```

Find the `## Dependencies` (or `## Depends On`) section. Each bullet should name another design by its path; tolerate slug-only mentions but prefer the explicit path. Build `deps = [<dep-design-path>, ...]`.

A design with no `## Dependencies` section has `deps = []`; it is actionable by definition (subject to the eligibility filter in `skills/design-queue-drift-check/SKILL.md`, which the caller has already run). Return `{verdict: start-here, design_path: <seed>, walked_chain: [<seed>]}`.

### 2. Classify each dependency

For each `dep` in `deps`, determine its state. The states are mutually exclusive and ordered by priority (the first matching state wins):

a. **dep-merged**: a closed-and-merged PR cross-references the dep's design path per `skills/design-to-pr-pipeline/SKILL.md` § What counts as covered. The dep's implementation has shipped; this dep is satisfied.

b. **dep-in-flight-PR**: an open PR (draft or ready-for-review, kriscendobot-authored) cross-references the dep's design path. The dep has an actionable head SHA the caller can stack on. Record the PR number and head SHA.

c. **dep-unstarted-design**: the dep's design document exists on the roadmap branch but no open or merged PR cross-references it. The dep is unstarted; the walk must recurse into it.

d. **dep-no-design**: the dep's design document does not exist on the roadmap branch. Surface as a registry bug via a `message` entry to `liaison`; treat as `no-actionable-design` for the slot.

The classification uses two `gh` calls per dep:

```sh
SLUG=$(basename <dep-design-path> .md)
gh pr list -R <owner>/<repo> --state all --search "$SLUG" \
  --json number,state,title,body,headRefName,headRefOid \
  --limit 20
gh api repos/<owner>/<name>/contents/<dep-design-path>?ref=<roadmap_branch> \
  --silent 2>/dev/null || echo "MISSING"
```

### 3. Aggregate the verdict per the dep states

After classifying every `dep` in `deps`:

- **All deps are `dep-merged`**: verdict is `start-here` with `design_path = <seed>`.
- **Some deps are `dep-in-flight-PR`, the rest are `dep-merged`**: verdict is `stack-on-PRs` with `design_path = <seed>` and `stack_prs` populated from the in-flight-PR deps' PR numbers and head SHAs.
- **Any dep is `dep-unstarted-design`**: recurse into that dep (step 4). The recursion's verdict becomes the walk's verdict for the seed.
- **Any dep is `dep-no-design`**: write the `message` to liaison naming the dangling reference. The seed is `no-actionable-design`.

If a seed has mixed `dep-in-flight-PR` and `dep-unstarted-design` deps, the unstarted dep is the immediate blocker; recurse into it first. The seed can still resolve to `stack-on-PRs` later, but not in the same walk turn; the unstarted dep needs to ship first.

### 4. Recurse into an unstarted dep

For each `dep-unstarted-design` dep:

a. **Cycle detection.** Maintain a `walked_chain = [<seed-path>, ...]` set across the recursion. If `dep` is already in `walked_chain`, the dependency graph has a cycle. Write a `message` to liaison naming the cycle members; return `no-actionable-design` for the seed.

b. **Active-slot avoidance.** If `dep` is in the caller's `active_slot_designs`, another slot is already building it. Return `start-with-dep` pointing at `dep` is **wrong** in this case (the caller would dispatch a second builder against a design another slot owns). Instead, return `stack-on-PRs` with the other slot's pending PR (the slot file's `pr_number` is null until the builder returns; if the other slot is mid-builder, the recurse returns "wait" and the caller leaves this slot empty this cycle; record the reason).

   The contractor's slot table is the source of truth for *which design is being built by some slot right now*. The walk consults it; the caller's active_slot_designs input is the contractor's slot table at cycle start.

c. **Recurse.** Run the walk on `dep` with `walked_chain += [dep]`. The recursion's verdict tells you what to do next:
   - The recursion returns `start-here` for `dep`: the seed's verdict becomes `start-with-dep` with `design_path = dep`. The slot builds the dep first; the seed re-enters the queue for a future cycle.
   - The recursion returns `stack-on-PRs` for `dep`: the seed's verdict is **still** `start-with-dep` with `design_path = dep` (the slot builds the dep first as a stacked PR; the seed waits for the dep's PR to merge or for a future cycle to stack on it).
   - The recursion returns `start-with-dep` for `dep`'s own unstarted dep: the seed's verdict propagates that decision (the slot builds the deepest dep first).
   - The recursion returns `no-actionable-design`: the seed's verdict is `no-actionable-design`. The walk has reached an impasse along this branch.

   If the seed has multiple `dep-unstarted-design` deps and the first recursion returns `no-actionable-design`, try the next; only return `no-actionable-design` for the seed if every unstarted dep is itself unactionable. Order the dep walks by the dep's last-modified date on the roadmap branch (newest first); ties by path lexicographic order, for determinism.

### 5. Return the verdict

The caller (the contractor's *Refill* step) reads the verdict and proceeds:

- `start-here`: dispatch a builder against `design_path` with `impl_base_branch` as the base.
- `stack-on-PRs`: dispatch a builder with the stacked base per `skills/stacked-pr-build/SKILL.md`, naming the `stack_prs` PR numbers and head SHAs.
- `start-with-dep`: dispatch a builder against the dep's `design_path` (which the walk redirected to); the seed re-enters the queue.
- `no-actionable-design`: the slot stays empty; the cycle records the reason in the slot file's prose body and the contractor proceeds.

The verdict's `walked_chain` is written into the slot file's prose body so the next cycle's reader (or a future maintainer audit) can see the dependency path the walk traversed.

## Pitfalls

- **Slug-only dep references.** A design that names its deps as slugs ("depends on timer") rather than paths ("depends on `designs/timer.md`") is ambiguous when multiple designs share a slug. Resolve by checking the design's package directory; if ambiguous, write a `message` to liaison and treat the dep as `dep-no-design` for the walk. The right long-term fix is the designer tightening the dep reference; the walk should not guess.

- **Closed-not-merged PRs.** A PR that cross-references a dep but is closed-without-merge is **not** evidence the dep has shipped. The walk treats it the same as no PR at all: the dep is `dep-unstarted-design` unless a different open or merged PR also references it. Per `skills/design-to-pr-pipeline/SKILL.md` § What counts as covered.

- **A dep with a stale PR.** An open PR that has not been touched in weeks may be effectively abandoned, but it still counts as `dep-in-flight-PR` for the walk. The contractor's separate "adopt stuck PR" logic in the *Refill* step handles stale-PR adoption; the walk's classification is purely structural. The two procedures compose: if the walk returns `start-with-dep` because of a stale in-flight-PR dep, the contractor's adoption logic may pick up the stale PR as the slot's work instead, advancing it rather than starting from the dep's design.

- **A dep on a different upstream repo.** The walk assumes both the seed and its deps live on the same `<owner>/<name>` repo. Cross-repo dep references (e.g., a design in `endo-but-for-bots` that depends on a design in `endo`) are not supported by this skill's first version; surface as a registry bug to liaison and treat as `dep-no-design`. A future revision may extend the walk to cross-repo if the maintainer asks.

- **Cycle in the design dep graph.** Real but rare. The cycle-detection rule above catches it; the resulting `message` to liaison names every chain member so the maintainer can pick which edge to break by editing one design's `## Dependencies` section.

## Notes from the field

- _2026-05-15_: skill landed as part of the general-contractor carving (dispatch `a8e396`). The walk's four-verdict shape (start-here / stack-on-PRs / start-with-dep / no-actionable-design) matches the contractor's *Refill* step's branches. The `active_slot_designs` input is contractor-specific; a future caller (steward extension, one-off liaison turn) passes an empty list and the active-slot-avoidance rule (step 4b) is a no-op.
