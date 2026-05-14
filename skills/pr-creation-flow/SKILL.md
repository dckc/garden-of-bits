---
created: 2026-05-13
updated: 2026-05-14
author: gardener
---

# Skill: pr-creation-flow

The canonical procedure that ties the per-PR roles together: which role opens the PR, which roles touch it before the maintainer ever sees it, and which role decides it is ready for the maintainer's review queue. Read by every role the flow touches ([builder](../../roles/builder/AGENT.md), [assayer](../../roles/assayer/AGENT.md), [cleaner](../../roles/cleaner/AGENT.md), [judge](../../roles/judge/AGENT.md), the jury seats ([assessor](../../roles/assessor/AGENT.md), [typist](../../roles/typist/AGENT.md), [stylist](../../roles/stylist/AGENT.md), [packager](../../roles/packager/AGENT.md), [archivist](../../roles/archivist/AGENT.md), [prover](../../roles/prover/AGENT.md), [curator](../../roles/curator/AGENT.md), [migrator](../../roles/migrator/AGENT.md), [locksmith](../../roles/locksmith/AGENT.md), [warden](../../roles/warden/AGENT.md), [saboteur](../../roles/saboteur/AGENT.md), [breaker](../../roles/breaker/AGENT.md)), and [fixer](../../roles/fixer/AGENT.md)) and by the orchestrators ([liaison](../../roles/liaison/AGENT.md), [steward](../../roles/steward/AGENT.md)) that dispatch them.

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
   |  judge runs twelve juror dispatches (concurrent) + gh pr edit --add-reviewer @copilot
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
- **Design-only PR (no flow).** A draft PR whose only diff is a `designs/<slug>.md` file landed by the designer (per `roles/designer/AGENT.md` § Operating norms) is **not in the build → cleaner → judge → fixer chain**. The cleaner has no source surface to coverage-expand; the judge has no jury-reviewable contribution (no tests, no public-API surface, no behavior change); the panel-review shape does not apply. The orchestrator's per-cycle scan skips such PRs entirely. The PR stays in draft until the maintainer reviews it directly; the designer's role file (and the project's bot-fork roadmap branch convention recorded in `journal/projects/<slug>/README.md`) governs un-drafting, not the judge. A separate builder dispatch later implements the design as a master-base PR (see *Designs versus implementations* below).

## Designs versus implementations

Design PRs and implementation PRs are two separate PRs against two different bases. The maintainer's framing on 2026-05-14: "We don't carry designs onto the master branch. The designs should be based on llm. The implementations should be based on master, for those designs."

- A **design PR** lands on the project's bot-fork roadmap branch (today `llm` on `endojs/endo-but-for-bots`). The designer opens it in draft; its diff is the `designs/<slug>.md` file. It is **not** in this skill's flow chain (see *Design-only PR* variant above).
- An **implementation PR** lands on the project's natural implementation base (today `master` on `endojs/endo-but-for-bots`). A separate builder dispatch opens it; its diff is the source change that realizes the design. It **is** in this skill's flow chain (builder, assayer, cleaner, judge, fixer, un-draft).
- The boatman later ferries the implementation to the upstream `master` if and when the maintainer authorizes.
- Reference shape: `endojs/endo-but-for-bots#232` (Node-18-drop design on `llm`) and `endojs/endo-but-for-bots#246` (Node-18-drop master-base implementation, mirrored from `#232`).

The two PRs are intentionally not combined. A single PR carrying both the `designs/<slug>.md` file and the implementation source forces the maintainer to review documentation prose alongside source diff, dilutes the design review's audience (anyone interested in the design must filter implementation noise), and prevents the boatman from ferrying the implementation alone. The split also lets the implementation land before, with, or after the design at the maintainer's discretion.

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

The default jury is **twelve seats**, dispatched by the judge as one panel round. The 2026-05-14 redesign halved each of the prior six seats' responsibilities into two more-focused successor seats so the panel hits each inquiry area twice with one primary per area.

- [assessor](../../roles/assessor/AGENT.md): correctness logic, control flow, error handling. Secondary: invariant claims overlap with the breaker.
- [typist](../../roles/typist/AGENT.md): type accuracy (TS, JSDoc types, narrowings). Secondary: public-API signature correctness overlap with the curator.
- [stylist](../../roles/stylist/AGENT.md): naming and identifier choice. Secondary: doc-name accuracy overlap with the archivist.
- [packager](../../roles/packager/AGENT.md): diff hygiene, commit splitting, changeset content. Secondary: public-surface rename description overlap with the stylist and curator.
- [archivist](../../roles/archivist/AGENT.md): docs and comment / JSDoc prose accuracy. Secondary: naming-vs-docstring overlap with the stylist.
- [prover](../../roles/prover/AGENT.md): regression evidence (test load-bearingness). Secondary: correctness on the tested path overlap with the assessor.
- [curator](../../roles/curator/AGENT.md): public API surface, exported identifier shape. Secondary: bump-level correctness overlap with the migrator.
- [migrator](../../roles/migrator/AGENT.md): backwards compatibility, behavior under prior callers, peer-dep cascade, bump-level. Secondary: silent contract shifts on the public surface overlap with the curator.
- [locksmith](../../roles/locksmith/AGENT.md): capability flow and attenuation. Secondary: boundary-crossing capabilities overlap with the warden.
- [warden](../../roles/warden/AGENT.md): SES / hardened-JS boundary, harden discipline, unguarded globals, prototype pollution. Secondary: capability-on-boundary overlap with the locksmith.
- [saboteur](../../roles/saboteur/AGENT.md): adversarial inputs (boundary, type confusion, adversarial values, reentrancy, timing). Secondary: invariant adjacency overlap with the breaker.
- [breaker](../../roles/breaker/AGENT.md): invariant attacks against claimed contracts (`M.interface()`, attenuator promises, vat-boundary contracts). Secondary: capability-attack overlap with the locksmith.

Plus one fire-and-forget shell call alongside the twelve dispatches (not a separate `Agent` invocation):

```sh
gh pr edit <N> -R <owner>/<repo> --add-reviewer @copilot
```

### Why twelve seats with halved responsibilities

Maintainer's framing (2026-05-14): each seat should carry **half** of what the prior six-seat version did, so the panel can be deeper in each inquiry area without diluting any seat's focus. The earlier framing remains true ("each kind of review is conducted more than once, but a wide variety of concerns are evaluated"); the 2026-05-14 directive narrows the per-seat lens by splitting each prior seat into two successor seats with disjoint primary surfaces and one deliberate overlap each.

Splits, one line per prior seat:

- **assessor** split into `assessor` (correctness logic and control flow) plus `typist` (type accuracy). Rationale: the typist's lens (JSDoc / TS type accuracy) is mechanically distinct from logic correctness and benefits from a dedicated reader.
- **stylist** split into `stylist` (naming only) plus `packager` (diff hygiene, commit splitting, changeset). Rationale: naming is a code-side concern; the packager's lens is the shape of the PR itself.
- **archivist** split into `archivist` (docs and comment prose) plus `prover` (regression evidence). Rationale: the regression-evidence audit is procedural (would the test reden if reverted) and warrants a dedicated reader; the archivist's lens stays on prose accuracy.
- **curator** split into `curator` (public surface and signature shape) plus `migrator` (backwards compat, peer-dep cascade, bump-level). Rationale: the curator inventories what changed; the migrator audits what depends on it.
- **locksmith** split into `locksmith` (capability flow and attenuation) plus `warden` (SES boundary, harden discipline, prototype pollution). Rationale: capability flow inside the module is mechanically distinct from the SES / hardened-JS boundary discipline.
- **saboteur** split into `saboteur` (adversarial inputs) plus `breaker` (invariant attacks against claimed contracts). Rationale: input-shape attacks target the code's behavior; invariant attacks target the code's published contract.

Smaller panels (3 to 6 seats) remain valid for tiny PRs when the orchestrator names a reduced composition in the dispatch brief; the reference's 12-perspective panel is now the default rather than an override.

### Concurrency

The judge dispatches the twelve seats **concurrently by default**. Twelve sequential `Agent` invocations would compound wall-clock cost beyond what the chain can absorb. The judge sends the panel out in parallel, waits for all twelve results to land, then aggregates. Sequential dispatch remains valid when the orchestrator explicitly requests it (e.g., for a panel where one seat's findings should inform another's), but is not the working default at twelve seats. The deliverable shape is the same either way: one aggregated panel verdict, one formal `gh pr review` submission from the judge.

When the harness does not surface an `Agent` (or `Task`) tool to the judge subagent, the judge falls back to the in-band procedure named in `roles/judge/AGENT.md` § In-band fallback: each seat's block is written one at a time against the per-seat role file's primary surface, aggregation runs after all twelve blocks land, and one formal `gh pr review` is still submitted. The `result` entry names the panel-execution mode for audit.

### Copilot as a thirteenth reviewer

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
2. **PR's diff is design-only (a single `designs/<slug>.md` file or sibling design files, no source / no tests)?** Not in this flow's chain. Skip entirely; the maintainer reviews directly. See the *Design-only PR* variant under *Flow ordering* and the *Designs versus implementations* section above. The orchestrator's per-cycle scan does not dispatch a cleaner, judge, or fixer against such PRs.
3. **Judge has un-drafted?** PR is no longer draft. Flow complete; the PR is in the maintainer's queue. Nothing owed.
4. **Panel `--approve` (or `--comment` with no in-scope must-fix) submitted, with no later builder/fixer push, but the PR is still draft?** The judge should have un-drafted but did not. The orchestrator un-drafts directly (`gh pr ready <N>`) and surfaces the discipline lapse. Owed: un-draft.
5. **Panel verdict has must-fix items, and the fixer has not yet pushed addressing commits since?** Fixer is owed.
6. **Fixer pushed since the last panel verdict, and the judge has not re-dispatched the panel since the fixer's HEAD?** Judge re-dispatch is owed.
7. **Cleaner pushed and CI is green (or only documented pre-existing infra red), and no panel verdict yet?** Judge is owed. (On the cleaner-skipped tiny-PR variant, the orchestrator dispatches the judge directly when no cleaner is owed and no panel verdict exists; see the qualifier in step 8.)
8. **Builder's PR is open and no cleaner push exists yet?** Cleaner is owed (default). On the tiny-PR variant (pure docs, lockfile-only, one-file format sweep, single-line bug fix with test fixture already in the diff), skip the cleaner and dispatch the judge instead. The orchestrator decides which variant applies by inspecting the diff.

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
- _2026-05-14_ (same day, later): twelve-seat panel. The maintainer's directive was to halve each seat's responsibilities. Each of the six prior seats split into two successor seats: assessor → assessor + typist, stylist → stylist + packager, archivist → archivist + prover, curator → curator + migrator, locksmith → locksmith + warden, saboteur → saboteur + breaker. Concurrent dispatch became the explicit default at this size; sequential dispatch is an override. Smaller panels (3 to 6 seats) remain valid when the dispatch brief names a reduced composition.
- _2026-05-14_ (same day, later still): design / implementation split codified. Maintainer directive after the SES top-level-await and SES import-attributes designers landed: designers default to opening draft PRs against the project's bot-fork roadmap branch (today `llm` on `endojs/endo-but-for-bots`); design PRs are not in this flow's chain (no cleaner, no judge, no jury); implementations of those designs are separate builder dispatches that land on the project's natural implementation base (today `master`). Node-18-drop pattern (`#232` design on `llm`, `#246` master-base mirror) is the reference shape. The next-stage-owed heuristic gained a step 2 that skips design-only PRs; the *Design-only PR* variant under Flow ordering and the new *Designs versus implementations* section above carry the rule.
