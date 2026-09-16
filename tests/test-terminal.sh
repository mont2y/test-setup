#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${SETUP_TEST_CHILD:-}" != terminal ]]; then
    test_home="$(mktemp -d)"
    trap 'rm -rf "$test_home"' EXIT
    env HOME="$test_home" SETUP_TEST_CHILD=terminal bash "$0"
    exit
fi
source "$ROOT_DIR/lib/common.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
install_package_manifest() { printf '%s\n' "$1" >> "$HOME/calls"; }
wezterm() { :; }
git() { :; }
sudo() { fail "Unexpected sudo: $*"; }
command() {
    if [[ "${1:-}" == -v && "${2:-}" == fc-* && "$font_mode" == no-fontconfig ]]; then return 1; fi
    builtin command "$@"
}
fc-match() {
    if [[ "$font_mode" == present ]]; then printf '%s\n' "${*: -1}"; else printf 'DejaVu Sans\n'; fi
}
fc-cache() { printf 'cache\n' >> "$HOME/calls"; }
curl() {
    printf 'download\n' >> "$HOME/calls"
    [[ "$download_failure" == false ]] || return 1
    printf 'mock archive\n' > "${*: -1}"
}
unzip() {
    local destination="${*: -1}"
    mkdir -p "$destination"
    printf 'mock font\n' > "$destination/JetBrainsMono-Regular.ttf"
    printf 'mock font\n' > "$destination/SymbolsNerdFontMono-Regular.ttf"
}
INSTALL_WEZTERM=true
WEZTERM_CONFIG_REPO=https://example.invalid/config.git
WEZTERM_CONFIG_BRANCH=main
font_mode=present
download_failure=false
for FAMILY in debian fedora arch; do
    : > "$HOME/calls"
    source "$ROOT_DIR/modules/20-terminal.sh" > "$HOME/log" 2>&1
    grep -Fxq "packages/fonts-$FAMILY.txt" "$HOME/calls" || fail "Missing $FAMILY manifest"
    ! grep -q download "$HOME/calls" || fail 'Existing font redownloaded'
done
font_mode=missing
: > "$HOME/calls"
source "$ROOT_DIR/modules/20-terminal.sh" > "$HOME/log" 2>&1
[[ "$(grep -c download "$HOME/calls")" == 2 ]] || fail 'Substitute font incorrectly accepted'
grep -q 'Required WezTerm font not found' "$HOME/log" || fail 'Missing font verification warning'
: > "$HOME/calls"
source "$ROOT_DIR/modules/20-terminal.sh" > "$HOME/log" 2>&1
! grep -q download "$HOME/calls" || fail 'Fallback fonts redownloaded on rerun'
download_failure=true
if install_wezterm_font_fallback 'Missing Font' failure https://example.invalid/font.zip '*.ttf' Missing.ttf > "$HOME/log" 2>&1; then
    fail 'Download error swallowed'
fi
[[ ! -e "$HOME/.local/share/fonts/failure" ]] || fail 'Failed download installed a font'
font_mode=no-fontconfig
source "$ROOT_DIR/modules/20-terminal.sh" > "$HOME/log" 2>&1
grep -q 'fontconfig unavailable' "$HOME/log" || fail 'Missing fontconfig warning'
INSTALL_WEZTERM=false
: > "$HOME/calls"
source "$ROOT_DIR/modules/20-terminal.sh"
[[ ! -s "$HOME/calls" ]] || fail 'Disabled WezTerm installed fonts'
printf 'WezTerm font selection, fallback, and rerun checks passed.\n'
