#!/usr/bin/env bash
# ripgrep -> ~/.local/bin (no sudo) — static (musl) binary from GitHub releases
set -euo pipefail
command -v rg >/dev/null && exit 0
arch=$(uname -m); case $arch in x86_64|aarch64|arm64) ;; *) exit 0 ;; esac
os=$(uname -s)
case $os in
  Linux)  [[ $arch == x86_64 ]] && triple=x86_64-unknown-linux-musl || triple=aarch64-unknown-linux-gnu ;;
  Darwin) [[ $arch == x86_64 ]] && triple=x86_64-apple-darwin || triple=aarch64-apple-darwin ;;
  *) exit 0 ;;
esac
json=$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest 2>/dev/null) || exit 0
ver=""; [[ $json =~ \"tag_name\":[[:space:]]*\"([^\"]+)\" ]] && ver="${BASH_REMATCH[1]}"
[[ -n $ver ]] || exit 0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$ver/ripgrep-$ver-$triple.tar.gz" \
  | tar -xz -C "$tmp" 2>/dev/null || exit 0
mkdir -p "$HOME/.local/bin"
find "$tmp" -name rg -type f -exec mv {} "$HOME/.local/bin/rg" \;
chmod +x "$HOME/.local/bin/rg"
echo "installed ripgrep $ver -> ~/.local/bin"
