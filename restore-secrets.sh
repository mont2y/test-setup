#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/settings.sh"
source "$ROOT_DIR/lib/common.sh"
[[ $EUID -ne 0 ]] || die 'Run secret restoration as your normal user, not root'
source "$ROOT_DIR/modules/80-secrets.sh"
