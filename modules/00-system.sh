#!/usr/bin/env bash

if [[ "$UPDATE_SYSTEM" == true ]]; then
    log "Updating system"
    case "$FAMILY" in
        debian)
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            ;;
        fedora)
            sudo dnf upgrade --refresh -y
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;
    esac
fi

if [[ "$INSTALL_BASE" == true ]]; then
    case "$FAMILY" in
        debian)
            install_many curl wget git ca-certificates gnupg unzip zip tar vim neovim nano tmux htop btop tree jq rsync openssh-client openssh-server ripgrep fd-find bash-completion
            install_many build-essential pkg-config cmake make gcc g++
            ;;
        fedora)
            install_many curl wget git ca-certificates gnupg2 unzip zip tar vim-enhanced neovim nano tmux htop btop tree jq rsync openssh-clients openssh-server ripgrep fd-find bash-completion
            install_many gcc gcc-c++ make cmake pkgconf-pkg-config
            ;;
        arch)
            install_many curl wget git ca-certificates gnupg unzip zip tar vim neovim nano tmux htop btop tree jq rsync openssh ripgrep fd bash-completion
            install_many base-devel cmake pkgconf
            ;;
    esac
fi
