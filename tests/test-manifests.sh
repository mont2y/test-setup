#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT_DIR/lib/packages.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

validate_manifest() {
    local manifest="$1" normalized line
    local -A seen=()
    normalized="$(read_package_manifest "$manifest")" || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ ! "$line" =~ [[:space:]]$ ]] || die "Trailing whitespace in $manifest: $line"
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -n "$line" && "$line" != \#* ]] || continue
        [[ -z "${seen[$line]:-}" ]] || die "Duplicate package in $manifest: $line"
        seen["$line"]=1
    done < "$manifest"
}

manifests=("$ROOT_DIR"/packages/*.txt)
[[ -f "${manifests[0]}" ]] || fail 'No manifests found'
for manifest in "${manifests[@]}"; do
    validate_manifest "$manifest"
done

fixture="$tmpdir/manifest with spaces.txt"
printf '  # comment\n\n git \r\n\tcurl\t\ngit\nlibc6:amd64\ngcc-c++\nname_1.0@repo\nwget' > "$fixture"
expected=$'git\ncurl\nlibc6:amd64\ngcc-c++\nname_1.0@repo\nwget'
[[ "$(read_package_manifest "$fixture")" == "$expected" ]] || fail 'Normalization or ordering'
(cd "$tmpdir"; [[ "$(read_package_manifest packages/common.txt)" == "$(read_package_manifest "$ROOT_DIR/packages/common.txt")" ]]) || fail 'Relative path resolution'

# Mock all external package-manager commands; never install anything in tests.
pkg_installed() { [[ "$1" == installed ]]; }
pkg_available() { [[ "$1" != missing ]]; }
sudo() { printf '%s\n' "$*" >> "$tmpdir/calls"; }
printf 'installed\nmissing\ngit\ngit\ncurl\n' > "$fixture"
for FAMILY in debian fedora arch; do
    : > "$tmpdir/calls"
    install_package_manifest "$fixture" > "$tmpdir/log" 2> "$tmpdir/warnings"
    case "$FAMILY" in
        debian) manager='apt-get install -y' ;;
        fedora) manager='dnf install -y' ;;
        arch) manager='pacman -S --needed --noconfirm' ;;
    esac
    printf '%s git\n%s curl\n' "$manager" "$manager" > "$tmpdir/expected"
    cmp "$tmpdir/expected" "$tmpdir/calls" || fail "Wrong transaction for $FAMILY"
    [[ "$(cat "$tmpdir/warnings")" == *'missing is not available'* ]] || fail 'Missing warning'
    [[ "$(cat "$tmpdir/log")" == *"$fixture"* ]] || fail 'Missing manifest log'
done

: > "$tmpdir/calls"
printf '# empty\n\n' > "$fixture"
install_package_manifest "$fixture" >/dev/null
[[ ! -s "$tmpdir/calls" ]] || fail 'Empty manifest installed packages'
if (install_package_manifest "$tmpdir/absent") > "$tmpdir/log" 2>&1; then
    fail 'Missing manifest accepted'
fi
[[ "$(cat "$tmpdir/log")" == *'missing or unreadable'* ]] || fail 'Missing error message'
for invalid in 'sudo apt install vim' 'apt-get' 'dnf install git' 'pacman -S git' '$(touch sentinel)' 'git;true' '--help' '-y' 'git # inline'; do
    printf 'git\n%s\n' "$invalid" > "$fixture"
    if (install_package_manifest "$fixture") >/dev/null 2>&1; then
        fail "Invalid entry accepted: $invalid"
    fi
    [[ ! -s "$tmpdir/calls" ]] || fail 'Invalid manifest partially installed'
done
printf 'git\ngit\n' > "$fixture"
if (validate_manifest "$fixture") >/dev/null 2>&1; then
    fail 'Duplicate not detected by validator'
fi
printf 'git \n' > "$fixture"
if (validate_manifest "$fixture") >/dev/null 2>&1; then
    fail 'Trailing whitespace not detected'
fi
# Installation errors must reach the caller.
printf 'git\ncurl\n' > "$fixture"
sudo() { [[ "$*" != *git ]]; }
if (install_package_manifest "$fixture") >/dev/null 2>&1; then
    fail 'Installation failure swallowed'
fi

# Base/build tools and Python must keep their independent settings switches.
(
    # shellcheck source=../settings.sh
    source "$ROOT_DIR/settings.sh"
    UPDATE_SYSTEM=false
    INSTALL_NVM_NODE=false
    INSTALL_DOCKER=false
    INSTALL_VSCODE=false
    INSTALL_GITHUB_CLI=false
    install_package_manifest() { printf '%s\n' "$1" >> "$tmpdir/calls"; }
    for FAMILY in debian fedora arch; do
        for INSTALL_BASE in true false; do
            for INSTALL_PYTHON in true false; do
                : > "$tmpdir/calls"
                : > "$tmpdir/expected"
                # shellcheck source=../modules/00-system.sh
                source "$ROOT_DIR/modules/00-system.sh"
                # shellcheck source=../modules/30-dev.sh
                source "$ROOT_DIR/modules/30-dev.sh" >/dev/null
                if [[ "$INSTALL_BASE" == true ]]; then
                    printf '%s\n' packages/common.txt "packages/$FAMILY.txt" packages/build-common.txt "packages/build-$FAMILY.txt" >> "$tmpdir/expected"
                fi
                if [[ "$INSTALL_PYTHON" == true ]]; then
                    printf '%s\n' "packages/development-$FAMILY.txt" >> "$tmpdir/expected"
                fi
                cmp "$tmpdir/expected" "$tmpdir/calls" || fail "Settings changed for $FAMILY"
            done
        done
    done
)
printf 'Manifest validation and mocked installation checks passed (%s manifests).\n' "${#manifests[@]}"
