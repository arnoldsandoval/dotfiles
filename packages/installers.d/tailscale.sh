#!/usr/bin/env bash
# tailscale — the fleet's front door; every machine is tailnet-first.
# Linux only here (Macs get it via Brewfile). The official installer
# adds the apt/dnf repo and installs; it invokes sudo itself, which is
# fine in an interactive bootstrap and fails visibly in a non-sudo one.
# Joining stays human: auth is an identity decision, so we only nag.
set -euo pipefail
[[ $(uname -s) == Linux ]] || exit 0
command -v tailscale >/dev/null && exit 0
curl -fsSL https://tailscale.com/install.sh | sh
echo "installed tailscale — run 'sudo tailscale up' to join the tailnet"
