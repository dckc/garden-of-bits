---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: rule-elision-test

Test whether a rule stated in a role or skill is intuitive enough to elide. Used to compact roles and skills: a rule that a fresh subagent applies reliably without being told does not need to be in the front of that role's context, only in a tracked record.

## What this skill tests (and what it does not)

The literal test is: "given the full context this role normally reads (the synthetic role file, `roles/COMMON.md`, cited skills, and the journal it greps for project context), does removing the explicit statement of this rule from the role file change the agent's behavior?"

That is **not** the same as "would an agent intuit this rule from scratch in any context?" Other parts of the role file, the cited skills, and historical journal entries can all carry the rule's substance even when the explicit statement is gone. A passing test means the explicit statement is not load-bearing within our garden's full context. A passing test does not mean the rule is universally intuitive.

This is fine for the skill's stated purpose (compaction). The thing we are deciding is whether the explicit statement earns its keep in the role file, given everything else the agent reads. If the rule is implied or restated elsewhere, the explicit version is redundant by definition.

## When to use

- A role or skill is becoming hard to read at one screen and a candidate rule looks like an obvious-thing-anyone-would-do.
- A new rule is being proposed; check whether it is necessary to state at all before adding it.
- Periodic compaction pass on a long-running role's accumulated norms.

The liaison runs this skill. The steward does not (compaction is meta-evolution, the liaison's purview).

## Procedure

### 1. Identify and frame the rule

Pick exactly one rule from one role or skill. State it precisely in one or two sentences. Identify the file and the lines it occupies.

A rule that bundles multiple distinct constraints is too coarse to test. Split first.

### 2. Construct three test scenarios

Design three hypothetical situations where:

- The rule, if applied, produces a specific identifiable behavior.
- The scenario is realistic for the role (the kind of situation it would actually encounter).
- The agent has all context needed to make a judgment.
- The scenario does **not** telegraph the rule. Avoid leading language ("given that you must X, would you...").

Three scenarios catch scenario-design flukes. One positive trial is not evidence; three independent positives are.

### 3. Stage a synthetic role file (and check for in-file restatements)

Copy the canonical role file to a tmp location with the rule excised. Do **not** edit the canonical file in place: that risks leaving the rule deleted if the test is interrupted.

```sh
TEST_DIR=/tmp/rule-elision-$(openssl rand -hex 3)
mkdir -p "$TEST_DIR/roles/<role>"
cp roles/<role>/AGENT.md "$TEST_DIR/roles/<role>/AGENT.md"
# Then edit "$TEST_DIR/roles/<role>/AGENT.md" to remove the rule.
```

After removing the rule's bullet, **scan the rest of the synthetic file for restatements**: the role's intro, the Done section, the dispatch-inputs section, and any pre-existing examples may carry the rule's substance under different words. If they do, the test will pass trivially (the agent picks up the rule from the restatement, not from intuition or wider context). Two choices when restatements exist:

- **Tighten the synthetic file** by also redacting the restatement, then test what is left. This tests "is the rule load-bearing across the whole file?" — the strictest version.
- **Acknowledge the restatement** and report the test result as "rule is implied by §<section>; the explicit bullet is redundant." Compact accordingly. Slightly weaker conclusion, faster to reach.

Pick the second when the restatement is itself a load-bearing statement that should stay regardless. The Done section's "PR is open" is a contract with the dispatcher, not a redundant copy of an operating norm; redacting it would mis-test.

### 3b. Check for journal and skill side channels

Before dispatching, list the readings the test agent will perform beyond the synthetic role file:

- **Cited skills**: anything `roles/<role>/AGENT.md` references in its Skills section. If a cited skill mentions the rule, the test isn't independent. Either stage a synthetic version of that skill too, or accept the leak and report it.
- **`roles/COMMON.md`**: read fresh from the canonical garden by every subagent. If COMMON.md mentions the rule, stage a synthetic COMMON.md.
- **Journal grep**: a thorough subagent will `grep -rl '^project: <slug>' journal/entries/` (or grep for the role name) to recover prior context. If past entries restate the rule (especially the entry that originally added the role to the garden), the test isn't independent. Either:
  - Instruct the test agent in the dispatch prompt to skip historical journal grep ("for this exercise, do not consult historical journal entries beyond your own dispatch"), or
  - Run the grep yourself first, identify any leaking entries, and document them as side-channel context the test could not control.

The skill cannot fully eliminate side channels in our orphan-branch model. Acknowledge what leaked; report the test's confidence accordingly.

### 4. Dispatch the test subagent for each scenario

For each of the three scenarios, dispatch a fresh subagent. The dispatch prompt overrides the canonical role-file path:

```
You are a subagent operating as role=<role>. For this test, read the
synthetic role file at <TEST_DIR>/roles/<role>/AGENT.md instead of the
canonical roles/<role>/AGENT.md, and read roles/COMMON.md from the
canonical garden as usual.

Scenario: <scenario text>

How would you proceed? Be specific about the actions you would take
and the order you would take them in.
```

Three independent dispatches; do not let one influence the next. Capture each response verbatim.

### 5. Score the responses

For each response, classify:

- **Intuitive**: the agent's plan complies with the rule's spirit, even without quoting it.
- **Partial**: the agent's plan touches the rule but misses an important aspect.
- **Missed**: the agent's plan would violate the rule.

A rule passes the test only when **all three** are intuitive. Anything else means the rule stays.

### 6. Compact if the rule passed

If the rule passed:

1. Remove the rule from the canonical role/skill file.
2. Write a journal `message` entry recording: the rule text, the file and lines it was elided from, the three scenarios and a one-line summary of each agent response, the new role/skill commit SHA. Tag the entry frontmatter with `subject_matter: [rule-elision]` (and the role's slug as a project tag if applicable) so future searches can find elision history.
3. Optionally, append a one-line entry to `roles/<role>/intuitive.md` (create if not present): `<YYYY-MM-DD>: <one-line rule summary> (see journal entry <relative-path>)`. This file is data, not directive; it is **not** loaded into agent context, only consulted when the maintainer asks "what rules used to be in this role?". The journal entry is the canonical record; the file is human-friendly browse.

If the rule did not pass:

- Leave the rule in place.
- Optionally write a journal `message` entry recording the test result for future reference, especially if a failure mode was instructive.

### 7. Clean up

```sh
rm -rf "$TEST_DIR"
```

## Cost-benefit

The test costs three subagent dispatches per rule plus the liaison's reading and judgment. That is cheap relative to the recurring cost of a stated rule (loaded on every role invocation forever).

A role with twenty norms whose top five are non-intuitive and bottom fifteen are intuitive will benefit substantially from elision. A role with five tight non-intuitive norms is already compact; elision testing on it is wasted effort.

## Pitfalls

- **Bad scenarios.** A scenario that telegraphs the rule produces false positives. A scenario too narrow for the role produces false negatives. Three diverse scenarios mitigate but do not eliminate; review the scenarios for leading language before dispatching.
- **Compound rules.** Splitting first is mandatory. Testing "do X under condition Y unless Z" as one rule confuses every step of scoring.
- **Scenario contamination.** If the scenario itself contains the rule's keywords or principle, the test is not independent. Strip leading language; describe the situation, not the principle.
- **Borderline (two of three pass).** The rule is borderline; keep it. Optionally re-run with three fresh scenarios later before deciding.
- **Model drift.** A rule intuitive for today's model may not be for a future or smaller model. The journal entry (and optional `intuitive.md`) lets a later session re-derive the rule if a regression makes it relevant again.
- **Side channel via COMMON.md.** The synthetic role file removes the rule, but `roles/COMMON.md` is read from the canonical garden. If COMMON.md mentions or implies the rule, the test is not independent. When testing a rule that cross-references COMMON.md, stage a synthetic COMMON.md too.
- **Side channel via the rest of the role file.** The Done section, the role's intro, the dispatch-inputs section, and inline examples can all restate the rule's substance under different words. Step 3 above scans for these and decides whether to redact them too or acknowledge the restatement.
- **Side channel via cited skills.** Skills the role's `## Skills` section names get read by the test agent. If a cited skill restates the rule, the test isn't independent. Stage a synthetic skill or accept the leak and report it.
- **Side channel via journal history.** Subagents grep `journal/entries/` for project context. The journal entries written when the rule was first added (or recently revisited) may restate the rule and feed it back into the test. Either tell the test agent to skip historical journal grep, or grep yourself first, find the leaks, and report them as side-channel context.
- **Confidence calibration.** A pass with no detected side channels is strong evidence the explicit statement is not load-bearing. A pass with a known restatement somewhere the agent reads is a weaker claim ("the explicit bullet is redundant given §<X>"); compact still, but cite the restatement in the journal entry.

## Notes from the field

(Append; do not rewrite history.)

- _2026-05-12_: first exercise, on the boatman role's "Don't merge" rule. All three test agents stopped at "open the upstream PR" with no merge step (literal pass). However: the role's Done section restates "Upstream PR open", and the journal entry that originally added the boatman role to the garden contains the phrase "opens the upstream PR and stops; merging is a human decision". Both leaked into the test. The pass is therefore the weaker claim (the explicit bullet is redundant given Done and prior journal context), not the stronger claim (the rule is intuitive in any context). The "What this skill tests" framing and the side-channel pitfalls in this skill were rewritten in response. Did not elide the rule on this run; the procedure that found the leak is more valuable than the marginal compaction would have been.
