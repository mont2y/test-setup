#!/usr/bin/env bash

if [[ "$INSTALL_RCLONE" == true ]]; then
    install_pkg rclone
    if [[ ! -f "$HOME/.config/rclone/rclone.conf" ]]; then
        if [[ "${RESTORE_BITWARDEN_SECRETS:-false}" == true && "${RESTORE_RCLONE_FROM_BITWARDEN:-false}" == true ]]; then
            log 'rclone configuration will be checked during Bitwarden restoration'
        else
            warn 'rclone installed but not configured; run: rclone config'
        fi
    fi
fi

if [[ "$INSTALL_SYNCTHING" == true ]]; then
    install_pkg syncthing
    if [[ "${RESTORE_BITWARDEN_SECRETS:-false}" == true && "${RESTORE_SYNCTHING_FROM_BITWARDEN:-false}" == true ]]; then
        source "$ROOT_DIR/lib/syncthing-recovery.sh"
        syncthing_recovery_prepare || warn 'Syncthing initialization failed; recovery will report its result during secret restoration'
    elif command -v syncthing >/dev/null 2>&1; then
        enable_user_service_if_exists syncthing.service
    fi
fi

if [[ "$INSTALL_SOLAAR" == true ]]; then
    install_pkg solaar
fi

if [[ "$INSTALL_INPUT_REMAPPER" == true ]]; then
    log "Installing Input Remapper"
    case "$FAMILY" in
        debian|fedora) install_pkg input-remapper ;;
        arch)
            if install_paru_arch; then
                paru -S --needed --noconfirm input-remapper-git
            fi
            ;;
    esac
    if systemctl list-unit-files 2>/dev/null | grep -q '^input-remapper-daemon.service'; then
        sudo systemctl enable --now input-remapper-daemon.service || true
    fi
fi

if [[ "$INSTALL_ESPANSO" == true ]]; then
    log "Installing Espanso"
    session="$ESPANSO_BACKEND"
    if [[ "$session" == "auto" ]]; then
        session="${XDG_SESSION_TYPE:-}"
        [[ "$session" == "x11" || "$session" == "wayland" ]] || session="wayland"
    fi

    if ! command -v espanso >/dev/null 2>&1; then
        case "$FAMILY" in
            debian)
                case "$(uname -m)" in
                    x86_64|amd64)
                        deb="espanso-debian-${session}-amd64.deb"
                        tmp="$(mktemp --suffix=.deb)"
                        curl -fL "https://github.com/espanso/espanso/releases/latest/download/${deb}" -o "$tmp"
                        sudo apt-get install -y "$tmp"
                        rm -f "$tmp"
                        ;;
                    *) warn "Espanso Debian binary install is amd64-only in this setup" ;;
                esac
                ;;
            fedora)
                if ! rpm -q terra-release >/dev/null 2>&1; then
                    sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
                fi
                sudo dnf install -y "espanso-${session}"
                ;;
            arch)
                if [[ "$session" == "x11" ]]; then
                    mkdir -p "$HOME/opt"
                    curl -fL https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage -o "$HOME/opt/Espanso.AppImage"
                    chmod u+x "$HOME/opt/Espanso.AppImage"
                    sudo "$HOME/opt/Espanso.AppImage" env-path register
                else
                    install_package_manifest "packages/espanso-build-arch.txt"
                    src="$HOME/.local/src/espanso"
                    mkdir -p "$HOME/.local/src"
                    if [[ -d "$src/.git" ]]; then
                        git -C "$src" pull --ff-only || warn "Could not update Espanso source"
                    else
                        git clone https://github.com/espanso/espanso.git "$src"
                    fi
                    (cd "$src" && cargo build -p espanso --release --no-default-features --features modulo,vendored-tls,wayland)
                    sudo install -Dm755 "$src/target/release/espanso" /usr/local/bin/espanso
                fi
                ;;
        esac
    fi

    if command -v espanso >/dev/null 2>&1; then
        if [[ "$session" == "wayland" ]]; then
            case "$FAMILY" in
                debian) install_pkg libcap2-bin ;;
                fedora|arch) install_pkg libcap ;;
            esac
            command -v setcap >/dev/null 2>&1 && sudo setcap 'cap_dac_override+p' "$(command -v espanso)"
        fi

        espanso service register || warn "Espanso service registration failed"

        espanso_config_dir="$(espanso path config 2>/dev/null || true)"
        if [[ -z "$espanso_config_dir" ]]; then
            espanso_config_dir="$HOME/.config/espanso"
        fi
        mkdir -p "$espanso_config_dir/match"
        link_config "$ROOT_DIR/configs/espanso/match/base.yml" "$espanso_config_dir/match/base.yml"

        espanso restart || espanso start || warn "Espanso could not start in this session"
    fi
fi
