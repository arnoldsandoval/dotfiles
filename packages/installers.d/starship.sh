#!/usr/bin/env bash
# starship prompt -> ~/.local/bin (no sudo)
set -euo pipefail
command -v starship >/dev/null && exit 0
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y >/dev/null
echo "installed starship -> ~/.local/bin"
