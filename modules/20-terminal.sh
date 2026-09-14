#!/usr/bin/env bash

[[ "$INSTALL_WEZTERM" == true ]] || return 0

if ! command -v wezterm >/dev/null 2>&1; then
    log "Installing WezTerm"
    case "$FAMILY" in
        debian)
            sudo install -d -m 0755 /usr/share/keyrings
            if [[ ! -f /usr/share/keyrings/wezterm-fury.gpg ]]; then
                curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
                sudo chmod 0644 /usr/share/keyrings/wezterm-fury.gpg
            fi
            if [[ ! -f /etc/apt/sources.list.d/wezterm.list ]]; then
                echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
            fi
            sudo apt-get update
            sudo apt-get install -y wezterm
            ;;
        fedora)
            install_pkg dnf-plugins-core
            sudo dnf copr enable -y wezfurlong/wezterm-nightly
            sudo dnf install -y wezterm
            ;;
        arch)
            install_many wezterm ttf-nerd-fonts-symbols-mono
            ;;
    esac
else
    ok "WezTerm already installed"
fi

config_dir="$HOME/.config/wezterm"
if [[ -d "$config_dir/.git" ]]; then
    remote="$(git -C "$config_dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$remote" == "$WEZTERM_CONFIG_REPO" || "$remote" == "${WEZTERM_CONFIG_REPO%.git}" ]]; then
        if git -C "$config_dir" diff --quiet && git -C "$config_dir" diff --cached --quiet; then
            git -C "$config_dir" fetch origin "$WEZTERM_CONFIG_BRANCH"
            git -C "$config_dir" checkout "$WEZTERM_CONFIG_BRANCH" >/dev/null 2>&1 || true
            git -C "$config_dir" pull --ff-only origin "$WEZTERM_CONFIG_BRANCH" || warn "Could not update WezTerm config"
        else
            warn "Local changes in $config_dir; skipping automatic update"
        fi
    else
        backup_path "$config_dir"
        git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
    fi
elif [[ -e "$config_dir" ]]; then
    backup_path "$config_dir"
    git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
else
    mkdir -p "$HOME/.config"
    git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
fi
