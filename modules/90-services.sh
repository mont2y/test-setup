#!/usr/bin/env bash

if [[ "$INSTALL_OPENSSH_SERVER" == true ]]; then
    case "$FAMILY" in
        debian|fedora) install_pkg openssh-server ;;
        arch) install_pkg openssh ;;
    esac
    if [[ "$ENABLE_OPENSSH_SERVER" == true ]]; then
        if system_service_exists sshd.service; then
            enable_system_service_if_exists sshd.service
        elif system_service_exists ssh.service; then
            enable_system_service_if_exists ssh.service
        else
            warn 'OpenSSH server requested, but no loaded sshd.service or ssh.service was found'
        fi
    fi
fi

if [[ "$INSTALL_CODEX" == true ]]; then
    log "Installing Codex CLI"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
fi
