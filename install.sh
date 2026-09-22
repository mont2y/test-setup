#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "$ROOT_DIR/settings.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/packages.sh"

require_normal_user
detect_distro

for module in "$ROOT_DIR"/modules/*.sh; do
    log "Running $(basename "$module")"
    # shellcheck disable=SC1090
    source "$module"
done

log "Setup complete"
cat <<EOF2

Next steps:
  1. Log out and back in so Zsh, Docker, libvirt, and kvm group changes apply.
  2. Open WezTerm.
  3. Verify:
       echo \$SHELL
       nvm --version
       node --version
       python3 --version
       docker --version
       code --version
  4. Sign in where needed: Brave, Telegram, Steam, GitHub CLI, Postman.
EOF2
if [[ "${INSTALL_BITWARDEN_CLI:-false}" == true || "${RESTORE_BITWARDEN_SECRETS:-false}" == true ]]; then
    printf '\nBitwarden: bw status\nRefresh secrets: ./restore-secrets.sh\n'
fi
if [[ -s "$HOME/.config/rclone/rclone.conf" ]]; then
    printf 'rclone: verify your configuration with rclone listremotes\n'
else
    printf 'rclone: no configuration found; run ./restore-secrets.sh or rclone config\n'
fi
if [[ "${INSTALL_BITWARDEN_DESKTOP:-false}" == true ]]; then
    printf 'SSH: open Bitwarden Desktop and enable SSH Agent; follow the README socket instructions.\n'
fi
