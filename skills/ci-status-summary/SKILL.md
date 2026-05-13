---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: ci-status-summary

Adopted from `references/endo-but-for-bots/skills/ci-status-summary.md`.

Batch a CI status sweep across many open PRs. `gh pr checks <N> --watch` blocks one PR at a time; the sweep below prints one line per PR.

## How

```sh
for n in <pr-list>; do
  state=$(gh pr view $n -R <owner>/<repo> \
    --json statusCheckRollup \
    --jq '[.statusCheckRollup[] | (if .status=="COMPLETED" then .conclusion else .status end)] | group_by(.) | map("\(.[0])=\(length)") | join(" ")')
  printf 'PR %s | %s\n' "$n" "$state"
done
```

Output looks like:

```
PR 63 | SUCCESS=26
PR 67 | IN_PROGRESS=7 QUEUED=19
PR 70 | FAILURE=1 SUCCESS=25
```

`SUCCESS=N` where N matches the matrix size means all checks pass. Anything with `FAILURE=` is an outlier worth investigating.

## Drilling into a failure

```sh
gh pr checks <N> -R <owner>/<repo> --json state,name,link \
  | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if c['state'] == 'FAILURE':
        print(c['name'], '|', c['link'])"

# Job logs for a specific job id (after the step completes):
gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs | tail -100
```

## Pitfalls

- **`gh pr checks <N>` text output uses tab/space-separated columns**, but check names contain spaces (e.g. `test (18.x, ubuntu-latest)`). Do not pipe to `awk '{print $2}'`; use `--json` and jq.
- **Job log streaming.** The job logs API is silent during an in-progress run if the step's stdout is buffered. Wait for the step to complete.
- **Stale rollup right after a force-push.** `gh pr checks` may briefly show "all SUCCESS" from the prior head before the new head's checks register. Cross-check with `gh api repos/<o>/<r>/actions/runs/<id>/jobs` for the specific run id when a green count looks suspicious within seconds of a push.
- **Run-level `status` lags per-job state.** The run sits at `queued` while half the matrix is `in_progress`. Don't infer "stuck" from a stale `queued`; cross-check with `/jobs`.
- **Treat the run as terminal only when the run object reports `completed`.** Then read `conclusion`. The `/jobs` endpoint can momentarily report all jobs as `status=completed` mid-run.
- **zsh word-splitting.** Unquoted parameter expansion of a multi-line `$RUNS` iterates once with `r` set to the entire string. Use a `while IFS= read -r r; do ... done <<< "$RUNS"` here-string loop instead.

## Notes from the field

- _2026-05-13_: adopted from the reference. Removed the `lerna-ecycle-fix` cross-reference; if a project needs that skill, port it from `references/endo-but-for-bots/skills/lerna-ecycle-fix.md`.
