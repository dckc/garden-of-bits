---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: rebase-hygiene-audit

Adopted from `references/endo-but-for-bots/skills/rebase-hygiene-audit.md`.

Batch audit across open PRs for "are these cleanly stacked on base?". Read-only; produces a maintainer-actionable report.

## Per-PR probes

```sh
git fetch <remote> <base> <head>

mergebase=$(git merge-base <remote>/<base> <remote>/<head>)
behind=$(git rev-list --count <remote>/<head>..<remote>/<base>)
ahead=$(git rev-list --count <remote>/<base>..<remote>/<head>)
merges=$(git rev-list --count --merges <remote>/<base>..<remote>/<head>)

if git merge-tree --write-tree <remote>/<base> <remote>/<head> >/dev/null 2>&1; then
  conflicts=clean
else
  conflicts=conflicts
fi
```

## Categories

- **green**: `behind == 0` and `merges == 0`. Already perfectly stacked.
- **needs-rebase**: `behind > 0` and `conflicts == clean`. A `git rebase <base>` would land cleanly.
- **needs-rebase-with-conflicts**: `behind > 0` and `conflicts == conflicts`. Author must resolve.
- **has-merge-commits**: `merges > 0`. The author merged base into branch instead of rebasing.
- **base-not-on-remote**: the base branch doesn't exist on the audit remote (a stacked-PR scenario whose parent merged or closed).

## Bulk-fetching

60 PRs times 5 fetches each is fine; 60 times `git fetch --all` is not. Pull the list first:

```sh
gh pr list -R <owner>/<repo> --state open --limit 200 \
  --json number,baseRefName,headRefName \
  > /tmp/prs.json
```

Then `git fetch <remote> <ref1> <ref2> ...` in batches of ~50.

## Output

A markdown report grouped by category with a summary table at the top. End with 2 to 3 sentences of recommendations.

## Pitfalls

- **Read-only.** The audit does not push or rebase; recommendations go to the maintainer.
- **Long-lived feature branches with intentional merges** will read as `has-merge-commits` but should not be rebased. Flag them as anomalies in the report.
- **Stale Dependabot PRs** can be 700+ commits behind; recommend "dependabot recreate" rather than manual rebase.

## Notes from the field

- _2026-05-13_: adopted from the reference.
