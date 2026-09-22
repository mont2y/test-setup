#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Node.js / NVM
# -----------------------------------------------------------------------------

if [[ "$INSTALL_NVM_NODE" == true ]]; then
    export NVM_DIR="$HOME/.nvm"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log "Installing NVM $NVM_VERSION"

        NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
        NVM_INSTALL_TMP="$(mktemp)"

        # Network behavior:
        #   - Retry temporary failures up to 5 times.
        #   - Wait 3 seconds between retries.
        #   - Retry connection/network errors too.
        #   - Give connection establishment 15 seconds.
        #   - Limit each transfer attempt to 120 seconds.
        if ! curl -fsSL \
            --retry 5 \
            --retry-delay 3 \
            --retry-all-errors \
            --connect-timeout 15 \
            --max-time 120 \
            "$NVM_INSTALL_URL" \
            -o "$NVM_INSTALL_TMP"; then

            rm -f "$NVM_INSTALL_TMP"
            die "Failed to download NVM $NVM_VERSION installer"
        fi

        if ! PROFILE=/dev/null bash "$NVM_INSTALL_TMP"; then
            rm -f "$NVM_INSTALL_TMP"
            die "NVM $NVM_VERSION installation failed"
        fi

        rm -f "$NVM_INSTALL_TMP"
    else
        ok "NVM already installed"
    fi

    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # NVM is installed outside this repository.
        # shellcheck disable=SC1090,SC1091
        source "$NVM_DIR/nvm.sh"

        log "Installing Node.js LTS"

        nvm install --lts
        nvm alias default 'lts/*'
        nvm use default
    else
        die "NVM installation completed but $NVM_DIR/nvm.sh was not found"
    fi
fi


# -----------------------------------------------------------------------------
# Python
# -----------------------------------------------------------------------------

if [[ "$INSTALL_PYTHON" == true ]]; then
    log "Installing Python development tools"

    install_package_manifest "packages/development-${FAMILY}.txt"
fi


# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

if [[ "$INSTALL_DOCKER" == true ]]; then
    log "Installing Docker Engine"

    if ! command -v docker >/dev/null 2>&1; then
        case "$FAMILY" in
            debian)
                docker_os="debian"
                docker_suite="${VERSION_CODENAME:-}"

                if [[ "$DISTRO_ID" == "ubuntu" || -n "${UBUNTU_CODENAME:-}" ]]; then
                    docker_os="ubuntu"
                    docker_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
                fi

                [[ -n "$docker_suite" ]] || \
                    die "Could not determine Debian/Ubuntu codename for Docker"

                sudo install -m 0755 -d /etc/apt/keyrings

                sudo curl -fsSL \
                    "https://download.docker.com/linux/${docker_os}/gpg" \
                    -o /etc/apt/keyrings/docker.asc

                sudo chmod a+r /etc/apt/keyrings/docker.asc

                arch="$(dpkg --print-architecture)"

                cat <<EOF_DOCKER | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
Types: deb
URIs: https://download.docker.com/linux/${docker_os}
Suites: ${docker_suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF_DOCKER

                sudo apt-get update

                sudo apt-get install -y \
                    docker-ce \
                    docker-ce-cli \
                    containerd.io \
                    docker-buildx-plugin \
                    docker-compose-plugin
                ;;

            fedora)
                install_pkg dnf-plugins-core

                sudo dnf config-manager addrepo \
                    --from-repofile \
                    https://download.docker.com/linux/fedora/docker-ce.repo

                sudo dnf install -y \
                    docker-ce \
                    docker-ce-cli \
                    containerd.io \
                    docker-buildx-plugin \
                    docker-compose-plugin
                ;;

            arch)
                install_many docker docker-buildx docker-compose
                ;;
        esac
    else
        ok "Docker already installed"
    fi

    enable_system_service_if_exists docker.service

    if getent group docker >/dev/null 2>&1; then
        sudo usermod -aG docker "$USER"
    fi
fi


# -----------------------------------------------------------------------------
# Visual Studio Code
# -----------------------------------------------------------------------------

if [[ "$INSTALL_VSCODE" == true ]]; then
    log "Installing Visual Studio Code"

    if ! command -v code >/dev/null 2>&1; then
        case "$FAMILY" in
            debian)
                sudo install -d -m 0755 /etc/apt/keyrings

                curl -fsSL \
                    https://packages.microsoft.com/keys/microsoft.asc |
                    gpg --dearmor > /tmp/packages.microsoft.gpg

                sudo install \
                    -o root \
                    -g root \
                    -m 644 \
                    /tmp/packages.microsoft.gpg \
                    /etc/apt/keyrings/packages.microsoft.gpg

                rm -f /tmp/packages.microsoft.gpg

                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
                    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

                sudo apt-get update
                sudo apt-get install -y code
                ;;

            fedora)
                MICROSOFT_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
                MICROSOFT_KEY_TMP="$(mktemp)"
                MICROSOFT_KEY_PATH="/etc/pki/rpm-gpg/MICROSOFT-RPM-GPG-KEY"

                log "Downloading Microsoft signing key"

                if ! curl -fsSL \
                    --retry 5 \
                    --retry-delay 3 \
                    --retry-all-errors \
                    --connect-timeout 15 \
                    --max-time 120 \
                    "$MICROSOFT_KEY_URL" \
                    -o "$MICROSOFT_KEY_TMP"; then

                    rm -f "$MICROSOFT_KEY_TMP"
                    die "Failed to download Microsoft signing key"
                fi

                sudo install \
                    -o root \
                    -g root \
                    -m 644 \
                    "$MICROSOFT_KEY_TMP" \
                    "$MICROSOFT_KEY_PATH"

                sudo rpm --import "$MICROSOFT_KEY_PATH"

                rm -f "$MICROSOFT_KEY_TMP"

                cat <<'EOF_CODE' | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/MICROSOFT-RPM-GPG-KEY
EOF_CODE

                sudo dnf install -y code
                ;;

            arch)
                if install_paru_arch; then
                    paru -S --needed --noconfirm visual-studio-code-bin
                fi
                ;;
        esac
    else
        ok "VS Code already installed"
    fi
fi


# -----------------------------------------------------------------------------
# GitHub CLI
# -----------------------------------------------------------------------------

if [[ "$INSTALL_GITHUB_CLI" == true ]]; then
    install_pkg gh
fi
