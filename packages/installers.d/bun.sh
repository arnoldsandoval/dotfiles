#!/usr/bin/env bash
# bun -> ~/.bun (no sudo)
set -euo pipefail
command -v bun >/dev/null && exit 0
[[ -x $HOME/.bun/bin/bun ]] && exit 0
curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1
echo "installed bun -> ~/.bun"
