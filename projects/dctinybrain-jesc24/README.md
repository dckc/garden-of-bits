# Project: dctinybrain/jesc24

JavaScript to Coq compilation target for the JES MOOC (c20). The garden engages with this project primarily through fixer dispatches on PRs; the repo is a student project that uses Coq 8.9.1 via opam on host `yolo1`.

## Build toolchain

- Build system: Coq 8.9.1 via opam, `coq_makefile` + Makefile
- Opam switch: `ocpl-coq-8.9.1-ocaml-4.07.1` on host `yolo1`
- Codegen: Python 3 needed for `js_to_coq_source.py`
- Coq is NOT available on the garden's bot hosts by default; a fixer dispatched against this repo must `eval $(opam env)` before running `coqc`. The exact commands:

  ```sh
  opam switch ocpl-coq-8.9.1-ocaml-4.07.1
  eval $(opam env)
  ```

## Repo layout

- Repo: <https://github.com/dctinybrain/jesc24>
- Bare clone at `worktrees/dctinybrain-jesc24.git`
- After pushing from a dispatch worktree, the bare clone's local branch refs are stale: run `git --git-dir=worktrees/dctinybrain-jesc24.git fetch origin <branch>` before verifying.

## Rules of engagement

- Fixer is the only role dispatched against this repo so far. Verify `eval $(opam env)` is in scope before running any Coq command. See the opam switch facts under *Build toolchain* above.
- The garden's bot identity (`dctinybrain`) is the GitHub identity for this repo. No identity switching needed.

## Upstream

- Repo: <https://github.com/dctinybrain/jesc24>
- Default branch: `main`
- No standing monitor; dispatches are one-off fixer or weaver runs.
