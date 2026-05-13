---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Role: groom

Adopted from `references/endo-but-for-bots/roles/groom.md`.

Maintain a project's roadmap (the `designs/README.md` or equivalent) so that estimates stay calibrated to actuals, milestones reflect recent pace, the dependency graph matches the design files, and priorities are sorted against current direction.

Assumes you have already read `roles/COMMON.md`.

## When to enter this role

- A maintainer directive asks for a roadmap edit: "raise X to M1", "groom the roadmap", "refresh estimates".
- A milestone has just completed and ratios are now meaningful.
- Several designs have flipped to `**Complete**` since the last pass.
- A periodic schedule fires (e.g., monthly) for an unattended pass.

A targeted roadmap edit (one design moves milestone, one row's status flips) is a thin slice of the full procedure: read the file, make the edit, push. Use the full procedure when reconciling many rows or recalibrating velocity.

## Skills

- [worktree-per-pr](../../skills/worktree-per-pr/SKILL.md): operate inside the dispatch root's `project/` worktree.
- [process-documents](../../skills/process-documents/SKILL.md): if the project still keeps a `process/` tree on its own branch, open-questions and answer-drain commits land there as isolated process commits. In this garden, per-project process documents commonly live in the journal as `message` entries tagged with the project slug; consult the project's mirror entries first.
- [groom-open-questions](../../skills/groom-open-questions/SKILL.md): format and discipline of the open-questions / answers ledger left for the maintainer.
- [velocity-recalibration](../../skills/velocity-recalibration/SKILL.md): recompute reference points and size buckets from observed completion durations.
- [roadmap-projection](../../skills/roadmap-projection/SKILL.md): recompute Summary by Milestone, the Mermaid Gantt, and the trailing "Progress as of" line.
- [dependency-graph-maintenance](../../skills/dependency-graph-maintenance/SKILL.md): reconcile design files' edges against the README graph and surface cycles.
- [design-queue-drift-check](../../skills/design-queue-drift-check/SKILL.md): the lighter sub-mode that re-classifies a `DESIGNS-WITHOUT-PR.md` queue so a marshal-equivalent picks from a clean list. Skips velocity / roadmap / dependency-graph procedures.
- [em-dash-style](../../skills/em-dash-style/SKILL.md), [relative-paths](../../skills/relative-paths/SKILL.md): apply to all roadmap prose.
- [self-improvement](../../skills/self-improvement/SKILL.md): the final task of every engagement.

## Sub-modes

- **Full grooming pass.** Velocity recalibration, roadmap re-projection, dependency-graph reconciliation, reprioritization, open-questions append. One `designs/README.md` edit commit, plus zero or one open-questions process commit (or journal `message` entry on this garden when the project's notes live there).
- **Drift-check pass.** Updates only the `DESIGNS-WITHOUT-PR.md` (or equivalent triage queue). Cap: ~30 minutes. See the cited skill.
- **Targeted post-event reconciliation.** A single-event trigger (a PR merging, a maintainer directive flipping one milestone, a builder pre-flight surfacing a reclassification). Edit only the disturbed rows; note the deltas in a "Changes since the prior-snapshot-date snapshot" block at the file's top. Cap: ~10 minutes. No full re-survey, no open-questions append.

The dispatch prompt names which sub-mode the groom runs. Default is targeted unless the brief asks for a full pass.

## Inbound: read prior open questions and answers first

Before reconciliation, search the project's mirror for prior groom open questions and any maintainer answers. In this garden, those are journal entries tagged with the project slug:

```sh
grep -rl '^project: <slug>' journal/entries/ | xargs grep -l 'GROOM-OPEN-QUESTIONS\|GROOM-ANSWERS'
```

The most recent matching entry is the current source of truth. If an answer is present for a prior open question, apply the maintainer's guidance to the roadmap edit, then leave a note (in your `result` entry, or as a follow-up journal `message`) recording that the question is closed and the answer applied. The discipline is "answer in, action taken, both notes shrink".

If a project still keeps `process/GROOM-OPEN-QUESTIONS.md` and `process/GROOM-ANSWERS.md` on a branch of its own repo, the same discipline applies in the fork worktree per `skills/process-documents/SKILL.md`: the answered-question deletion and the open-question append ship as isolated process commits.

## Procedure (full grooming pass)

1. **Stand in the dispatch's `project/` worktree.** The orchestrator prepared it. Verify with `pwd` and `git log -1`.
2. **Fetch and fast-forward the project's roadmap branch** so the pass starts from the current tip. If fast-forward fails, the local has diverged; stop and report rather than resolving via a merge commit.
3. **Read prior open questions and any maintainer answers** per *Inbound* above. Apply answered items into the edits you make this pass.
4. **Reconcile per-design status.** Walk every design listed in `designs/README.md` § Summary; compare its row to the design file's metadata block. Drift goes in the open-questions note; do not edit the README's row to match a file that itself looks stale. Recompute any "Totals" line below the table from actual statuses present.
5. **Recalibrate velocity** via `skills/velocity-recalibration/SKILL.md` over designs completed since the previous calibration. Refresh the reference-point table and the size-bucket durations.
6. **Re-project the roadmap** via `skills/roadmap-projection/SKILL.md`: recompute § Summary by Milestone, the Mermaid Gantt and its table, and the trailing "Progress as of" line.
7. **Update the dependency graph** via `skills/dependency-graph-maintenance/SKILL.md`: reconcile new edges, surface cycles, flag divergences in the open-questions note.
8. **Reprioritize.** For any design whose milestone now looks wrong (its prerequisite shipped, its rationale changed, the strategic-early reasoning no longer applies), draft a recommendation. Mechanical recommendations (move A from M4 to M3 because its sole M3 dep just landed) apply directly; trade-off recommendations go in the open-questions note.
9. **Leave open questions** wherever the procedure called for one, per `skills/groom-open-questions/SKILL.md`.
10. **Commit.** The README edit ships as one substantive commit; the open-questions append and any answer-drain ship as separate process commits per `skills/process-documents/SKILL.md`. No `Co-Authored-By: Claude` lines; the upstream identity authorizing the push is named in the dispatch brief.
11. **Push to the project's roadmap branch**, rebasing on conflict until success. Roadmap branches are commonly high-traffic; the first push may be rejected because the remote tip advanced. Loop:

    ```sh
    until git push <remote> HEAD:<branch> --force-with-lease; do
      git fetch <remote> <branch>
      git rebase <remote>/<branch>
    done
    ```

    Even `--force-with-lease` has a race window: it computes the lease from the most-recently-fetched ref, so if a concurrent agent pushes between your last fetch and your push, the lease passes against your stale cache and the concurrent commit is overwritten silently. Always run `git fetch <remote> <branch> && git diff --stat HEAD..FETCH_HEAD` immediately before the push and verify the diff is empty; if not, rebase before pushing. The `until` loop is what makes this eventually-safe: an overwritten push triggers no rebase, but the next agent's fast-forward-failure rebase notices and recovers.

12. **The orchestrator tears down the worktree** when you return. Do not remove it yourself.

The targeted and drift-check sub-modes share steps 1, 2, 3, 10, 11, 12; they replace steps 4 to 9 with the focused work each sub-mode names (one row's edit in the targeted case; a re-classification pass over the triage queue in the drift-check case).

## Recovery: cross-role clobber of `designs/README.md`

A non-groom role (commonly a builder or fixer working from a stale worktree base) can inadvertently include a revert of the last groom's reconciliation alongside its intended edit to a different file. Symptom: a recent commit's diff for `designs/README.md` undoes the previous groom-pass changes (M-counts regress, "Last updated" moves backward, status rows revert, "Progress as of" goes back to an older date) while the same commit's other file changes are legitimate.

This is **not** a force-push lease failure; it is a regular commit whose working-tree base predated the groom's merge. The other-file changes in that commit must stay; only the README revert needs undoing.

Recovery:

1. Identify the most recent groom-pass commit on the roadmap branch (the one whose `designs/README.md` is the target state).
2. From your dispatch's `project/` worktree, restore that file from the groom commit:

    ```sh
    git checkout <groom-sha> -- designs/README.md
    ```

3. Verify only the offending commit intervened (and nothing else):

    ```sh
    git log --oneline <groom-sha>.. -- designs/README.md
    ```

    If a later commit also legitimately edited the file, do not blindly check out the groom SHA; merge by hand, taking the groom-pass values for the reconciled rows on top of the later legitimate change.
4. Recompute the totals row to confirm the restored state matches actual statuses present. Skip the full velocity / roadmap re-projection unless data has substantially changed.
5. Commit as `docs(designs): restore README rows clobbered by <short-sha>` and push per step 11.

The clobber-recovery pass is narrower than a normal grooming pass: one file restored, one commit, no open-questions append, no answer drain.

## External-repo etiquette

The groom edits the project's roadmap file on a branch that is its own merge target (often a branch with no review gate, e.g. the prior reference's `garden` branch). The push is implicit in the dispatch's framing. Posting a roadmap-comment on a PR or issue (e.g., explaining a non-trivial milestone reshape) is a per-action authorization the steward forwards from a liaison `message`; the groom does not originate it. See `roles/COMMON.md` § External-repo etiquette.

## Operating norms

- **Reconcile facts before recommending.** Velocity must be recalibrated before milestones are re-projected; the graph must be up to date before priorities are re-evaluated.
- **Cite sources for every actual.** "Median of N reference points from <date> to <date>" beats "feels faster lately".
- **Decisions that require taste** (reshaping milestones, changing the strategic-early list, dropping a design) go to the maintainer via the open-questions note, not the README edit.
- **Date every change with the actual ISO date the pass runs.** Convert any relative date the dispatch used ("Thursday") into the absolute date.
- **One pass, one substantive diff.** A grooming pass produces one diff to `designs/README.md` plus zero or one bullets appended to the open-questions note. If the diff spans more sections, the pass was over-broad; split it.
- **Leave the README readable as a standalone document.** The audience is a maintainer skimming over coffee, not the groom on the next pass.

## Definition of done

- The `designs/README.md` edit is committed on the project's roadmap branch and pushed (with retry-on-rejection).
- Any open-questions append and answer-drain ship as separate process commits or as a journal `message` entry tagged with the project slug, never folded into the substantive diff.
- A `result` journal entry references the originating dispatch, names each file changed, and ends with `Self-improvement: ...` per the skill.
