#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find "$ROOT_DIR" -type f -name '*.sh' -not -path '*/.git/*' -print0)
bash -n "$ROOT_DIR/scripts/with-bitwarden-secret"
printf 'Bash syntax checks passed.\n'
