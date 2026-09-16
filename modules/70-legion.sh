#!/usr/bin/env bash

[[ "$INSTALL_LENOVO_LEGION_LINUX" == true ]] || return 0

legion_kernel_uses_clang() {
    local config="${1:-/boot/config-$(uname -r)}" proc_config="${2:-/proc/config.gz}"
    if [[ -r "$config" ]] && grep -q '^CONFIG_CC_IS_CLANG=y' "$config"; then
        return 0
    fi
    if [[ -r "$proc_config" ]] && zgrep '^CONFIG_CC_IS_CLANG=y' "$proc_config" >/dev/null; then
        return 0
    fi
    [[ "$DISTRO_ID" == cachyos ]]
}

install_legion_python_tools() {
    local source_dir="$1" bin_dir
    command -v pipx >/dev/null 2>&1 || { warn 'pipx unavailable; cannot install legion_cli/legion_gui'; return 1; }
    # Reuse distro Qt/Pillow where available, while keeping pip writes in a venv.
    # --force refreshes the same environment from the updated local checkout.
    pipx install --force --system-site-packages --python python3 "$source_dir/python/legion_linux" || return 1
    bin_dir="$(pipx environment --value PIPX_BIN_DIR)" || return 1
    [[ -n "$bin_dir" ]] || return 1
    export PATH="$bin_dir:$PATH"
    command -v legion_cli >/dev/null 2>&1 && command -v legion_gui >/dev/null 2>&1 || return 1
    ok 'LenovoLegionLinux legion_cli and legion_gui installed'
}

install_legion_dkms() {
    local source_dir="$1" build_dir="${2:-/usr/lib/modules/$(uname -r)/build}"
    if [[ -e "$build_dir" ]]; then
        if (cd "$source_dir/kernel_module" && sudo make dkms); then
            ok 'LenovoLegionLinux DKMS module installed'
        else
            warn 'LenovoLegionLinux DKMS installation failed'
        fi
    else
        warn 'Skipping LenovoLegionLinux DKMS build because kernel headers are missing'
    fi
}

vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
if [[ "$vendor" != *LENOVO* && "$vendor" != *Lenovo* ]]; then
    warn "This machine does not identify as Lenovo; skipping LenovoLegionLinux"
    return 0
fi

log "Installing LenovoLegionLinux"
install_package_manifest "packages/legion-common.txt"
install_package_manifest "packages/legion-${FAMILY}.txt"
case "$FAMILY" in
    debian)
        sudo apt-get install -y "linux-headers-$(uname -r)" || warn "Could not install running-kernel headers"
        ;;
    fedora)
        sudo dnf group install -y "Development Tools" || warn 'Could not install Fedora Development Tools'
        ;;
    arch)
        if legion_kernel_uses_clang; then
            install_package_manifest "packages/legion-clang-arch.txt"
        fi
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
    if ! git clone https://github.com/johnfanv2/LenovoLegionLinux.git "$src"; then
        warn 'Could not clone LenovoLegionLinux; skipping its installation'
        return 0
    fi
fi

install_legion_dkms "$src"

if ! install_legion_python_tools "$src"; then
    warn 'LenovoLegionLinux legion_gui/legion_cli installation failed; see the separate DKMS result above'
fi

if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'; then
    warn "Secure Boot is enabled; LenovoLegionLinux may need DKMS module signing/MOK enrollment"
fi
