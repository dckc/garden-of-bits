---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: agent-termination

Write a termination report for a long-living subagent and (when possible) archive its raw Claude Code JSONL transcript so the agent's experience is consultable in future sessions.

## When to use

When a long-living subagent terminates: intentionally stopped, completed its bounded engagement, or interrupted. For trivial one-shot dispatches (a single monitor tick, a quick query), the journal `result` entry is sufficient. Write a termination report when the subagent's accumulated knowledge would plausibly be worth consulting in a future session.

Default rule: if the subagent ran across more than one steward cycle, **or** its work was non-trivial enough that a future agent might ask "what did the prior one find about X?", write a termination report.

The dispatcher (liaison or steward) writes the report. Subagents do not write their own.

## Inputs

Gathered before invoking:

- `role`: the role the subagent was operating as.
- `worktree` and `worktree_path`: if applicable.
- `repo`, `branch`, `project`: as known.
- `subject_matter`: list of kebab-case tags (`ses-intrinsics`, `endo-bytes`, `ci-flakiness`, `eslint-plugin-import-x`, etc.). These drive future grep-based consultation.
- `started_at` / `terminated_at`: ISO timestamps in UTC.
- `terminated_by`: `complete` (engagement finished), `interrupted` (steward stopped it), or `stopped` (liaison stopped it).
- `summary`: one-line description of the subagent's contribution. This is what shows up in by-role and by-subject indexes.
- `final_report`: the agent's last message to the dispatcher, verbatim.
- `session_id` (optional): the subagent's Claude Code session ID. If you have it, both the JSONL copy and the report's frontmatter can name it; if not, the report is still useful and the JSONL is best-effort.
- `prs` (optional): list of PRs the agent worked on, in the same shape as the worktree-index `prs:` field.

## Procedure

All commands are shown with the garden root as cwd.

1. Generate a short-id:

   ```sh
   SHORT=$(openssl rand -hex 3)
   ```

2. Compute the report filename. The date is the termination date in UTC:

   ```sh
   REPORT="journal/agents/$(date -u +%Y-%m-%d)-<role>-${SHORT}.md"
   ```

3. (Track B, optional but recommended) Locate and copy the subagent's raw transcript. Claude Code stores subagent transcripts at:

   ```
   ~/.claude/projects/<encoded-cwd>/<session-id>/subagents/agent-<agent-id>.jsonl
   ```

   `<encoded-cwd>` is the cwd with `/` replaced by `-` (so `/Users/kris/garden` becomes `-Users-kris-garden`). If you know the subagent's session ID, copy by name. Otherwise, find by mtime (newest under that `subagents/` directory within the dispatch window) and verify by reading the first few lines for the dispatch prompt:

   ```sh
   PROJ=$(echo "$PWD" | sed 's|/|-|g')
   SUBAGENTS=~/.claude/projects/$PROJ/<session-id>/subagents
   # If session_id is known:
   cp "$SUBAGENTS/agent-<session-id>.jsonl" "journal/agents/transcripts/agent-<session-id>.jsonl"
   # Otherwise, find by mtime:
   ls -t "$SUBAGENTS"/agent-*.jsonl | head -1
   ```

   If the transcript cannot be located cleanly, skip the copy and note `transcript: null` in the report's frontmatter.

   Claude Code prunes session files after 30 days by default, which is the reason for this defensive copy. The orphan `journal` branch lives in the garden's repo and survives indefinitely.

4. Write the report file with frontmatter:

   ```yaml
   ---
   agent_id: <short-id>
   session_id: <session-id-or-null>
   hostname: <hostname -s>
   worktree: <name-or-null>
   worktree_path: <absolute-or-null>
   role: <role>
   repo: <owner/repo-or-null>
   branch: <branch-or-null>
   project: <slug-or-null>
   subject_matter:
     - <tag1>
     - <tag2>
   started_at: <ISO>
   terminated_at: <ISO>
   terminated_by: complete | interrupted | stopped
   summary: "<one line>"
   prs:
     - repo: <owner/repo>
       pr: <n>
       role: source | target | related
   transcript: transcripts/agent-<session-id>.jsonl
   ---

   <final_report verbatim, lightly cleaned for readability>
   ```

   Body conventions: keep the agent's own voice. Add a short editor's note at the top only if the report needs context the agent did not provide ("Terminated mid-CI failure investigation; see `entries/<...>` for the trigger.").

5. Commit and push the report (and the JSONL, if copied) via `skills/journal-sync/SKILL.md`. Include both files in one commit.

6. Update the worktree's journal index entry: set `status: collected` per `WORKTREES.md` if the worktree is being collected at the same time. The agent termination and the worktree collection are usually but not always coincident.

## Consultation

To answer a future "btw, what did the X agent conclude about Y?" question:

1. Find candidate reports:

   ```sh
   # by role
   ls journal/agents/*-monitor-*.md
   # by date
   ls journal/agents/2026-05-*.md
   # by subject-matter tag
   grep -l 'ses-intrinsics' journal/agents/*.md
   # by project
   grep -l '^project: endo' journal/agents/*.md
   ```

2. Read the most relevant report. The frontmatter and body usually answer.

3. If the report leaves the question unanswered, dispatch a fresh agent with the report (and optionally the JSONL transcript path) as context. The fresh agent reads the report, considers the new question, and returns. Do NOT attempt to "resume" the past subagent; resumption of a past JSONL into a new context as background is not supported by Claude Code today and would require custom tooling.

## Notes from the field

(Append; do not rewrite history.)

- _2026-05-12_: created. The Track B JSONL discovery procedure is heuristic (mtime-based when the session id is unknown). First real termination will exercise it; refine here if the heuristic misfires (parallel dispatches in the same window are the obvious failure mode).
