# project-hook: dctinybrain/jesc24
# Sourced by dispatch-prepare.sh when setting up a worktree for this repo.
# Prints the opam env setup that the subagent needs to build Coq 8.9.1.
#
# The subagent should run these commands before invoking coqc:
#   eval $(opam env)
#   opam switch ocpl-coq-8.9.1-ocaml-4.07.1
#   eval $(opam env)

SWITCH="ocpl-coq-8.9.1-ocaml-4.07.1"

echo "dispatch-prepare (dctinybrain-jesc24 hook): opam switch is ${SWITCH} on host bldbox" >&2
echo "dispatch-prepare (dctinybrain-jesc24 hook): ensure 'eval \$(opam env)' is in scope before coqc" >&2

# Write a convenience env script into the dispatch root so the subagent can
# source it. The subagent's COMMON.md tells it to look for .garden/ in the
# dispatch root.
mkdir -p "${ROOT}/.garden"
cat > "${ROOT}/.garden/opam-env.sh" <<-OPAM_EOF
# Source this file in the dispatch root before running coqc:
#   source .garden/opam-env.sh
opam switch ${SWITCH}
eval \$(opam env)
echo "opam switch is ${SWITCH}; coqc version: \$(coqc -version 2>/dev/null || echo not found)"
OPAM_EOF
chmod +x "${ROOT}/.garden/opam-env.sh"
