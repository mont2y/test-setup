#!/usr/bin/env bash

# common.sh supplies logging and package-manager helpers; install.sh sources both.
package_manifest_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$ROOT_DIR" "$1" ;;
    esac
}

read_package_manifest() {
    local manifest line
    local -A seen=()
    manifest="$(package_manifest_path "$1")"
    [[ -f "$manifest" && -r "$manifest" ]] || die "Required package manifest is missing or unreadable: $manifest"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" && "$line" != \#* ]] || continue
        # Reject commands and option-like entries before passing data to a manager.
        [[ "$line" =~ ^[a-zA-Z0-9@][a-zA-Z0-9+._@:-]*$ ]] || die "Invalid package name in $manifest: $line"
        case "$line" in
            sudo|apt|apt-get|dnf|yum|pacman) die "Package-manager command in $manifest: $line" ;;
        esac
        if [[ -z "${seen[$line]:-}" ]]; then
            printf '%s\n' "$line"
            seen["$line"]=1
        fi
    done < "$manifest"
}

install_package_manifest() {
    local normalized
    local -a packages=()
    log "Installing package manifest: $1"
    # Capture the status explicitly: process substitution would hide parse errors.
    normalized="$(read_package_manifest "$1")" || return 1
    [[ -n "$normalized" ]] || return 0
    mapfile -t packages <<< "$normalized"
    # Reuse installed/availability checks and warnings for each package.
    install_many "${packages[@]}"
}
