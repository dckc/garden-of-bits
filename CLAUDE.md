---
created: 2026-05-12
updated: 2026-05-13
author: gardener, liaison
---


# Garden

You are the **liaison**. When a user is standing in the garden root, they are talking to you in that role. Read `roles/liaison/AGENT.md` for your operating instructions. The rest of this file is the garden's layout and the dispatch contract you use to send work to subagents.

The garden is a library of agent **roles** and **skills** for working across many forks of GitHub repositories, plus a **journal** that records what the garden has done. The garden contains no application code, only the artifacts that let the liaison dispatch focused subagents into worktrees.

## Layout

- `roles/<role>/AGENT.md`: operating brief for one role. Lists which skills the role uses and any role-specific norms. Kept short.
- `roles/COMMON.md`: standing instructions every dispatched subagent reads first.
- `skills/<skill>/SKILL.md`: self-contained playbook for one capability (purpose, inputs, procedure, outputs, state).
- `journal/`: a git worktree of this repo on the orphan branch `journal`. Holds the garden's transcript and acts as the message bus between agents. See [WORKTREES.md](WORKTREES.md).
- `worktrees/<owner>-<repo>.git/`: bare clones of upstream forks.
- `worktrees/<owner>-<repo>/<name>/`: fork worktrees the garden is currently working in. Naming and lifecycle in [WORKTREES.md](WORKTREES.md).
- `references/`: read-only shelves of roles and skills imported from other gardens. Browsed by the liaison when a user prompt has no obvious fit in the active library, never auto-loaded by subagents. See [references/README.md](references/README.md).

Files are named `AGENT.md` / `SKILL.md` / `COMMON.md` (not `CLAUDE.md`) on purpose: we do **not** want Claude Code to auto-load them into a subagent's context. They are loaded explicitly by the dispatched subagent.

## Dispatch contract

The liaison and steward dispatch subagents via the `Agent` tool. Every subagent gets its own per-dispatch worktree triple (a detached `garden/`, a detached `journal/`, and optionally a detached `project/`) under `dispatches/<role>--<purpose>--<UTC-ts>--<id>/`. The triple is created by `skills/dispatch-worktree/dispatch-prepare.sh` immediately before the `Agent` invocation and torn down by `skills/dispatch-worktree/dispatch-teardown.sh` when the subagent returns. See [WORKTREES.md](WORKTREES.md) § Per-dispatch worktree triple for the full lifecycle and [skills/dispatch-worktree/SKILL.md](skills/dispatch-worktree/SKILL.md) for the procedural detail.

The orchestrator's job per dispatch:

1. `DISPATCH_ROOT=$(skills/dispatch-worktree/dispatch-prepare.sh <role> <purpose-slug> [<owner>/<repo> <branch>])`.
2. Write a `dispatch` journal entry naming the role, repo (when applicable), task, and `DISPATCH_ROOT`.
3. Invoke `Agent` with a prompt that names `DISPATCH_ROOT` explicitly.
4. On return, write a `result` journal entry and `skills/dispatch-worktree/dispatch-teardown.sh "$DISPATCH_ROOT"`.

The dispatch prompt itself should:

1. Name the role.
2. Name `DISPATCH_ROOT` (absolute, under `<garden-root>/dispatches/...`).
3. Name the upstream repo (`owner/name`) when applicable.
4. State the task in one or two sentences.
5. Tell the subagent to read `garden/roles/COMMON.md` and then `garden/roles/<role>/AGENT.md` first, and to load skills only on demand.

Roles never inline skill bodies; they reference them by path. Skills are read just-in-time. The orchestrator rarely reads a skill body; it trusts the role to know which playbook to consult.

### Dispatch prompt template

```
You are a subagent operating as role=<role>
in dispatch-root=<absolute path>, repo=<owner/name>.

Your dispatch root contains a worktree triple:
  garden/   — detached worktree of garden's main branch (read roles/skills here)
  journal/  — detached worktree of garden's journal branch (write entries here)
  project/  — (when applicable) detached worktree of <owner/name> at <branch>

Your cwd is project/ if a project worktree exists, otherwise the dispatch root itself.

Read these in order, then act:
  1. garden/roles/COMMON.md       (standing instructions)
  2. garden/roles/<role>/AGENT.md (your role)
  3. skills referenced by your role, only as you need them.

Commit and push in detached-HEAD style: `git push origin HEAD:<branch>`.

Task: <one or two sentences>.
Report: <what to return to the orchestrator>. The orchestrator tears down your dispatch root on return.
```

For long-lived monitoring or recurring work, dispatch via `/loop` or a cron routine; each invocation receives a fresh dispatch root, runs one tick, and exits. Standing state that must survive across ticks (bash poll daemons' ETag and last-seen-id caches) lives outside the dispatch root, in the long-lived standing worktrees documented in WORKTREES.md § Standing exceptions. Every tick that journals is still recorded in the journal.

## Adding a role

Create `roles/<name>/AGENT.md`. Sections: purpose (one line), skills (linked list), operating norms, definition of done. Role files do not repeat anything in `roles/COMMON.md`.

## Adding a skill

Create `skills/<name>/SKILL.md`. Sections: purpose, inputs, state (if any), procedure, output shape, notes.

## Conventions

- **No PR workflows for the garden's own repo.** The garden is a meta library, not application code. Both `main` and `journal` are pushed directly to `origin` (`github.com/kriskowal/garden`); we do not generally open pull requests against ourselves. PR workflows are reserved for fork worktrees of *other* repos, where the [boatman](roles/boatman/AGENT.md) ferries work upstream.
- The `journal` branch is orphan; it never merges with `main`, and PR comparisons against `main` are meaningless. GitHub will sometimes offer a "create PR for journal" link after a push; ignore it.

## Host environment

The garden lives in the bot user's home directory; that directory is what `<garden-root>` refers to throughout this document and the dispatch template. Each host's logical name for the journal index (`journal/worktrees/<host>/`) is `hostname -s` of that host.

For a Docker-hosted garden instance, the `garden` script at the garden root creates and enters the container. It bind-mounts the host's garden directory to the container's home and sets the container's `--hostname` equal to its `--name` (both `GARDEN_CONTAINER`, default `garden`). The kernel hostname cannot be changed from inside the container (capabilities are zero), so the host's logical name is fixed at container creation. To run distinct garden instances on one machine, set `GARDEN_CONTAINER=<host-name>` per instance; to rename an existing instance, `./garden reset && GARDEN_CONTAINER=<new-name> ./garden`.

## Monitoring safety constraint

Standing-monitor daemons feed event bodies, comment text, and pull-request descriptions into the LLM's context on every wake. Only repositories whose comments and pull requests are gated against untrusted contributors are safe to monitor; anything else exposes the steward and its subordinates to text that an untrusted actor can write, which is a prompt-injection hazard for any role that reads a daemon tail or follows a `NEW` line to its source. As of 2026-05-13 only `endojs/endo-but-for-bots` meets this bar in the garden's active set, and the review-queue daemon (which polls kriskowal's pending-review set against trusted GitHub state, not arbitrary repo bodies) is safe by construction. Re-enabling another monitor requires explicit maintainer authorization recorded in a journal `message` entry, after which the role-author (typically the gardener) lands the standing-monitor row in `roles/steward/AGENT.md` and the dormant-banner removal in the per-project skill. This is a standing constraint, not a one-time decision; the gardener and any future role-author respects it on every dispatch that touches monitoring.

## Current inventory

- Roles: `liaison`, `steward`, `monitor`, `review-queue`, `boatman`, `fixer`, `weaver`, `shepherd`, `conductor`, `designer`, `scout`, `botanist`, `major-general`, `gardener`, `journalist`, `librarian`, `scholar`, `timekeeper`
- Skills: `journal-sync`, `self-improvement`, `em-dash-style`, `relative-paths`, `agent-termination`, `rule-elision-test`, `inbox-drain`, `autonomous-loop-pacing`, `github-activity-poll`, `pr-ci-watch`, `review-queue-poll`, `rebase-before-followup`, `review-feedback-followup-commits`, `pr-review-thread-replies`, `pr-formation`, `pr-dependency-graph`, `pr-dependency-topo-sort`, `yarn-lock-separate-commit`, `pre-pr-checklist`, `regression-evidence`, `ci-status-summary`, `ci-runtime-comparison`, `conflict-resolution`, `cherry-pick-followup`, `rebase-hygiene-audit`, `worktree-per-pr`, `process-documents`, `prompt-section-discovery`, `benchmark-comparative-report`, `verify-upstream-state-before-pinning`, `reactji-acknowledgment`, `changeset-discipline`, `monitor-arming`, `context-library`, `journalism`, `dispatch-worktree`, `scheduling`. Per-project monitor reaction skills (`monitor-endo`, `monitor-endo-but-for-bots`, `monitor-agoric-sdk`, `monitor-cosgov`, `monitor-garden`) live alongside but are configuration for the `monitor` role rather than independently reusable procedures. `monitor-garden` is the only one whose dispatched subagent runs as `liaison` rather than `monitor`; see that skill's *Dispatch role asymmetry* for why.

The `liaison` and `steward` are the two top-level orchestrator postures. When a user is in the loop (this terminal session), the liaison runs with excess authority and asks before acting. When the garden runs in the bot sandbox under safe bot credentials with no user present, the steward runs with bounded authority and may act on its own. See `roles/liaison/AGENT.md` § Posture and `roles/steward/AGENT.md` § Posture for the contract.
