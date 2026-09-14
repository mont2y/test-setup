#!/usr/bin/env bash

if [[ "$INSTALL_FLATPAK" == true ]]; then
    install_pkg flatpak
    if command -v flatpak >/dev/null 2>&1; then
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
fi

[[ "$INSTALL_TELEGRAM" == true ]] && install_flatpak_app org.telegram.desktop
[[ "$INSTALL_LUTRIS" == true ]] && install_flatpak_app net.lutris.Lutris
[[ "$INSTALL_STEAM" == true ]] && install_flatpak_app com.valvesoftware.Steam

if [[ "$INSTALL_BRAVE" == true ]]; then
    log "Installing Brave"
    if ! command -v brave-browser >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
        case "$FAMILY" in
            debian)
                sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
                sudo apt-get update
                sudo apt-get install -y brave-browser
                ;;
            fedora)
                install_pkg dnf-plugins-core
                if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
                    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
                fi
                sudo dnf install -y brave-browser
                ;;
            arch)
                if install_paru_arch; then
                    paru -S --needed --noconfirm brave-bin
                fi
                ;;
        esac
    fi
fi

if [[ "$INSTALL_POSTMAN" == true ]]; then
    log "Installing Postman"
    if [[ ! -x /opt/Postman/Postman ]]; then
        case "$(uname -m)" in
            x86_64|amd64) postman_url="https://dl.pstmn.io/download/latest/linux64" ;;
            aarch64|arm64) postman_url="https://dl.pstmn.io/download/latest/linux_arm64" ;;
            *) postman_url="" ;;
        esac
        if [[ -n "$postman_url" ]]; then
            tmp="$(mktemp --suffix=.tar.gz)"
            curl -fL "$postman_url" -o "$tmp"
            sudo rm -rf /opt/Postman
            sudo tar -xzf "$tmp" -C /opt
            rm -f "$tmp"
            sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman
            sudo tee /usr/share/applications/postman.desktop >/dev/null <<'EOF_POSTMAN'
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Type=Application
Categories=Development;
Terminal=false
EOF_POSTMAN
        else
            warn "Unsupported architecture for Postman: $(uname -m)"
        fi
    fi
fi

if [[ "$INSTALL_THUNDERBIRD" == true ]]; then
    install_pkg thunderbird
fi
