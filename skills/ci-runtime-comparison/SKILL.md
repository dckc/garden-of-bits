---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: ci-runtime-comparison

Adopted from `references/endo-but-for-bots/skills/ci-runtime-comparison.md`.

Compare CI wall-clock and compute across branches when a maintainer asks "is the new PR slower?", or when a refactor's CI cost is in question.

## How

Pull workflow runs for each branch:

```sh
gh api repos/<owner>/<repo>/actions/runs?branch=<branch>&per_page=5 \
  --jq '.workflow_runs[] | {head_sha, name, status, conclusion, created_at, updated_at, run_started_at}'
```

Total wall-clock for a run is `max(updated_at) - min(run_started_at)` across the run's jobs. Per-job durations:

```sh
gh api repos/<owner>/<repo>/actions/runs/<run-id>/jobs \
  --jq '.jobs[] | {name, started_at, completed_at}' \
  | python3 -c "
import sys, json
from datetime import datetime
total = 0
for line in sys.stdin:
    j = json.loads(line)
    s = datetime.fromisoformat(j['started_at'].replace('Z','+00:00'))
    e = datetime.fromisoformat(j['completed_at'].replace('Z','+00:00'))
    d = (e-s).total_seconds()
    print(f'{int(d):4d}s  {j[\"name\"]}')
    total += d
print(f'sum: {int(total)}s')"
```

## What to report

Compare three numbers per branch:

1. **Wall-clock total** for one run. This is what a reviewer waits for, since matrix jobs run in parallel.
2. **Slowest single job.** The bottleneck; if both branches have the same slowest job, the new PR doesn't regress wall-clock.
3. **Sum of all job durations** if compute spend matters more than wall-clock.

Interpret in one paragraph naming the trade-off.

## Pitfalls

- **Required vs optional checks.** A single run includes both; filter by `name` for apples-to-apples.
- **Re-runs inflate `created_at` vs `run_started_at`.** Use the latest re-run's timestamps.
- **Runner-type drift.** Branch comparisons are most stable when both runs were on the same runner. `runs-on:` lives in `.github/workflows/*.yml`.

## Notes from the field

- _2026-05-13_: adopted from the reference.
