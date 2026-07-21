#!/usr/bin/env bash
# fzf -> ~/.local/bin (no sudo) — static binary from GitHub releases
set -euo pipefail
command -v fzf >/dev/null && exit 0
arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) exit 0 ;; esac
os=$(uname -s | tr '[:upper:]' '[:lower:]'); [[ $os == linux || $os == darwin ]] || exit 0
json=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest 2>/dev/null) || exit 0
ver=""; [[ $json =~ \"tag_name\":[[:space:]]*\"v([^\"]+)\" ]] && ver="${BASH_REMATCH[1]}"
[[ -n $ver ]] || exit 0
mkdir -p "$HOME/.local/bin"
curl -fsSL "https://github.com/junegunn/fzf/releases/download/v$ver/fzf-$ver-${os}_$arch.tar.gz" \
  | tar -xz -C "$HOME/.local/bin" fzf 2>/dev/null || exit 0
chmod +x "$HOME/.local/bin/fzf"
echo "installed fzf v$ver -> ~/.local/bin"
