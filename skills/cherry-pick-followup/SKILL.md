---
created: 2026-05-13
updated: 2026-05-13
author: liaison
---

# Skill: cherry-pick-followup

Adopted from `references/endo-but-for-bots/skills/cherry-pick-followup.md`.

When a doc, style, or policy change lands on a branch that's not the current working tree's branch, apply it locally via cherry-pick rather than reauthoring.

## How

```sh
git -C <repo> cherry-pick <sha>
# resolve conflicts manually if any
git -C <repo> log --oneline -2     # confirm the new commit landed
```

If the change should also land on a different worktree's branch, run the cherry-pick from inside that worktree.

## Pitfalls

- **Different SHAs per branch.** Cherry-picking the same commit onto multiple branches gives each branch a different SHA. Compare commit messages or trees, not SHAs, across branches.
- **Mismatch between style files.** When project A tracks rules in `CLAUDE.md` and project B in `AGENTS.md` (or some other file), cherry-picking blindly leaves the rule undocumented on whichever side lacks the file. Detect the case and target the right file instead of a no-op cherry-pick.

## Notes from the field

- _2026-05-13_: adopted from the reference.
