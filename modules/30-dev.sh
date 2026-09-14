#!/usr/bin/env bash

if [[ "$INSTALL_NVM_NODE" == true ]]; then
    export NVM_DIR="$HOME/.nvm"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log "Installing NVM $NVM_VERSION"
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash
    fi
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1090
        source "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm alias default 'lts/*'
        nvm use default
    fi
fi

if [[ "$INSTALL_PYTHON" == true ]]; then
    log "Installing Python development tools"
    case "$FAMILY" in
        debian) install_many python3 python3-pip python3-venv pipx ;;
        fedora) install_many python3 python3-pip pipx ;;
        arch) install_many python python-pip python-pipx ;;
    esac
fi

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
                [[ -n "$docker_suite" ]] || die "Could not determine Debian/Ubuntu codename for Docker"
                sudo install -m 0755 -d /etc/apt/keyrings
                sudo curl -fsSL "https://download.docker.com/linux/${docker_os}/gpg" -o /etc/apt/keyrings/docker.asc
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
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            fedora)
                install_pkg dnf-plugins-core
                sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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

if [[ "$INSTALL_VSCODE" == true ]]; then
    log "Installing Visual Studio Code"
    if ! command -v code >/dev/null 2>&1; then
        case "$FAMILY" in
            debian)
                sudo install -d -m 0755 /etc/apt/keyrings
                curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
                sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                rm -f /tmp/packages.microsoft.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
                sudo apt-get update
                sudo apt-get install -y code
                ;;
            fedora)
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                cat <<'EOF_CODE' | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
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

if [[ "$INSTALL_GITHUB_CLI" == true ]]; then
    install_pkg gh
fi
