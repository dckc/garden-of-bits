---
created: 2026-05-13
updated: 2026-05-14
author: gardener
---

# Skill: pr-creation-flow

The canonical procedure that ties the per-PR roles together: which role opens the PR, which roles touch it before the maintainer ever sees it, and which role decides it is ready for the maintainer's review queue. Read by every role the flow touches ([builder](../../roles/builder/AGENT.md), [assayer](../../roles/assayer/AGENT.md), [cleaner](../../roles/cleaner/AGENT.md), [judge](../../roles/judge/AGENT.md), the jury seats ([assessor](../../roles/assessor/AGENT.md), [stylist](../../roles/stylist/AGENT.md), [archivist](../../roles/archivist/AGENT.md), [curator](../../roles/curator/AGENT.md), [locksmith](../../roles/locksmith/AGENT.md), [saboteur](../../roles/saboteur/AGENT.md)), and [fixer](../../roles/fixer/AGENT.md)) and by the orchestrators ([liaison](../../roles/liaison/AGENT.md), [steward](../../roles/steward/AGENT.md)) that dispatch them.

The skill is the orchestration map. Per-role detail (how to write a test, how to address a review thread, how to delete dead code) lives in the role files and the role-specific skills.

## When to use

- The orchestrator dispatches a builder against an issue or design. The flow starts here.
- A maintainer asks for a fresh PR. The flow is the same.
- A cold PR opened by someone else gets a jury panel after the fact. The flow's cleaner and judge stages still apply; only the builder stage is skipped.

## Draft discipline

**The builder opens every PR in draft state**: `gh pr create --draft` (or the API equivalent with `draft: true`). The draft flag is the load-bearing signal that the bot-side chain has not yet finished. **The judge is the only role that moves the PR out of draft** (`gh pr ready <N>`), and only when the jury-fixer loop terminates with no in-scope must-fix.

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
cleaner (coverage pass; dead-code; same branch)
   |
   |  cleaner pushes coverage commits, watches CI converge
   v
judge (foreperson; dispatches the jury panel)
   |
   |  judge runs six juror dispatches + gh pr edit --add-reviewer @copilot
   v
jury panel verdict (judge aggregates, submits formal gh pr review)
   |
   |  if must-fix items, the orchestrator dispatches a fixer
   v
fixer --pushes follow-up commits
   |
   v
judge re-dispatches the same panel against the fixer's head
   |
   |  loop until the panel surfaces no further in-scope must-fix
   v
gh pr ready <N>  (judge un-drafts; PR enters maintainer's review queue)
```

Variants:

- **Cleaner-skipped tiny-PR variant.** When the PR is pure documentation, lockfile-only churn, a one-file format sweep, or a single bug-fix line whose test fixture is already in the diff, the cleaner has no coverage surface to expand. The orchestrator skips the cleaner and **dispatches the judge directly after the builder**. There is no procedural no-op cleaner stage; the cleaner is skipped, not run-as-a-no-op. The judge still runs the panel and un-drafts at the end of the loop.
- **No must-fix on first panel round.** The fixer step is skipped. The judge declares the loop done after the first panel verdict and un-drafts immediately.
- **Pre-merge fix-up rounds (after maintainer review).** The maintainer's `CHANGES_REQUESTED` triggers the standard fixer loop (fixer to CI-green to re-request maintainer); neither the cleaner nor the judge re-runs by default. The PR stays out of draft; the maintainer's review queue is the venue. A maintainer who explicitly asks for a fresh cleaner or judge pass overrides this default.

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

## Cleaner placement

The cleaner stands **between the builder (and any in-concert assayer) and the judge**. By the time the panel reads the PR, the test surface has been expanded and dead code is gone, so the panel reviews the final shape rather than a half-tested draft. The cleaner's remit:

- Run a coverage pass on the package(s) the PR touched, per `skills/coverage-driven-testing/SKILL.md`.
- Push coverage commits to the same branch.
- Watch CI converge to green (or only documented pre-existing infra red) on the cleaner's own HEAD.
- Report done. **The cleaner does not un-draft.**

Un-draft authority moved from the cleaner to the judge in the 2026-05-14 redesign. The maintainer's framing on the move: "I don't see the cleaner as a juror since it both writes and runs tests, which is to say, it should continue to stand between the builder and the jury." The cleaner is explicitly **not a juror**; its mutating work (writing and running tests) does not fit the read-only review posture the panel seats hold.

If the PR is `CONFLICTING` against its base when the cleaner arrives, the cleaner does not push coverage commits onto a non-mergeable head. It surfaces "needs a weaver before cleaner" and the orchestrator dispatches a weaver first.

## Jury composition

The default jury is **six seats**, dispatched by the judge as one panel round:

- [assessor](../../roles/assessor/AGENT.md): correctness, types, control flow, performance / complexity. Secondary: regression-evidence overlap with the archivist.
- [stylist](../../roles/stylist/AGENT.md): naming, diff hygiene, changeset content. Secondary: public-surface naming overlap with the curator.
- [archivist](../../roles/archivist/AGENT.md): docs, regression evidence, comment / JSDoc accuracy. Secondary: naming clarity overlap with the stylist.
- [curator](../../roles/curator/AGENT.md): API stability, public surface, backwards compatibility. Secondary: correctness on interface boundaries overlap with the assessor.
- [locksmith](../../roles/locksmith/AGENT.md): security, capabilities, attenuation, SES boundary. Secondary: correctness on capability edges overlap with the assessor.
- [saboteur](../../roles/saboteur/AGENT.md): adversarial inputs, invariant attacks. Secondary: security adjacency overlap with the locksmith.

Plus one fire-and-forget shell call alongside the six dispatches (not a separate `Agent` invocation):

```sh
gh pr edit <N> -R <owner>/<repo> --add-reviewer @copilot
```

### Why six seats with deliberate overlap

Maintainer's framing (2026-05-14): "each kind of review is conducted more than once, but a wide variety of concerns are evaluated." Six seats lets every named inquiry area in this skill be touched by at least two seats (the "secondary overlap" in each juror's role file). The areas covered: correctness/types, naming/diff/changeset, docs/regression-evidence, API stability, security/capabilities, adversarial/invariants, performance/complexity. Four or five seats would force one seat to carry two unrelated areas; seven or more dilutes focus per seat.

The orchestrator (liaison or steward) may pick a different composition by naming jurors in the dispatch prompt. Smaller panels (3 seats) are valid for tiny PRs; larger ones (the reference's 12-perspective panel) are valid for large or unusually risky ones. The default is six.

### Concurrency

The judge dispatches the six seats sequentially or concurrently at its discretion. Concurrent is cheaper wall-clock and is the working default. Sequential lets one seat's findings inform another (e.g., the saboteur's attack can be informed by the assessor's correctness reading), but with six seats the wall-clock cost adds up. The deliverable shape is the same either way: one aggregated panel verdict, one formal `gh pr review` submission from the judge.

### Copilot as a seventh reviewer

The `@copilot` `gh pr edit --add-reviewer` call is fire-and-forget. The `@copilot` token is `gh`'s canonical handle for the Copilot reviewer; the login that appears in `reviewRequests` and `reviews[].author.login` afterward is `copilot-pull-request-reviewer`. Copilot leaves a `COMMENTED` review on its own schedule (typically minutes); the judge does not poll or block on it. If Copilot's review has landed by the time the judge writes the panel's formal `gh pr review`, the judge considers it part of the panel's reading; otherwise the panel proceeds without it. The `gh pr edit` is idempotent for the same reviewer; on a re-round it re-requests Copilot's review.

Copilot is added only when the judge dispatches a panel. The orchestrator does not add Copilot to PRs outside the judge-dispatch flow.

## Jury-fixer loop

After the judge submits the panel's verdict:

1. **If the verdict has must-fix items**: the orchestrator dispatches a fixer with the must-fix list inline as the brief. The fixer addresses each item (or replies on threads citing why an item is verified-no-change or deferred), pushes follow-up commits, and reports done.
2. **The orchestrator re-dispatches the judge** with the fixer's `result` cited. The judge re-dispatches the same panel (or an equivalent one), briefed with the prior verdict plus the fixer's response so each juror verifies the prior must-fix items are addressed and surfaces any *new* in-scope finding the fix introduced.
3. **Loop until the panel surfaces no further in-scope complaints.** In-scope means a problem the PR's change introduced or directly touched. Out-of-scope complaints (adjacent refactors, package-wide hygiene) go in the "Out of scope / follow-up" section of the panel report and become candidate follow-up PRs or issues; they do not block the loop.
4. **When the judge declares the loop done** (an `--approve` verdict or a `--comment` verdict with no must-fix or should-fix items in scope), the judge runs `gh pr ready <N>` to un-draft.

Loop-exit discipline: the panel cannot block the loop on out-of-scope findings. If a juror keeps surfacing the same out-of-scope concern across rounds, the judge promotes the concern to a separate issue and clears it from the loop.

## Maintainer entry point

The maintainer reviews only PRs that are out of draft. Before un-drafting, the flow's internal review (builder + assayer + cleaner + jury panel + fixer loop) is the quality bar; the bot's job is to make sure a PR in the maintainer's queue is genuinely ready for the maintainer's time.

A draft PR sitting in the bot's chain is not in the maintainer's queue; the maintainer should not be looking at it. The bulletin (in `journal/README.md`) lists ready-for-review PRs; draft PRs are tracked in the bot's own dashboards (e.g., the PR backlog section, with a `DRAFT` annotation) but not in the *Pending kriskowal reviews* section.

## State on the PR

The flow encodes position in two layers:

- **Draft vs ready-for-review** (load-bearing). Draft means the bot-side chain is in progress; ready-for-review means the judge has un-drafted and the maintainer's queue is the next venue.
- **Labels** (advisory). When useful, the bot can annotate the PR with labels like `state:building`, `state:cleaning`, `state:in-review`, `state:fixing`, `state:ready`. These are for the bot's own dashboard and dispatch-decision triage. Labels are not load-bearing; the orchestrator never makes a flow-decision based on a label alone (it would key on the actual GitHub state: PR draft? has reviews? CI green?). Labels can be added or omitted without affecting correctness.

The garden's current default is **draft-state only**; we have not yet built the dashboard machinery that would benefit from labels. Adding labels is a non-breaking enhancement when a future bulletin or summary view needs them.

## Orchestrator's dispatch responsibilities

The orchestrator (liaison when a user is present, steward otherwise) is the dispatcher across all flow stages **with one exception**: the judge dispatches the jurors itself, because the panel composition is the judge's contract. The orchestrator dispatches the builder, the assayer (in concert), the cleaner, the judge, and the fixer (when a panel verdict has must-fix). The orchestrator does **not** dispatch individual jurors; that is the judge's job.

Per-stage dispatch decisions:

- **Builder dispatched** when an issue or directive points at code that does not exist yet.
- **Assayer dispatched in concert** with the builder by default. Concurrent invocation against the same branch.
- **Cleaner dispatched** when the builder's (and any in-concert assayer's) `result` entries have landed, or skipped on the tiny-PR variant above.
- **Judge dispatched** when the cleaner's `result` lands (or directly after the builder on the cleaner-skipped variant). The judge dispatches the panel from there.
- **Fixer dispatched** when the judge's panel verdict has must-fix items.
- **Judge re-dispatched** after the fixer's `result` entry lands. The judge re-runs the panel; the orchestrator does not.
- **Weaver dispatched first** if any of the above stages find the PR is `CONFLICTING`. The weaver rebases; the interrupted stage re-dispatches.

## Orchestrator chaining is load-bearing

The single-stage dispatch (build a PR and stop) is the **failure mode** this skill exists to prevent. A builder dispatch that lands a draft PR is *not* "done"; the PR is in the bot's chain, in draft state, with no maintainer review possible until the judge un-drafts. If no role advances it, the PR sits orphaned: the bot opens drafts the bot itself never finishes, the maintainer's queue stays empty, and the cycle of work never closes. Observed evidence (as of 2026-05-14): a backlog of garden-authored draft PRs on `endojs/endo-but-for-bots` whose builders returned without the orchestrator continuing the chain.

The discipline lives in two places: the **liaison** when a user-in-session dispatches a builder, and the **steward**'s per-cycle scan when no user is in the loop.

### The next-stage-owed heuristic

For each open draft PR authored by the garden (`gh pr list -R <repo> --author kriscendobot --draft --state open`), the next stage owed is the first stage whose preceding stage's artifact exists but whose own artifact does not. Detection reads the PR state directly from GitHub, not from journal entries (which can lag, be misfiled, or describe a stage the orchestrator never dispatched).

Reading order, top to bottom; the first match is the stage owed:

1. **PR is `CONFLICTING` against its base?** Weaver is owed first, before any of the below. Re-evaluate the next-owed stage after the weaver returns.
2. **Judge has un-drafted?** PR is no longer draft. Flow complete; the PR is in the maintainer's queue. Nothing owed.
3. **Panel `--approve` (or `--comment` with no in-scope must-fix) submitted, with no later builder/fixer push, but the PR is still draft?** The judge should have un-drafted but did not. The orchestrator un-drafts directly (`gh pr ready <N>`) and surfaces the discipline lapse. Owed: un-draft.
4. **Panel verdict has must-fix items, and the fixer has not yet pushed addressing commits since?** Fixer is owed.
5. **Fixer pushed since the last panel verdict, and the judge has not re-dispatched the panel since the fixer's HEAD?** Judge re-dispatch is owed.
6. **Cleaner pushed and CI is green (or only documented pre-existing infra red), and no panel verdict yet?** Judge is owed. (On the cleaner-skipped tiny-PR variant, the orchestrator dispatches the judge directly when no cleaner is owed and no panel verdict exists; see the qualifier in step 7.)
7. **Builder's PR is open and no cleaner push exists yet?** Cleaner is owed (default). On the tiny-PR variant (pure docs, lockfile-only, one-file format sweep, single-line bug fix with test fixture already in the diff), skip the cleaner and dispatch the judge instead. The orchestrator decides which variant applies by inspecting the diff.

A *panel verdict* is a `kriscendobot`-authored formal `gh pr review` (state `CHANGES_REQUESTED`, `COMMENTED`, or `APPROVED`) whose body matches the panel-review shape (in-scope / out-of-scope sections, must-fix / should-fix verdicts). A plain `gh pr comment` is not a panel verdict and does not advance the flow; the judge's role file requires the formal-review submission.

The orchestrator decides whether to dispatch concurrently (multiple PRs' next stages in one cycle) or rate-limit (one stage per PR per cycle) based on its own load. The steward's default is concurrent dispatch; the liaison's default is sequential and explicit (the user is in the loop and watching).

### Discipline

- A single-stage dispatch (the orchestrator dispatches a builder and the PR sits) is a **discipline violation**. The next orchestrator turn (liaison's next prompt, or the steward's next cycle) corrects it by reading the next-stage-owed and dispatching it.
- The orchestrator does not need a maintainer's per-PR authorization to advance a garden-authored draft PR through its own chain; the chain is the garden's normal operation. Authorization is only required for the cross-repo etiquette actions per `roles/COMMON.md` § External-repo etiquette (the boatman handoff, replying on inline review threads, posting top-level PR comments). The chain itself (builder push, assayer push, cleaner push, panel verdict submission, fixer push, un-draft) is implicit in each role's dispatch.
- A draft PR that has been quiet for more than one steward cycle without a clear "owed" stage is a signal that the heuristic is missing a case. Surface it via a `message` to `liaison` rather than guessing.

## Pitfalls

- **A non-judge role un-drafting is a discipline violation.** Only the judge un-drafts, and only after the panel declares the loop done. A builder that opens a PR ready-for-review (skipping the draft) bypasses the entire flow; the orchestrator's first action on noticing is to `gh pr ready --undo <N>` and report the discipline violation.
- **The cleaner un-drafting is a discipline violation.** The 2026-05-14 redesign moved un-draft authority from the cleaner to the judge. A cleaner that runs `gh pr ready <N>` is operating on an outdated role file; the orchestrator surfaces the lapse and the next gardener dispatch refreshes the cleaner's worktree.
- **The jury-fixer loop spinning on out-of-scope findings.** If a juror keeps re-raising a concern that is genuinely out of scope, the judge promotes the concern to a separate follow-up and clears it from the loop. The loop's exit condition is "no in-scope complaints," not "all complaints addressed."
- **The cleaner pushing onto a CONFLICTING head.** The cleaner verifies `mergeable_state` before pushing; if `CONFLICTING`, surface "needs weaver" and stop.
- **A maintainer's `CHANGES_REQUESTED` reactivating the flow's draft state.** It does not. After the maintainer has reviewed, the loop is fixer to CI-green to re-request maintainer (no re-cleaner, no re-judge by default). The PR stays out of draft; the maintainer's review queue is the venue.
- **The orchestrator dispatching individual jurors directly.** The judge dispatches the jurors; the orchestrator dispatches the judge. A liaison or steward that dispatches a juror role directly bypasses the panel's aggregation and produces a finding without a verdict the dispatch matrix can read. The exception is a maintainer's explicit directive ("run an assessor on PR #N"), which the orchestrator can honor; the deliverable is then the juror's `result` entry, not a panel verdict.

## Notes from the field

- _2026-05-13_: skill landed. The default assayer placement is in concert with the builder, the jury composition was a fixed juror plus saboteur pair, and labels were advisory while draft state was the load-bearing flag.
- _2026-05-14_: backlog of garden-authored draft PRs accumulated on `endojs/endo-but-for-bots` (#236, #237, #238, #239, #240, #241, #242, #243) because builder dispatches landed and the orchestrator stopped, treating the open draft as "done". The maintainer framed it as a systemic failure of chaining. Repair: the *Orchestrator chaining is load-bearing* section and the next-stage-owed heuristic above are now mandatory reading for the orchestrator, and the steward's per-cycle PR-creation-flow scan (see `roles/steward/AGENT.md` § PR-creation-flow scan) enforces the chain automatically.
- _2026-05-14_: jury-judge redesign. The single generic `juror` role split into five named seats (assessor, stylist, archivist, curator, locksmith) plus the existing saboteur for six total, with deliberate overlap so every inquiry area is touched by at least two seats. The judge role was added as the panel's foreperson (dispatches the jurors, aggregates, submits one verdict, un-drafts on loop completion). The cleaner moved from last-in-the-chain to between-builder-and-jury, and lost un-draft authority. Old single-stage juror-plus-saboteur panels remain valid by maintainer override; the default is the six-seat panel.
