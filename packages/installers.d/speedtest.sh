#!/usr/bin/env bash
# Ookla speedtest CLI -> ~/.local/bin (no sudo; static binary).
# Linux only — macs get it via Brewfile (tap teamookla/speedtest).
set -euo pipefail
[[ $(uname -s) == Linux ]] || exit 0
command -v speedtest >/dev/null && exit 0
arch=$(uname -m); case $arch in x86_64|aarch64) ;; *) echo "speedtest: no static build for $arch — skipping" >&2; exit 0 ;; esac
url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${arch}.tgz"
tmp=$(mktemp -d)
curl -fsSL "$url" -o "$tmp/st.tgz" && tar -xzf "$tmp/st.tgz" -C "$tmp" speedtest
mkdir -p "$HOME/.local/bin" && mv "$tmp/speedtest" "$HOME/.local/bin/" && rm -rf "$tmp"
echo "installed speedtest -> ~/.local/bin"
