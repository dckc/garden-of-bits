# Project: dctinybrain/jesc24

JavaScript to Coq compilation target for the JES MOOC (c20). The garden engages with this project primarily through fixer dispatches on PRs; the repo is a student project that uses Coq 8.9.1 via a Nix dev shell on host `yolo1`.

## Fork relationship

**This repo is a fork of `agoric-labs/jesc24`.** It is NOT the upstream.

- Fork: <https://github.com/dctinybrain/jesc24> (garden's working copy)
- Upstream: <https://github.com/agoric-labs/jesc24> (canonical repo)

Changes pushed to the fork's `main` branch stay on the fork. They do not propagate upstream. To ferry changes upstream:

1. The [boatman](../../roles/boatman/AGENT.md) opens an upstream PR on `agoric-labs/jesc24` from the garden fork branch, attributing commits to the human author. This is the preferred route.
2. Alternatively, a direct PR to `agoric-labs/jesc24` from the fork branch works if the boatman is not available.

The liaison made this mistake on 2026-05-15: it assumed `dctinybrain/jesc24` was the upstream and dispatched a fixer to push directly to the fork's `main` branch. The fix landed on the fork but not upstream. The lesson: always check whether a project repo is a fork before dispatching work that pushes to `main`.

## Build toolchain

- Build system: Coq 8.9.1 via Nix, `coq_makefile` + Makefile
- Nix dev shell: `nix develop --no-pure-eval` (see `flake.nix` in the project root; provides `coq_8_9`, `python3`, `gnumake`, `gcc`)
- Codegen: Python 3 needed for `js_to_coq_source.py` (included in the Nix shell)
- The opam route was abandoned because the upstream opam repository no longer contains OCaml 4.07 metadata (removed 2026-05-05); see `agoric-labs/jesc24#1` commit `cc8cfed` for the full investigation.

## Repo layout

- Repo: <https://github.com/dctinybrain/jesc24>
- Bare clone at `worktrees/dctinybrain-jesc24.git`
- After pushing from a dispatch worktree, the bare clone's local branch refs are stale: run `git --git-dir=worktrees/dctinybrain-jesc24.git fetch origin <branch>` before verifying.

## Rules of engagement

- Fixer is the primary role dispatched against this repo so far. Run `nix develop --no-pure-eval` from the project root before running any Coq command. See the Nix dev shell facts under *Build toolchain* above.
- The garden's bot identity (`dctinybrain`) is the GitHub identity for this repo. No identity switching needed.
- The flake (`flake.nix`, `flake.lock`) was cherry-picked from `dckc/jesc24`'s `dc-jessie-ci` branch (commits `195de94`, `a80b83d`). Keep it in sync with upstream if that PR merges.

## Upstream

- No standing monitor; dispatches are one-off fixer or weaver runs.
- To get changes upstream, use the boatman or open a PR to `agoric-labs/jesc24`.
