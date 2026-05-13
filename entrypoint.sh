#!/bin/bash
# garden-entrypoint — link dotfiles from /opt/dotfiles into $HOME, then exec.
# $HOME is bind-mounted from /home/kris/garden on the host. Symlinks we
# create here persist there; they'll appear dangling outside the container
# (since /opt/dotfiles exists only in the image), which is expected.

set -e

DOTFILES=/opt/dotfiles

# Link target -> link_path, but only when the path is absent or already a
# symlink. Never clobber a real file or directory the user has placed in
# the bind mount.
link_if_safe() {
    local target=$1 link_path=$2
    if [[ -L "$link_path" ]] || [[ ! -e "$link_path" ]]; then
        ln -sfn "$target" "$link_path"
    fi
}

if [[ -d "$DOTFILES" ]]; then
    link_if_safe "$DOTFILES/.bashrc"       "$HOME/.bashrc"
    link_if_safe "$DOTFILES/.bash_profile" "$HOME/.bash_profile"
    link_if_safe "$DOTFILES/.vimrc"        "$HOME/.vimrc"
    link_if_safe "$DOTFILES/.vimrc.local"  "$HOME/.vimrc.local"
    link_if_safe "$DOTFILES/vim"           "$HOME/.vim"
    link_if_safe "$DOTFILES/tmux.conf"     "$HOME/.tmux.conf"
    link_if_safe "$DOTFILES/tigrc"         "$HOME/.tigrc"
    link_if_safe "$DOTFILES/zshrc"         "$HOME/.zshrc"

    mkdir -p "$HOME/.config/git"
    link_if_safe "$DOTFILES/git/.gitconfig" "$HOME/.config/git/config"
fi

exec "$@"
