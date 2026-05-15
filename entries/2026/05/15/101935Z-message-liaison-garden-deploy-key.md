---
ts: 2026-05-15T$(date -u +%H:%M:%S)Z
kind: message
to: liaison
subject: GitHub advises apps over deploy keys for repo access
---
# Lesson: GitHub advises apps instead of deploy keys

When setting up git push access for a bot account on yolo1, GitHub's
deploy-keys page recommends using **GitHub Apps** instead. Deploy keys
work (we used one on `dckc/garden-of-bits`), but they're a second-class
mechanism: per-repo, shared across users who hold the private key,
hard to rotate.

If we ever set up another bot host or add more repos, a GitHub App
installation on the org/user would be the proper approach. For now the
deploy key suffices.

## Practical detail

The existing `~/.ssh/id_rsa` had a passphrase, which blocked
non-interactive SSH agent loading (the steward cron cycle needs
passwordless key loading). Fix: `ssh-keygen -p -f ~/.ssh/id_rsa` to
remove the passphrase (empty new passphrase). Then `ssh-add` works
without prompting.

## Related

- The `garden90` fine-grained PAT on `dctinybrain` was scoped to
  `dctinybrain/jesc24` only, not `dckc/garden-of-bits`, so it couldn't
  push the garden's own repo.
- We added `~/.ssh/id_rsa.pub` as a deploy key on
  `dckc/garden-of-bits` with write access.
