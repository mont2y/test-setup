#!/usr/bin/env bash

[[ "$INSTALL_LENOVO_LEGION_LINUX" == true ]] || return 0

vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
if [[ "$vendor" != *LENOVO* && "$vendor" != *Lenovo* ]]; then
    warn "This machine does not identify as Lenovo; skipping LenovoLegionLinux"
    return 0
fi

log "Installing LenovoLegionLinux"
case "$FAMILY" in
    debian)
        install_many make gcc build-essential git lm-sensors wget python3-pyqt6 python3-yaml python3-venv python3-pip python3-argcomplete python3-darkdetect dkms openssl mokutil
        sudo apt-get install -y "linux-headers-$(uname -r)" || warn "Could not install running-kernel headers"
        ;;
    fedora)
        install_many kernel-headers kernel-devel dmidecode lm_sensors python3-qt6 python3-pyqt6 python3-yaml python3-pip python3-argcomplete python3-darkdetect dkms openssl mokutil
        sudo dnf group install -y "Development Tools" || true
        ;;
    arch)
        install_many base-devel lm_sensors git dmidecode python-pyqt6 python-yaml python-argcomplete python-darkdetect dkms openssl mokutil
        if [[ ! -e "/usr/lib/modules/$(uname -r)/build" ]]; then
            kernel_pkg="$(pacman -Qqo "/usr/lib/modules/$(uname -r)/vmlinuz" 2>/dev/null || true)"
            if [[ -n "$kernel_pkg" ]] && pkg_available "${kernel_pkg}-headers"; then
                install_pkg "${kernel_pkg}-headers"
            else
                warn "Could not automatically determine kernel headers"
            fi
        fi
        ;;
esac

src="$HOME/.local/src/LenovoLegionLinux"
mkdir -p "$HOME/.local/src"
if [[ -d "$src/.git" ]]; then
    git -C "$src" pull --ff-only || warn "Could not update LenovoLegionLinux"
else
    git clone https://github.com/johnfanv2/LenovoLegionLinux.git "$src"
fi

if [[ -e "/usr/lib/modules/$(uname -r)/build" ]]; then
    (cd "$src/kernel_module" && sudo make dkms) || warn "LenovoLegionLinux DKMS installation failed"
else
    warn "Skipping LenovoLegionLinux DKMS build because kernel headers are missing"
fi

if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
    warn "Secure Boot is enabled; LenovoLegionLinux may need DKMS module signing/MOK enrollment"
fi
