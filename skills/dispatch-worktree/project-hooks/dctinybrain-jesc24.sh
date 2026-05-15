# project-hook: dctinybrain/jesc24
# Sourced by dispatch-prepare.sh when setting up a worktree for this repo.
# Prints the Nix dev shell setup that the subagent needs to build Coq 8.9.1.
#
# The subagent should run this in the project root before invoking coqc or make:
#   nix develop --no-pure-eval --command <cmd>
#
# Or to get a shell with coqc in PATH:
#   nix develop --no-pure-eval
#
# The flake provides coq_8_9, python3, gnumake, gcc. See flake.nix in the
# project root for the full package list.

echo "dispatch-prepare (dctinybrain-jesc24 hook): Nix dev shell provides coq_8_9 on host yolo1" >&2
echo "dispatch-prepare (dctinybrain-jesc24 hook): run 'nix develop --no-pure-eval' in the project root" >&2

# Write a convenience env script into the dispatch root so the subagent can
# source it. The subagent's COMMON.md tells it to look for .garden/ in the
# dispatch root.
mkdir -p "${ROOT}/.garden"
cat > "${ROOT}/.garden/nix-env.sh" <<-NIX_EOF
# Source this file in the dispatch root before running coqc:
#   source .garden/nix-env.sh
echo "Nix dev shell for dctinybrain/jesc24"
echo "  coqc version: \$(cd "${ROOT}/project" && nix develop --no-pure-eval --command coqc --version 2>/dev/null || echo "not found; run from project/")"
echo "  To enter shell: cd ${ROOT}/project && nix develop --no-pure-eval"
NIX_EOF
chmod +x "${ROOT}/.garden/nix-env.sh"
