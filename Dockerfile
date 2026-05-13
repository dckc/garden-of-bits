FROM ubuntu:24.04

ARG NODE_MAJOR=22
ARG GO_VERSION=1.23.6
ARG DOTFILES_REPO=https://github.com/kriskowal/dotfiles.git
ARG VUNDLE_REPO=https://github.com/VundleVim/Vundle.vim.git

ENV DEBIAN_FRONTEND=noninteractive

# Base packages
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    vim \
    zsh \
    tmux \
    tig \
    less \
    openssh-client \
    ca-certificates \
    gnupg \
    unzip \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    cmake \
    fzf \
    ripgrep \
    fasd \
    locales \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Node.js via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Go toolchain
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Go language tooling — installed under /opt so the bind-mounted $HOME
# at runtime can't mask it. gopls is the LSP server used by vim-lsp;
# the others are the linters referenced in the vimrc plus dlv/goimports.
RUN mkdir -p /opt/go-tools/bin \
    && export GOPATH=/tmp/gopath GOBIN=/opt/go-tools/bin \
    && go install golang.org/x/tools/gopls@latest \
    && go install golang.org/x/tools/cmd/goimports@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install golang.org/x/lint/golint@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest \
    && go install github.com/kisielk/errcheck@latest \
    && rm -rf /tmp/gopath /root/.cache/go-build
ENV PATH="/opt/go-tools/bin:${PATH}"

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create kris user — UID 1000 matches the host user so the bind-mounted
# home directory stays writable without uid juggling. The bot's git/gh
# identity (kriscendobot) is supplied at runtime via ~/.ssh and ~/.config/gh
# in the bind mount, not via a separate unix user.
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 -G sudo kris \
    && echo 'kris ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Dotfiles — cloned into /opt/dotfiles since /home/kris is bind-mounted at
# runtime and would hide anything installed there. The entrypoint re-links
# these into $HOME on each start.
RUN git clone "${DOTFILES_REPO}" /opt/dotfiles \
    && chown -R kris:kris /opt/dotfiles

USER kris

# Install Vundle and the plugins listed in the vimrc. The vimrc expects
# Vundle at ~/.vim/bundle/Vundle.vim, so create build-time-only symlinks
# in /home/kris. These get masked at runtime by the bind mount; the
# entrypoint recreates equivalent links inside the bind mount.
RUN git clone "${VUNDLE_REPO}" /opt/dotfiles/vim/bundle/Vundle.vim \
    && ln -sfn /opt/dotfiles/vim    /home/kris/.vim \
    && ln -sfn /opt/dotfiles/.vimrc /home/kris/.vimrc \
    && vim -E -u /opt/dotfiles/.vimrc -i NONE \
         -c 'set nomore' \
         -c 'PluginInstall' \
         -c 'qa!' \
       ; true

# Login-shell PATH — the bind-mounted $HOME won't have any dotfiles, so
# ship PATH via /etc/profile.d so `bash -l` picks it up.
USER root
RUN printf '%s\n' \
    'export PATH="$HOME/bin:$HOME/go/bin:/opt/go-tools/bin:/usr/local/go/bin:$PATH"' \
    > /etc/profile.d/garden.sh

ENV PATH="/home/kris/bin:/home/kris/go/bin:${PATH}"

# Entrypoint links dotfiles from /opt/dotfiles into $HOME at start.
COPY entrypoint.sh /usr/local/bin/garden-entrypoint
RUN chmod +x /usr/local/bin/garden-entrypoint

USER kris
WORKDIR /home/kris

ENTRYPOINT ["/usr/local/bin/garden-entrypoint"]
CMD ["/bin/bash", "-l"]
