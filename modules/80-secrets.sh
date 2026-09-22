#!/usr/bin/env bash

# shellcheck source=../lib/bitwarden.sh
source "$ROOT_DIR/lib/bitwarden.sh"

# Application mappings stay here; the library only knows generic vault/files.
# Both install.sh and restore-secrets.sh use this same function and policy.
restore_bitwarden_secrets() (
    [[ $- != *x* ]] || { bitwarden_error 'Bitwarden secret access refuses shell tracing'; return 1; }
    [[ "${RESTORE_RCLONE_FROM_BITWARDEN:-true}" == true ]] || return 0
    bitwarden_guard || return 1
    BITWARDEN_RELOCK=false
    trap bitwarden_cleanup_session EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    bitwarden_authenticate || return 1
    # shellcheck source=../configs/bitwarden/items.sh
    source "$ROOT_DIR/configs/bitwarden/items.sh"
    bitwarden_restore_note_file "$BITWARDEN_RCLONE_ITEM" "$BITWARDEN_RCLONE_DEST" "$BITWARDEN_RCLONE_MODE" || return 1
    ok 'rclone configuration is ready' >&2
)

[[ "${RESTORE_BITWARDEN_SECRETS:-true}" == true ]] || return 0
if ! restore_bitwarden_secrets; then
    bitwarden_secret_failure 'Bitwarden secret restoration incomplete; rerun ./restore-secrets.sh after resolving the warning'
fi
