---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: process-documents

Adopted from `references/endo-but-for-bots/skills/process-documents.md`.

How to ship audit reports, gap reports, snapshots, and decision logs that describe how the work was done without polluting the codebase's history.

In this garden, project-specific process documents that the prior steward kept under a fork's `process/` tree live in the journal as `message` entries tagged with the project slug. Within an upstream fork worktree, a process document still ships under `process/` per the rules below, but most of the prior garden's "process" surface is now journal-side.

## What is a process document

Artifact of the work, not artifact of the product:

- Audit reports (TODO scan, rebase-hygiene audit, PR coverage map).
- Gap reports (designs without an in-flight PR, issues whose implementation has already landed).
- Snapshot reports (status of in-flight PRs at a moment in time).
- Decision logs and open-question notes.
- Curated work-handoff lists.

Process documents are *for the conversation between the user and the agents*, not for the codebase. They describe how the work was done, who decided what, and what remains.

## Where they live in a fork worktree

`process/` at the repo root. One file per report in `kebab-case.md` or `SCREAMING-CASE.md`. Subdirectories when reports cluster (`process/audits/`, `process/handoffs/`). A `process/README.md` indexes the current set.

## The isolation rule

**Process commits are isolated**: a commit either contains only `process/` changes (plus possibly the index update), or it contains no `process/` changes at all. Never mix.

The reason: when a maintainer ports work from a triage repo to upstream, process commits should drop cleanly. A maintainer running

```sh
git log --oneline upstream/master..triage \
  | grep -v '^[a-f0-9]\+ process'
```

should see exactly the substantive commits worth porting. Mixing process and substance pollutes upstream history with artifacts that have no value there.

## Commit-message convention

Process commits use the prefix `process` (no scope) or `process(<role>)` when a specific role produced the document:

- `process: TRIAGE.md snapshot 2026-04-26`
- `process(triager): agent-ready issues report`
- `process(shepherd): PR-rebase audit on bots`

The prefix makes process commits trivially grep-able for porting scripts.

## What does not belong in `process/`

- Source code or tests (those go in `packages/` or wherever the codebase keeps them).
- Design documents (those go in `designs/`).
- Role and skill files (those go in the garden's `roles/` and `skills/`).
- PR descriptions or comments (those live on the PR; quote them in a process document if context is needed, but the authority is the PR itself).

If a file would make a reviewer ask "why is this in our history?", it is process.

## Pitfalls

- **`git add -A` followed by a substantive commit message silently captures modified process files.** Always `git status` before staging, and stage selectively.
- **Process documents that describe themselves.** A snapshot of the current process system is itself process. The `process/README.md` index is process; this skill is not (it belongs in `skills/`, not `process/`, because it is a reusable technique).
- **Cross-cutting refactors.** When a process document gets an overhaul that also moves authoritative content out (a decision-log entry into a design doc), split into two commits: substantive promotion first, then process cleanup.
- **Stale snapshots.** A report dated months ago that has not been refreshed is misleading. Either refresh, mark superseded with a one-line header, or move to `process/archive/`.

## Notes from the field

- _2026-05-13_: adopted from the reference. The garden's own journal handles the "decision log" and "open questions" surface for most cross-project work; per-project process files now live in journal `message` entries tagged with the project slug.
