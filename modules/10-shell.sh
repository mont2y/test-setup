#!/usr/bin/env bash

[[ "$INSTALL_ZSH" == true ]] || return 0

install_pkg zsh

if [[ ! -d "$HOME/.oh-my-zsh/.git" ]]; then
    log "Installing Oh My Zsh"
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
else
    ok "Oh My Zsh already installed"
fi

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM_DIR/plugins"

if [[ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions/.git" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-completions/.git" ]]; then
    git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM_DIR/plugins/zsh-completions"
fi

link_config "$ROOT_DIR/configs/zsh/.zshrc" "$HOME/.zshrc"

zsh_path="$(command -v zsh)"
if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    if ! grep -Fqx "$zsh_path" /etc/shells; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$zsh_path" "$USER" || warn "Could not set Zsh as the default shell"
fi
