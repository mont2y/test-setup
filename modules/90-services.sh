#!/usr/bin/env bash

if systemctl list-unit-files 2>/dev/null | grep -q '^sshd.service'; then
    enable_system_service_if_exists sshd.service
elif systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
    enable_system_service_if_exists ssh.service
fi

if [[ "$INSTALL_CODEX" == true ]]; then
    log "Installing Codex CLI"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
fi
