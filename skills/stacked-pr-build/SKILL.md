---
created: 2026-05-15
updated: 2026-05-15
author: gardener
---

# Skill: stacked-pr-build

Build a PR whose base is the implementation branch with one or more in-flight PR heads merged in, so the dependent's implementation can be developed and reviewed against the actual code the deps deliver rather than against a clean base that does not yet have them. Used by the [general-contractor](../../roles/general-contractor/AGENT.md) when `skills/design-dependency-walk/SKILL.md` returns the `stack-on-PRs` verdict; reusable by any role facing the same dep-stack shape.

Distinct from `skills/pr-dependency-graph/SKILL.md` and `skills/pr-dependency-topo-sort/SKILL.md`: those skills are the *registry-read and ordering* primitives for the bulletin and the journalist's per-cycle rendering. This skill is the *operational* procedure for building on top of a stack at build time: what base to compute, how to commit, how to surface the dependence to reviewers, and how to handle the stack's heads moving.

## When to use

- The design-dependency-walk's verdict is `stack-on-PRs` and the caller is about to dispatch a builder.
- A maintainer directive names "build X on top of #N and #M" explicitly.
- The contractor's *Refill* step adopts a stale PR whose body declares `depends on #N` and the maintainer (or the walk) confirms the dependency is load-bearing rather than informational.

## Inputs

- `impl_base_branch`: today `master` on `endojs/endo-but-for-bots`. The natural implementation base.
- `stack_prs`: list of `{number: <int>, head_sha: <sha>, design_path: <path>}` records. Order is the dep order returned by the walk (deepest dep first; the walk's `walked_chain` preserves the order).
- `seed_design_path`: the design the slot is implementing. The PR's body will cite this and the stack.
- `working_branch_name`: the branch name the builder will push to (e.g., `<bot-slug>--<design-slug>--stack`).
- `repo`: `<owner>/<name>` of the fork.

The contractor passes these from its slot table plus the walk's verdict; a one-off caller assembles them by hand.

## Procedure

The stack is built on a fresh local branch and pushed to the fork. The PR is opened against `impl_base_branch` (not against the topmost stack PR) so the GitHub diff shows the full delta from `impl_base_branch` plus the deps' diffs plus the seed's diff. Reviewers see everything in one place; the dep PRs continue to live as their own merge units.

### 1. Prepare a clean working tree

The orchestrator's `dispatch-prepare.sh` has already created the dispatch's `project/` worktree at `impl_base_branch`. Stand in `project/`:

```sh
cd project/
git fetch origin <impl_base_branch>
git checkout -B <working_branch_name> origin/<impl_base_branch>
```

The working branch starts at the freshest `origin/<impl_base_branch>` HEAD. The dispatch worktree's local `<impl_base_branch>` may be behind by minutes; the `git fetch` keeps the stack aligned.

### 2. Merge each stack PR's head SHA

For each `stack_pr` in order (deepest dep first):

```sh
git fetch origin pull/<number>/head:pr-<number>
git merge --no-ff pr-<number> \
  -m "stack: merge endojs/<repo>#<number> head <short-sha> (<dep-design-slug>)"
```

The `--no-ff` is load-bearing: the merge commit's first parent is the working branch's prior HEAD, the second parent is the dep PR's head. The merge commit's message names the upstream PR and the dep's design slug so a reviewer can trace the stack without leaving the PR view.

Use the SHA the walk recorded, not `pr-<number>`'s current head, when the contractor's slot file was written more than five minutes before this step. The slot file is the source of truth for what the stack pinned to; if the dep PR's head has advanced since, the contractor's slot file is the audit trail for what the stack actually built on. (A future cycle that re-runs the walk and sees the new head can rebuild the stack against the new SHA; the prior build is preserved in git history.)

Resolve conflicts in line per `skills/conflict-resolution/SKILL.md`. The merge commit's body should record any non-trivial resolution; if the resolution exceeds the scope of a single commit message, the builder writes a follow-up commit on top of the merge that adjusts the dep's code so the stack compiles, with a commit message that explains the adjustment.

### 3. Add the seed's implementation commits

After all stack merges land, the working branch is at `impl_base_branch + dep1 + dep2 + ...`. The builder now commits the seed design's implementation on top, using whatever per-package commit shape `skills/changeset-discipline/SKILL.md` and the project's own commit-shape conventions call for.

The seed's commits should not re-touch files the stack merges introduced unless the seed genuinely needs to. Cross-cutting touches (a shared utility the dep PR introduced and the seed extends) are fine; gratuitous re-formatting of the dep's code is not.

### 4. Push the working branch

```sh
git push origin HEAD:<working_branch_name>
```

The push goes to the fork as usual; the working branch lives alongside the existing fork branches.

### 5. Open the PR against the implementation base

```sh
gh pr create -R <repo> \
  --base <impl_base_branch> \
  --head <working_branch_name> \
  --draft \
  --title "<seed-design-slug>: <one-line description>" \
  --body "$(cat <<'EOF'
Implements `<seed_design_path>`.

## Stack

This PR is built on top of:

- #<number-1> (`<dep-1-design-slug>`)
- #<number-2> (`<dep-2-design-slug>`)
- ...

The merge commits at the top of the stack pin each dep at the SHA the
slot's design-dependency-walk recorded. Reviewers see the full diff
including the deps' contributions; the deps' PRs continue to live as
their own merge units. When the deps merge into `<impl_base_branch>`,
the maintainer can either rebase this PR (the weaver does it on the
contractor's next cycle) or merge this PR after the deps have landed.

## Design

<short summary of the seed design's contract>
EOF
)"
```

The PR opens in draft state per the standard `skills/pr-creation-flow/SKILL.md` discipline. The judge un-drafts when the chain terminates.

### 6. Record the stack on the slot file

The contractor writes the stack metadata into the slot file's frontmatter so subsequent cycles know the PR is a stack:

```yaml
stack:
  base: <impl_base_branch>
  prs:
    - { number: <int>, head_sha: <sha> }
    - { number: <int>, head_sha: <sha> }
```

The slot's prose body records the design-dependency-walk's chain.

## Maintaining the stack across cycles

The dep PRs continue to move while the seed's PR is in flight. The contractor's per-cycle procedure handles three transitions:

- **A dep PR merges.** The stack's pinned SHA is now part of `impl_base_branch`. The seed PR is fine as-is; the next weaver dispatch (when the seed becomes `CONFLICTING` against its base, or on a maintainer-asked rebase) reduces the stack by one PR, because the dep's commits are now ancestors of `impl_base_branch`.

- **A dep PR's head advances.** The maintainer (or the bot chain) pushed new commits to the dep's PR. The seed's stack still points at the old SHA. Two options:
  - **Leave it.** The seed's PR is built on the stack snapshot; the dep's later commits don't affect the seed's review surface. The dep will land eventually and the weaver dispatch above resolves the stack.
  - **Rebuild the stack.** If the dep's new commits include API changes the seed relies on, dispatch a weaver to rebase the seed against `impl_base_branch + <new-dep-head>`. The weaver follows the same merge-each-pr procedure above but starting from the seed's existing branch rather than from `impl_base_branch`.

  The contractor's slot file's `stack.prs[].head_sha` is the audit trail. A weaver dispatch with the brief "rebase against the dep's new head" updates the slot file's pinned SHAs.

- **A dep PR is closed without merging.** The stack is broken: the dep's implementation is no longer landing, but the seed depends on it. The contractor surfaces the breakage as a `message` to liaison, marks the slot stalled per the role's stall-detection procedure, and re-enters the dependency walk on the seed (which now sees the dep as `dep-unstarted-design` again; the walk may redirect to `start-with-dep` or `no-actionable-design`).

## Pitfalls

- **Opening the PR against the topmost stack PR's branch.** Tempting but wrong. The PR's diff would only show the seed's own commits, hiding the stack from the reviewer. Open against `impl_base_branch`; the stack is visible as the merge commits at the top.

- **Forgetting `--no-ff`.** A fast-forward merge produces a linear history that loses the "this is a stack" signal in `git log --graph`. The merge-commit's two-parent shape is load-bearing for the reviewer and for any later bisect. Always use `--no-ff` for stack merges.

- **Resolving conflicts in the merge commit's resolution rather than in a follow-up commit.** A merge commit with a non-trivial conflict resolution embedded in it is hard to review (the merge commit's diff against either parent is the resolution, but neither view shows the diff against the *seed's* code). When the resolution is more than a one-line conflict marker fix, commit it as a separate `chore: reconcile stack with <dep>` commit on top of the merge.

- **Stacking deeper than two PRs.** Three or more PRs in a stack increases the bot's review surface and the rebase cost geometrically. The contractor's first heuristic is to redirect to `start-with-dep` when the stack would exceed two PRs; the deeper dep is built first as its own slot, and the seed re-enters the queue once the dep lands. The walk's recursion does this naturally (an unstarted dep at depth 2 returns `start-with-dep` for the seed, redirecting the slot to build the depth-2 dep directly). A maintainer override can permit a deeper stack when the deps are mature and unlikely to need further rework.

- **The dep's design naming a different `impl_base_branch`.** If the dep's design says it lands on a different base than the seed (rare, but possible during a base migration), the stack is invalid; the deps cannot be merged because their commits are on a different lineage. Surface as a `message` to liaison.

## Notes from the field

- _2026-05-15_: skill landed as part of the general-contractor carving (dispatch `a8e396`). The maintainer's framing in the originating dispatch entry: "the builder is to implement their design based on a merge of all its dependency PRs, in a stack." The merge-each-PR approach (open against `impl_base_branch`, stack as merge commits at the top) was chosen over the "branch off the topmost stack PR" alternative because the former preserves a single-PR review surface for the reviewer; the latter would scatter the seed's review across the stack's PRs. The two-PR depth cap is a first heuristic; the notes-from-the-field will accumulate evidence on whether deeper stacks are sometimes warranted.
