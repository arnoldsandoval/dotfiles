#!/usr/bin/env bash
# jq -> ~/.local/bin (no sudo) — static binary from GitHub releases
set -euo pipefail
command -v jq >/dev/null && exit 0
arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) exit 0 ;; esac
os=$(uname -s | tr '[:upper:]' '[:lower:]'); case $os in linux) os=linux ;; darwin) os=macos ;; *) exit 0 ;; esac
mkdir -p "$HOME/.local/bin"
curl -fsSL -o "$HOME/.local/bin/jq" \
  "https://github.com/jqlang/jq/releases/latest/download/jq-$os-$arch" || exit 0
chmod +x "$HOME/.local/bin/jq"
echo "installed jq -> ~/.local/bin"
