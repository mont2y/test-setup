#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
install_package_manifest() { :; }
systemctl() { printf 'not-found\n'; }
getent() { return 1; }
virsh() { fail 'virsh must use sudo, C locale, and the system connection'; }
sudo() {
    [[ "$1 $2 $3 $4 $5 $6" == 'env LC_ALL=C virsh --connect qemu:///system net-'* ]] || fail "Unexpected sudo: $*"
    shift 5
    printf '%s\n' "$1" >> "$tmpdir/calls"
    case "$1" in
        net-list)
            [[ "$scenario" != list-failure ]] || return 1
            [[ -f "$tmpdir/exists" ]] && printf 'default\n'
            return 0 ;;
        net-define)
            [[ "$scenario" != define-failure ]] || return 1
            grep -q "192.168.122.1" "$2" || fail 'Wrong network definition'
            touch "$tmpdir/exists" ;;
        net-info)
            [[ "$scenario" != info-failure ]] || return 1
            printf 'Active: %s\nAutostart: %s\n' "$(cat "$tmpdir/active")" "$(cat "$tmpdir/autostart")" ;;
        net-start)
            [[ "$scenario" != start-failure ]] || return 1
            printf 'yes\n' > "$tmpdir/active" ;;
        net-autostart)
            [[ "$scenario" != autostart-failure ]] || return 1
            [[ "$scenario" == verification-failure ]] || printf 'yes\n' > "$tmpdir/autostart" ;;
        *) fail "Unexpected virsh: $*" ;;
    esac
    return 0
}
INSTALL_VIRTUALIZATION=true
FAMILY=debian
for scenario in missing inactive active start-failure autostart-failure list-failure define-failure info-failure verification-failure; do
    : > "$tmpdir/calls"
    rm -f "$tmpdir/exists"
    printf 'no\n' > "$tmpdir/active"
    printf 'no\n' > "$tmpdir/autostart"
    case "$scenario" in missing|define-failure) ;; *) touch "$tmpdir/exists" ;; esac
    [[ "$scenario" != active ]] || printf 'yes\n' > "$tmpdir/active"
    source "$ROOT_DIR/modules/60-virtualization.sh" > "$tmpdir/log" 2>&1
    case "$scenario" in
        missing) expected=$'net-list\nnet-define\nnet-info\nnet-start\nnet-autostart\nnet-info' ;;
        active) expected=$'net-list\nnet-info\nnet-autostart\nnet-info' ;;
        list-failure) expected=net-list ;;
        define-failure) expected=$'net-list\nnet-define' ;;
        info-failure) expected=$'net-list\nnet-info' ;;
        *) expected=$'net-list\nnet-info\nnet-start\nnet-autostart\nnet-info' ;;
    esac
    [[ "$(cat "$tmpdir/calls")" == "$expected" ]] || fail "Wrong flow: $scenario"
    case "$scenario" in
        *failure) grep -Eq 'Could not|verification failed' "$tmpdir/log" || fail "Missing warning: $scenario" ;;
        *) grep -q 'is active with autostart enabled' "$tmpdir/log" || fail "Missing verification: $scenario" ;;
    esac
done
printf 'Libvirt state and failure checks passed.\n'
