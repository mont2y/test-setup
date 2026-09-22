#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
install_pkg() { printf 'install %s\n' "$1" >> "$tmpdir/calls"; }
# Direct queries and sudo service operations are mocked separately.
# shellcheck disable=SC2032
systemctl() {
    [[ "$*" == "show --property=LoadState --value "* ]] || fail "Unexpected systemctl: $*"
    if [[ "${*: -1}" == "$unit" ]]; then printf 'loaded\n'; else printf 'not-found\n'; fi
}
sudo() { printf '%s\n' "$*" >> "$tmpdir/calls"; }
INSTALL_CODEX=false
for FAMILY in debian fedora arch; do
    for INSTALL_OPENSSH_SERVER in false true; do
        for ENABLE_OPENSSH_SERVER in false true; do
            for unit in ssh.service sshd.service missing; do
                : > "$tmpdir/calls"
                : > "$tmpdir/expected"
                source "$ROOT_DIR/modules/90-services.sh" > "$tmpdir/log" 2>&1
                if [[ "$INSTALL_OPENSSH_SERVER" == true ]]; then
                    package=openssh-server
                    [[ "$FAMILY" != arch ]] || package=openssh
                    printf 'install %s\n' "$package" >> "$tmpdir/expected"
                    if [[ "$ENABLE_OPENSSH_SERVER" == true ]]; then
                        if [[ "$unit" == missing ]]; then
                            grep -q 'no loaded sshd.service or ssh.service' "$tmpdir/log" || fail 'Missing unit warning'
                        else
                            printf 'systemctl enable --now %s\n' "$unit" >> "$tmpdir/expected"
                        fi
                    fi
                fi
                cmp "$tmpdir/expected" "$tmpdir/calls" || fail "$FAMILY/$INSTALL_OPENSSH_SERVER/$ENABLE_OPENSSH_SERVER/$unit"
            done
        done
    done
done
printf 'OpenSSH settings and service checks passed.\n'
