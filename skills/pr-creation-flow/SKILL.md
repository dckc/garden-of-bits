---
created: 2026-05-13
updated: 2026-05-14
author: gardener
---

# Skill: pr-creation-flow

The canonical procedure that ties the per-PR roles together: which role opens the PR, which roles touch it before the maintainer ever sees it, and which role decides it is ready for the maintainer's review queue. Read by every role the flow touches ([builder](../../roles/builder/AGENT.md), [assayer](../../roles/assayer/AGENT.md), [juror](../../roles/juror/AGENT.md), [saboteur](../../roles/saboteur/AGENT.md), [fixer](../../roles/fixer/AGENT.md), [cleaner](../../roles/cleaner/AGENT.md)) and by the orchestrators ([liaison](../../roles/liaison/AGENT.md), [steward](../../roles/steward/AGENT.md)) that dispatch them.

The skill is the orchestration map. Per-role detail (how to write a test, how to address a review thread, how to delete dead code) lives in the role files and the role-specific skills.

## When to use

- The orchestrator dispatches a builder against an issue or design. The flow starts here.
- A maintainer asks for a fresh PR. The flow is the same.
- A cold PR opened by someone else gets a jury panel after the fact. The flow's jury and cleaner stages still apply; only the builder stage is skipped.

## Draft discipline

**The builder opens every PR in draft state**: `gh pr create --draft` (or the API equivalent with `draft: true`). The draft flag is the load-bearing signal that the bot-side chain has not yet finished. **The cleaner is the only role that moves the PR out of draft** (`gh pr ready <N>`), and only after CI is green on the cleaner's own HEAD.

Why draft state rather than labels: draft state is enforced by GitHub itself (reviewers cannot be auto-requested on a draft, the PR is visually distinct, the merge button is disabled). Labels are advisory text the bot writes and the bot reads; nothing outside the bot acts on them. The flow uses draft vs ready-for-review as the load-bearing state, with labels (if used at all) as advisory annotation.

## Flow ordering

```
builder (opens draft PR)
   |
   |  in concert (default), or before, or after
   v
assayer  --pushes tests to same branch
   |
   v
jury (juror + saboteur panel)
   |
   |  if must-fix items, the orchestrator dispatches a fixer
   v
fixer --pushes follow-up commits
   |
   v
jury (re-review the same panel)
   |
   |  loop until the jury declares no further in-scope complaints
   v
cleaner (coverage pass; same branch)
   |
   |  cleaner pushes coverage commits, watches CI converge
   v
gh pr ready <N>  (cleaner un-drafts; PR enters maintainer's review queue)
```

Variants:

- **No must-fix on first jury round.** The fixer step is skipped. The orchestrator dispatches the cleaner directly after the jury's review submission.
- **Cleaner-skipped PRs.** When the PR is pure docs, lockfile-only churn, a one-file format sweep, or a single bug-fix line whose test fixture is already in the diff, the cleaner has no coverage surface to expand. The cleaner step still procedurally runs (the orchestrator dispatches a cleaner; the cleaner reads the PR, decides no work is warranted, and un-drafts directly); this preserves the un-draft authority routing through the cleaner role.
- **Pre-merge fix-up rounds (after maintainer review).** The maintainer's `CHANGES_REQUESTED` triggers the standard fixer loop (fixer to CI-green to re-request maintainer); the cleaner does not re-run by default. A maintainer who explicitly asks for a fresh cleaner pass overrides this default.

## Assayer placement

The assayer authors tests for *this PR's contribution*. The default placement is **in concert with the builder**: the assayer and builder are dispatched concurrently against the same branch, the builder writes the production change, the assayer writes the tests that pin the contract, and both push to the same branch as their commits land. The two roles coordinate via the dispatch briefs and the PR's commit log, not via an explicit synchronization step.

Two other orderings are supported when the change's shape calls for them:

- **Before the builder (TDD-style).** The assayer writes tests that fail closed against the current production code; the builder is then dispatched to make them pass. Best fit: the contract is fully specified in the issue or design, and the builder benefits from a fail-fast definition of done.
- **After the builder (regression-coverage).** The builder writes production and lands a draft PR; the assayer is then dispatched to pin the regressions the change closes. Best fit: the change is a bug fix where the contract is "the behavior described in the bug report"; the assayer's test pins exactly that.

The orchestrator names the placement in the dispatch brief. Default is in concert unless the brief specifies otherwise.

### Default rationale

In-concert is the default because:

- The builder and assayer share the same branch; concurrent pushes work cleanly because their commits touch disjoint files (production vs test).
- TDD-style requires the builder to be blocked on the assayer's first push; the time-to-first-CI-green stretches.
- Regression-after means the assayer's test is written against code that already passes (less load-bearing per `skills/regression-evidence/SKILL.md`'s shape); the assayer has to temporarily break the production code to confirm the test fails, which is an extra step.

The notes-from-the-field section accumulates evidence as the flow runs; if a different default emerges, this section updates.

## Jury composition

The default jury is **two seats: one juror plus one saboteur**, dispatched by the orchestrator as a single jury round. The two roles operate as a fixed pair:

- The juror covers the general review surface (correctness, types, API stability, diff hygiene, naming, docs, etc.; see `skills/panel-review/SKILL.md` for the canonical perspective list).
- The saboteur specifically looks for invariant violations and adversarial inputs the regular review surface would miss (see `skills/adversarial-tests/SKILL.md` and `skills/saboteur-adversarial-review/SKILL.md`).

The orchestrator's choice: dispatch the two seats **sequentially or concurrently**. The deliverable is the same shape either way (one aggregated panel verdict, one formal `gh pr review` submission). Concurrent dispatch is cheaper wall-clock; sequential dispatch lets the saboteur's findings be informed by the juror's reading (the juror tends to surface "this branch is untested" findings the saboteur then frames as "and here is the attack on it"). The gardener's working default is concurrent; the orchestrator may pick differently for a specific PR.

Larger panels are supported by the same machinery (the reference's 12-perspective panel is one such larger composition); the orchestrator names the composition in the dispatch brief.

## Jury-fixer loop

After the jury submits its verdict:

1. **If the verdict has must-fix items**: the orchestrator dispatches a fixer with the must-fix list inline as the brief. The fixer addresses each item (or replies on threads citing why an item is verified-no-change or deferred), pushes follow-up commits, and reports done.
2. **The orchestrator re-dispatches the jury** (same panel, or an equivalent one). The juror's job on a re-review is to verify each prior must-fix is addressed and to surface any *new* in-scope finding the fix introduced.
3. **Loop until the panel surfaces no further in-scope complaints.** In-scope means a problem the PR's change introduced or directly touched. Out-of-scope complaints (adjacent refactors, package-wide hygiene) go in the "Out of scope / follow-up" section of the panel report and become candidate follow-up PRs or issues; they do not block the loop.
4. **When the jury declares the loop done** (an `--approve` verdict or a `--comment` verdict with no must-fix or should-fix items in scope), the orchestrator dispatches the cleaner.

Loop-exit discipline: the jury cannot block the loop on out-of-scope findings. If a juror keeps surfacing the same out-of-scope concern across rounds, the orchestrator promotes the concern to a separate issue and clears it from the loop.

## Cleaner placement

The cleaner is the **last role to automatically touch the PR before the maintainer ever sees it**. Its remit:

- Run a coverage pass on the package(s) the PR touched, per `skills/coverage-driven-testing/SKILL.md`.
- Push coverage commits to the same branch.
- Watch CI converge to green (or only documented pre-existing infra red) on the cleaner's own HEAD.
- `gh pr ready <N>` to un-draft. The PR enters the maintainer's review queue.

The cleaner is the **only role that un-drafts**. No other role moves the PR out of draft state; the un-draft is the load-bearing signal that the bot-side chain is complete.

If the PR is `CONFLICTING` against its base when the cleaner arrives, the cleaner does not push coverage commits onto a non-mergeable head. It surfaces "needs a weaver before cleaner" and the orchestrator dispatches a weaver first.

## State on the PR

The flow encodes position in two layers:

- **Draft vs ready-for-review** (load-bearing). Draft means the bot-side chain is in progress; ready-for-review means the cleaner has un-drafted and the maintainer's queue is the next venue.
- **Labels** (advisory). When useful, the bot can annotate the PR with labels like `state:building`, `state:in-review`, `state:fixing`, `state:cleaning`, `state:ready`. These are for the bot's own dashboard and dispatch-decision triage. Labels are not load-bearing; the orchestrator never makes a flow-decision based on a label alone (it would key on the actual GitHub state: PR draft? has reviews? CI green?). Labels can be added or omitted without affecting correctness.

The garden's current default is **draft-state only**; we have not yet built the dashboard machinery that would benefit from labels. Adding labels is a non-breaking enhancement when a future bulletin or summary view needs them.

## Maintainer entry point

The maintainer reviews only PRs that are out of draft. Before un-drafting, the flow's internal review (builder + assayer + jury including the saboteur + fixer loop + cleaner) is the quality bar; the bot's job is to make sure a PR in the maintainer's queue is genuinely ready for the maintainer's time.

A draft PR sitting in the bot's chain is not in the maintainer's queue; the maintainer should not be looking at it. The bulletin (in `journal/README.md`) lists ready-for-review PRs; draft PRs are tracked in the bot's own dashboards (e.g., the PR backlog section, with a `DRAFT` annotation) but not in the *Pending kriskowal reviews* section.

## Orchestrator's dispatch responsibilities

The orchestrator (liaison when a user is present, steward otherwise) is the dispatcher across all flow stages. Roles do not chain into one another directly: the builder does not dispatch the jury; the jury does not dispatch the fixer; the fixer does not re-dispatch the jury. The orchestrator does each step, reading the prior role's `result` entry and deciding the next dispatch.

Per-stage dispatch decisions:

- **Builder dispatched** when an issue or directive points at code that does not exist yet.
- **Assayer dispatched in concert** with the builder by default. Concurrent invocation against the same branch.
- **Jury dispatched** after the builder's `result` entry lands. Sequential or concurrent for the two seats.
- **Fixer dispatched** when the jury's verdict has must-fix items.
- **Jury re-dispatched** after the fixer's `result` entry lands.
- **Cleaner dispatched** when the jury declares the loop done (no further in-scope complaints).
- **Weaver dispatched first** if any of the above stages find the PR is `CONFLICTING`. The weaver rebases; the interrupted stage re-dispatches.

## Orchestrator chaining is load-bearing

The single-stage dispatch (build a PR and stop) is the **failure mode** this skill exists to prevent. A builder dispatch that lands a draft PR is *not* "done"; the PR is in the bot's chain, in draft state, with no maintainer review possible until the cleaner un-drafts. If no role advances it, the PR sits orphaned: the bot opens drafts the bot itself never finishes, the maintainer's queue stays empty, and the cycle of work never closes. Observed evidence (as of 2026-05-14): a backlog of garden-authored draft PRs on `endojs/endo-but-for-bots` whose builders returned without the orchestrator continuing the chain.

The discipline lives in two places: the **liaison** when a user-in-session dispatches a builder, and the **steward**'s per-cycle scan when no user is in the loop.

### The next-stage owed heuristic

For each open draft PR authored by the garden (`gh pr list -R <repo> --author kriscendobot --draft --state open`), the next stage owed is the first stage whose preceding stage's artifact exists but whose own artifact does not. Detection reads the PR state directly from GitHub, not from journal entries (which can lag, be misfiled, or describe a stage the orchestrator never dispatched).

Reading order, top to bottom; the first match is the stage owed:

1. **Cleaner has un-drafted?** PR is no longer draft. Flow complete; the PR is in the maintainer's queue. Nothing owed.
2. **Cleaner pushed and CI is green?** The cleaner should have un-drafted but did not. The orchestrator un-drafts directly (`gh pr ready <N>`) and surfaces the discipline lapse. Owed: un-draft.
3. **Jury submitted a `--approve` review (or `--comment` with no must-fix in-scope), with no later builder/fixer push?** Cleaner is owed.
4. **Jury submitted `--request-changes` with must-fix items, and the fixer has not yet pushed addressing commits since?** Fixer is owed.
5. **Fixer pushed since the last jury review, and the jury has not re-reviewed since the fixer's HEAD?** Jury re-review is owed.
6. **Builder's PR is open (any state) and no jury review exists yet?** Jury (the first pass) is owed. The assayer's in-concert pass, if it was going to happen, has either happened or been skipped by now; the absence of an assayer push is not a blocker.
7. **PR is `CONFLICTING` against its base?** Weaver is owed first, before any of the above. Re-evaluate the next-owed stage after the weaver returns.

A *jury-shaped review* is a `kriscendobot`-authored formal `gh pr review` (state `CHANGES_REQUESTED`, `COMMENTED`, or `APPROVED`) whose body matches the panel-review shape (in-scope / out-of-scope sections, must-fix / should-fix verdicts). A plain `gh pr comment` is not a jury review and does not advance the flow; the juror's role file requires the formal-review submission.

The orchestrator decides whether to dispatch concurrently (multiple PRs' next stages in one cycle) or rate-limit (one stage per PR per cycle) based on its own load. The steward's default is concurrent dispatch; the liaison's default is sequential and explicit (the user is in the loop and watching).

### Discipline

- A single-stage dispatch (the orchestrator dispatches a builder and the PR sits) is a **discipline violation**. The next orchestrator turn (liaison's next prompt, or the steward's next cycle) corrects it by reading the next-stage-owed and dispatching it.
- The orchestrator does not need a maintainer's per-PR authorization to advance a garden-authored draft PR through its own chain; the chain is the garden's normal operation. Authorization is only required for the cross-repo etiquette actions per `roles/COMMON.md` § External-repo etiquette (the boatman handoff, replying on inline review threads, posting top-level PR comments). The chain itself (builder push, assayer push, jury review submission, fixer push, cleaner push, un-draft) is implicit in each role's dispatch.
- A draft PR that has been quiet for more than one steward cycle without a clear "owed" stage is a signal that the heuristic is missing a case. Surface it via a `message` to `liaison` rather than guessing.

## Pitfalls

- **A non-cleaner role un-drafting is a discipline violation.** Only the cleaner un-drafts, and only after CI is green. A builder that opens a PR ready-for-review (skipping the draft) bypasses the entire flow; the orchestrator's first action on noticing is to `gh pr ready --undo <N>` and report the discipline violation.
- **The jury-fixer loop spinning on out-of-scope findings.** If a juror keeps re-raising a concern that is genuinely out of scope, the orchestrator promotes the concern to a separate follow-up and clears it from the loop. The loop's exit condition is "no in-scope complaints," not "all complaints addressed."
- **The cleaner pushing onto a CONFLICTING head.** The cleaner verifies `mergeable_state` before pushing; if `CONFLICTING`, surface "needs weaver" and stop.
- **A maintainer's `CHANGES_REQUESTED` reactivating the flow's draft state.** It does not. After the maintainer has reviewed, the loop is fixer to CI-green to re-request maintainer (no re-jury, no re-cleaner by default). The PR stays out of draft; the maintainer's review queue is the venue.
- **The flow skipping the cleaner step entirely on a tiny PR.** The cleaner step is still procedurally invoked (one dispatch); the cleaner reads the PR, decides no coverage work is warranted, and un-drafts. This keeps the un-draft authority routed through one role.

## Notes from the field

- _2026-05-13_: skill landed. The default assayer placement is in concert with the builder, the jury composition is a fixed juror plus saboteur pair, and labels are advisory while draft state is the load-bearing flag. These defaults are starting points; the notes-from-the-field below accumulate evidence as the flow runs and revisits them.
- _2026-05-13_: first builder/assayer/jury/cleaner dispatches will land when the maintainer next asks for work on a specific PR; this engagement is meta-evolution, not flow-running.
- _2026-05-14_: backlog of garden-authored draft PRs accumulated on `endojs/endo-but-for-bots` (#236, #237, #238, #239, #240, #241, #242, #243) because builder dispatches landed and the orchestrator stopped, treating the open draft as "done". The maintainer framed it as a systemic failure of chaining. Repair: the *Orchestrator chaining is load-bearing* section and the next-stage-owed heuristic above are now mandatory reading for the orchestrator, and the steward's per-cycle PR-creation-flow scan (see `roles/steward/AGENT.md` § PR-creation-flow scan) enforces the chain automatically. The maintainer's in-session liaison handles the existing backlog; future builder dispatches inherit the scan.
