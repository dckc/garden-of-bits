---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: rule-elision-test

Test whether a rule stated in a role or skill is intuitive enough to elide. Used to compact roles and skills: a rule that a fresh subagent applies reliably without being told does not need to be in the front of that role's context, only in a tracked record.

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

### 3. Stage a synthetic role file

Copy the canonical role file to a tmp location with the rule excised. Do **not** edit the canonical file in place: that risks leaving the rule deleted if the test is interrupted.

```sh
TEST_DIR=/tmp/rule-elision-$(openssl rand -hex 3)
mkdir -p "$TEST_DIR/roles/<role>"
# Hand-edit the synthetic file: copy the canonical and strip the rule.
cp roles/<role>/AGENT.md "$TEST_DIR/roles/<role>/AGENT.md"
# Then edit "$TEST_DIR/roles/<role>/AGENT.md" to remove the rule.
```

The synthetic file lives only for the test. Delete `$TEST_DIR` after.

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

## Notes from the field

(Append; do not rewrite history.)
