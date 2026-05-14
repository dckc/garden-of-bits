---
created: 2026-05-14
updated: 2026-05-14
author: gardener
---

# Skill: merged-pr-feedback-watch

The gardener's procedure for periodically reading recently-merged PRs in the garden's primary upstream repos, extracting maintainer feedback patterns, looking for recurring themes and contradictions in current rules, and proposing "automatic and permanent solutions" (rule additions to roles or skills) that prevent the feedback from recurring on future PRs.

The maintainer's framing: feedback after merge is the most reliable signal. Pre-merge review feedback is filtered through the panel and the fixer's response; post-merge feedback (review comments left at merge time, follow-up issues, the maintainer's own commits that fix what the bot got wrong) reveals what the chain actually shipped versus what it should have.

This skill is the gardener's standing duty per `roles/gardener/AGENT.md` § Standing duties.

## When to run

- **On every gardener dispatch as the first or last act**, depending on the dispatch's primary task. If the dispatch is a focused role/skill change, run the watch at the end so the merged-PR signal informs the next gardener dispatch. If the dispatch is itself "read recent merged PRs for lessons," run the watch as the dispatch's primary work.
- **Recommended cadence**: weekly (every 7 days). The threshold for "land a rule" (see *Threshold* below) requires a pattern across 2+ merged PRs in the window; weekly is the shortest cadence that gives a typical week's merge volume enough density to surface duplicates. Faster cadences risk landing rules on single-sample observations; slower cadences let feedback patterns age before they become structural.
- **Out-of-cadence trigger**: an unusual surge of merged PRs (e.g., a release-prep batch) or an unusual amount of post-merge feedback (the maintainer leaves several review comments on a recently-merged PR) warrants an immediate pass.

## Inputs

### Repos to watch

The active set as of 2026-05-14:

- `endojs/endo-but-for-bots`: the garden's primary working repo; the most direct feedback loop.
- `endojs/endo`: the garden's primary mirror upstream; feedback there typically arrives via the boatman handoff and is filtered through one extra layer, but the signal is high-quality.

The set may grow when the maintainer adds repos to the garden's active monitored set. The set may shrink when a repo is collected; see `roles/COMMON.md` § Monitoring safety constraint.

### Time window

The last 14 days (two weeks) by default. The window's purpose is twofold: long enough that the merge volume yields a usable signal (typically 5 to 20 merged PRs per repo per fortnight on the active set), and short enough that the gardener is not re-digesting PRs that landed in a prior cycle.

### Comment-fetch commands

For each repo, fetch the merged PRs in the window and their comments:

```sh
# List merged PRs in the window
gh pr list -R <owner>/<repo> --state merged --limit 50 \
  --json number,title,mergedAt,author,headRefName \
  | jq '.[] | select(.mergedAt > "'$(date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)'")'

# For each PR, fetch reviews and review comments
gh pr view <N> -R <owner>/<repo> \
  --json reviews,comments,reviewRequests,number,title,mergedAt

# For each PR, fetch inline review comments (the "Conversation" tab's inline replies)
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate
```

The garden's primary feedback source is `kriskowal`'s review bodies and inline comments. Other reviewers' feedback is included but weighted less.

## State

The gardener records what it has already digested at:

```
journal/projects/<slug>/merged-pr-digests/<YYYY-MM-DD>.md
```

The most recent digest's `digested_through:` field names the latest `mergedAt` timestamp included. The next pass starts from that timestamp and reads forward. If no digest exists for the project yet, the first pass uses the 14-day window described above.

The digest entry itself is also a journal entry of `kind: digest`; see *Output shape* below for the per-pass digest entry. The `merged-pr-digests/` index is an aggregated rolling view, optional but recommended for projects with high merge volume.

## Procedure

1. **Pull the latest journal state.** Run `skills/journal-sync/SKILL.md` step 1 so the cycle reads the prior digest's `digested_through:` timestamp.
2. **Locate the prior digest** for each repo. If none, set the window's start to 14 days ago. Else set it to the prior `digested_through:`.
3. **List merged PRs** in the window using the commands above. The list is the work queue.
4. **For each PR**, fetch its reviews, top-level comments, and inline review comments. Read kriskowal's contributions first (highest signal); read other reviewers' contributions second.
5. **Extract patterns.** For each PR, write down (privately, in the working scratch) the maintainer-feedback themes: what was requested as a change, what was praised, what was repeated across multiple inline threads, what the maintainer's own post-merge commits fixed.
6. **Cross-PR aggregation.** Collect themes that appear across multiple PRs in the window. A theme that appears in 2+ PRs is a *recurring theme* and warrants a rule proposal. A theme that appears in only 1 PR is a *notes-from-the-field* observation, not a rule.
7. **Contradiction sweep.** Read the active `skills/` library for rules that the recurring themes contradict. Common contradiction shapes:
   - A skill rule says "do X" but the maintainer's feedback consistently says "don't do X here".
   - Two skills disagree about the same operation and the maintainer's feedback resolves the disagreement.
   - A skill cites an example that the maintainer has since clarified is no longer canonical.
   - A role's `## Skills` list cites a skill that has since been retired or split.
   One sweep per pass: also check that `pr-creation-flow` and the named-juror role files are internally consistent (the 2026-05-14 redesign created these files together, and the gardener verifies them on each pass until the redesign is well-exercised).
8. **Propose rule changes.** For each recurring theme or contradiction, draft the rule change as a one-paragraph entry in the digest. The change itself is landed by the next gardener dispatch (or by the liaison if the rule is structural enough to warrant user confirmation); this skill's deliverable is the digest, not the role/skill commit.
9. **Write the digest entry.** See *Output shape* below.

## Threshold

- **2+ merged PRs in the window**: the theme is recurring. Propose a rule change in the digest's *Proposed rules* section. The next gardener dispatch lands it (a rule, an example, a "Pitfalls" entry; see `skills/self-improvement/SKILL.md` § Where it goes for the routing).
- **1 merged PR in the window**: the theme is a single-sample observation. Add it to the digest's *Notes from the field* section. Do not propose a rule.
- **A theme that appeared in a prior digest's *Notes from the field* and reappears in this window's*: the cross-pass count is the threshold. Promote to *Proposed rules* and propose a rule change.

This matches `skills/self-improvement/SKILL.md` § Threshold for landing a change: one vivid observation is a note, a pattern across engagements is a rule. The digest is the gardener's way of tracking the "across engagements" count for feedback patterns.

## Output shape

A digest journal entry:

```markdown
---
ts: <UTC>
kind: digest
role: gardener
project: <slug>             # or repeat for each repo digested in this pass
digested_through: <UTC>     # latest mergedAt timestamp included in this pass
window_start: <UTC>         # earliest mergedAt this pass examined
window_pr_count: <N>        # how many merged PRs the pass read
refs:
  - entries/<YYYY>/<MM>/<DD>/<HHMMSS>Z-dispatch-liaison-<id>.md
---

# Merged-PR digest: <project>, <YYYY-MM-DD> to <YYYY-MM-DD>

## Summary

<one paragraph: how many PRs, what the dominant themes were, any flagged contradictions>

## Recurring themes

(Themes that appeared in 2+ merged PRs in the window.)

- **<theme>**: <one sentence summary>. PRs: #<N>, #<N>. Proposed rule: <link to the proposal below>.

## Notes from the field

(Single-sample observations. No rule change proposed; tracked for the next pass.)

- _<PR #N>_: <one sentence>.

## Contradictions found

(Rules in the active skills/ library that the recurring themes contradict.)

- **<skill>**: <one sentence on the contradiction and the proposed resolution>.

## Proposed rules

(Drafts for the next gardener dispatch to land.)

### <rule slug>

<target file>: add this rule to <section>:

> <rule prose, terse and imperative>

Rationale: <one paragraph naming the source PRs and the maintainer feedback that drives the rule>.

## Open questions

(Themes the gardener flagged but cannot land alone, typically because they imply a posture decision the maintainer should make.)

- <question>; written as a `message` to liaison if it needs to surface to the user.

Self-improvement: <one line per skills/self-improvement/SKILL.md>.
```

The digest is the gardener's working surface; the *Proposed rules* are the deliverable the next gardener dispatch (or the liaison) will land as role/skill edits.

## Contradiction sweep details

The contradiction sweep in step 7 above is its own discipline. Read each skill file and check for:

- **Cross-skill disagreement.** Two skills that name the same operation should agree on it. If they disagree, the digest's *Contradictions found* section names the pair and proposes which one is canonical (typically the one the maintainer's feedback supports).
- **Skill-vs-role disagreement.** A role's `## Skills` list cites a skill by path; if the role's prose contradicts the cited skill's rule, the skill is canonical (per `skills/self-improvement/SKILL.md` § Cost-benefit framing). The digest names the role and the contradiction.
- **Stale cross-references.** A skill or role cites another file by relative path; if the cited file has been renamed, split, or retired, the digest flags the stale link. The next gardener dispatch fixes it.
- **Voice drift.** Different agents write differently. A skill written in a chatty paragraph alongside terse-imperative siblings is a sign that the voice has drifted; the digest flags it for revision.

This sweep is a small part of each pass (5 to 10 minutes of reading); the bulk of the gardener's work is the merged-PR feedback extraction.

## Pitfalls

- **Single-sample reaction.** Landing a rule on one PR's feedback is `skills/self-improvement/SKILL.md` § Premature rules pitfall. The digest's *Notes from the field* section exists precisely to defer single-sample observations until they recur.
- **Re-digesting prior passes.** The `digested_through:` field is load-bearing; without it the gardener re-reads PRs already examined and surfaces the same patterns as fresh. The state path under `journal/projects/<slug>/merged-pr-digests/` is the canonical source; do not infer the cutoff from the digest entry's `ts:` field (which is when the digest was written, not when the watch's window ended).
- **Letting the contradiction sweep crowd out the feedback extraction.** The maintainer's feedback is the higher-signal half of this skill; the contradiction sweep is a useful background hygiene pass but should not become the pass's centerpiece.
- **Routing structural lessons through the digest.** The digest is the gardener's working surface, not a structural-change channel. If the recurring theme implies a new role, a role split, or a skill retirement, the digest names it under *Open questions* and writes a `message` to `liaison`; the actual structural change goes through the liaison per `skills/self-improvement/SKILL.md` § Where it goes.

## Notes from the field

- _2026-05-14_: skill landed alongside the jury-judge redesign. The merged-PR watch is the gardener's standing duty; the cadence is weekly. The first digest pass (after this skill is in place) will exercise the procedure end-to-end against `endojs/endo-but-for-bots` and `endojs/endo`. The skill is dispatched separately from this engagement per the dispatch's "out of scope" clause.
