#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Run the module in a disposable home; every privileged/network command is mocked.
if [[ "${SETUP_TEST_CHILD:-}" != legion ]]; then
    test_home="$(mktemp -d)"
    trap 'rm -rf "$test_home"' EXIT
    env HOME="$test_home" SETUP_TEST_CHILD=legion bash "$0"
    exit
fi
source "$ROOT_DIR/lib/common.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
install_package_manifest() { printf '%s\n' "$1" >> "$HOME/calls"; }
install_pkg() { printf 'package %s\n' "$1" >> "$HOME/calls"; }
pkg_available() { return 0; }
uname() { printf 'setup-test-kernel\n'; }
zgrep() {
    [[ " $* " != *' /proc/config.gz '* ]] || return 1
    command zgrep "$@"
}
cat() {
    if [[ "$1" == /sys/class/dmi/id/sys_vendor ]]; then printf '%s\n' "$test_vendor"; else command cat "$@"; fi
}
# Both direct package queries and sudo are mocked separately.
# shellcheck disable=SC2032
pacman() { printf 'linux-test\n'; }
sudo() {
    printf 'sudo %s\n' "$*" >> "$HOME/calls"
    [[ "$*" != 'make dkms' || "$dkms_failure" == false ]]
}
git() {
    printf 'git %s\n' "$*" >> "$HOME/calls"
    if [[ "$1" == clone ]]; then
        mkdir -p "$3/.git" "$3/kernel_module"
    fi
}
pipx() {
    if [[ "$1" == environment ]]; then printf '%s\n' "$HOME/.local/bin"; return 0; fi
    printf 'pipx %s\n' "$*" >> "$HOME/calls"
    [[ "$pipx_failure" == false ]] || return 1
    mkdir -p "$HOME/.local/bin"
    for executable in legion_cli legion_gui; do
        printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/$executable"
        chmod +x "$HOME/.local/bin/$executable"
    done
}
mokutil() { printf 'SecureBoot enabled\n'; }
INSTALL_LENOVO_LEGION_LINUX=true
dkms_failure=false
pipx_failure=false
for scenario in non-lenovo debian fedora arch cachyos pipx-failure; do
    test_vendor=LENOVO
    FAMILY=arch
    DISTRO_ID=arch
    pipx_failure=false
    case "$scenario" in
        non-lenovo) test_vendor=Dell ;;
        debian|fedora) FAMILY="$scenario"; DISTRO_ID="$scenario" ;;
        cachyos) DISTRO_ID=cachyos ;;
        pipx-failure) pipx_failure=true ;;
    esac
    : > "$HOME/calls"
    source "$ROOT_DIR/modules/70-legion.sh" > "$HOME/log" 2>&1
    if [[ "$scenario" == non-lenovo ]]; then
        [[ ! -s "$HOME/calls" ]] || fail 'Non-Lenovo installed something'
        continue
    fi
    grep -Fxq 'packages/legion-common.txt' "$HOME/calls" || fail 'Missing common manifest'
    grep -Fxq "packages/legion-$FAMILY.txt" "$HOME/calls" || fail 'Missing family manifest'
    if [[ "$scenario" == cachyos ]]; then
        grep -Fxq 'packages/legion-clang-arch.txt' "$HOME/calls" || fail 'CachyOS missing Clang'
    else
        ! grep -q 'legion-clang' "$HOME/calls" || fail 'Unnecessary Clang install'
    fi
    if [[ "$scenario" == debian ]]; then
        grep -q 'apt-get install -y linux-headers-setup-test-kernel' "$HOME/calls" || fail 'Missing headers attempt'
    fi
    grep -q 'pipx install --force --system-site-packages --python python3' "$HOME/calls" || fail 'Missing isolated install'
    grep -q 'Secure Boot is enabled' "$HOME/log" || fail 'Missing Secure Boot warning'
    if [[ "$scenario" == pipx-failure ]]; then
        grep -q 'legion_gui/legion_cli installation failed' "$HOME/log" || fail 'Missing pipx failure warning'
    else
        if ! command -v legion_cli >/dev/null || ! command -v legion_gui >/dev/null; then
            fail 'Missing commands'
        fi
    fi
done
# Use fixture paths to cover kernel detection independently of the host kernel.
DISTRO_ID=arch
printf 'CONFIG_CC_IS_CLANG=y\n' > "$HOME/kernel-config"
legion_kernel_uses_clang "$HOME/kernel-config" "$HOME/missing" || fail 'Boot config detection'
gzip -c "$HOME/kernel-config" > "$HOME/config.gz"
legion_kernel_uses_clang "$HOME/missing" "$HOME/config.gz" || fail 'Compressed config detection'
printf '# CONFIG_CC_IS_CLANG is not set\n' > "$HOME/kernel-config"
if legion_kernel_uses_clang "$HOME/kernel-config" "$HOME/missing"; then fail 'False Clang detection'; fi
DISTRO_ID=cachyos
legion_kernel_uses_clang "$HOME/missing" "$HOME/missing" || fail 'CachyOS fallback'
mkdir -p "$HOME/build"
for dkms_failure in false true; do
    install_legion_dkms "$src" "$HOME/build" > "$HOME/log" 2>&1
    if [[ "$dkms_failure" == true ]]; then
        grep -q 'DKMS installation failed' "$HOME/log" || fail 'Missing DKMS failure warning'
    else
        grep -q 'DKMS module installed' "$HOME/log" || fail 'Missing DKMS success'
    fi
done
INSTALL_LENOVO_LEGION_LINUX=false
: > "$HOME/calls"
source "$ROOT_DIR/modules/70-legion.sh"
[[ ! -s "$HOME/calls" ]] || fail 'Disabled Lenovo setup installed something'
printf 'Lenovo hardware, Clang, pipx, and DKMS checks passed.\n'
