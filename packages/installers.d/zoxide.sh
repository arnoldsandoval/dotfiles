#!/usr/bin/env bash
# zoxide -> ~/.local/bin (no sudo) — fallback when the system package is absent
set -euo pipefail
command -v zoxide >/dev/null && exit 0
curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
  | sh -s -- --bin-dir "$HOME/.local/bin" >/dev/null 2>&1 || exit 0
echo "installed zoxide -> ~/.local/bin"
