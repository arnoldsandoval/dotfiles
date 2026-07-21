#!/usr/bin/env bash
# gum (charmbracelet) -> ~/.local/bin (no sudo). Static binary from GitHub releases.
set -euo pipefail
command -v gum >/dev/null && exit 0
arch=$(uname -m); case $arch in x86_64) arch=x86_64 ;; aarch64|arm64) arch=arm64 ;; *) exit 0 ;; esac
os=$(uname -s); case $os in Linux) os=Linux ;; Darwin) os=Darwin ;; *) exit 0 ;; esac
# no pipes here: early-exit consumers (grep -m1) SIGPIPE their producer under pipefail
json=$(curl -fsSL https://api.github.com/repos/charmbracelet/gum/releases/latest 2>/dev/null) || exit 0
ver=""
[[ $json =~ \"tag_name\":[[:space:]]*\"([^\"]+)\" ]] && ver="${BASH_REMATCH[1]}"
[[ -n $ver ]] || exit 0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/charmbracelet/gum/releases/download/$ver/gum_${ver#v}_${os}_${arch}.tar.gz" \
  | tar -xz -C "$tmp" 2>/dev/null || exit 0
mkdir -p "$HOME/.local/bin"
find "$tmp" -name gum -type f -exec mv {} "$HOME/.local/bin/gum" \;
chmod +x "$HOME/.local/bin/gum"
echo "installed gum $ver -> ~/.local/bin"
