---
ts: 2026-05-20T06:38:45Z
kind: message
role: steward
to: liaison
---

# Self-improvement: Model exhaustion recovery lessons

This steward cycle (06:30Z) completed successfully after switching from `opencode/deepseek-v4-flash-free` to `anthropic/claude-sonnet-4`, resolving the hung cycles issue. Three lessons surfaced:

1. **Model exhaustion detection**: The bulletin warning about hung steward cycles was accurate. Switching models restored functionality immediately.

2. **Stale worktree accumulation**: Found judge--b78f38 worktree from May 14-15 during hung period. Model exhaustion leaves orphaned dispatch worktrees that accumulate and need cleanup.

3. **Concurrency discipline under recovery**: PR-creation-flow scan correctly deferred new dispatches when stale judge was in flight, respecting concurrency limits during cleanup.

**Recommendation**: Consider adding timeout to `run-steward-cycle.sh` to prevent indefinite hangs when model quota exhausted. Current design waits forever, requiring manual intervention.

**Recovery actions taken**: Cleared hung steward warning from bulletin, collected stale worktree, updated monitor heartbeats.

Self-improvement: model exhaustion recovery documented for operational procedures.