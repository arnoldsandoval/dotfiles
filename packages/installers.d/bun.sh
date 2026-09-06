#!/usr/bin/env bash
# bun -> ~/.bun (no sudo)
set -euo pipefail
command -v bun >/dev/null && exit 0
[[ -x $HOME/.bun/bin/bun ]] && exit 0
# bun's installer unpacks a zip; without unzip it dies. Say so instead
# of failing silently (a fresh Ubuntu Server ships without it — the
# intent.txt apt list now includes it, this guard covers other distros).
if ! command -v unzip >/dev/null; then
  echo "bun: needs 'unzip' (apt install unzip) — skipping" >&2
  exit 1
fi
out=$(curl -fsSL https://bun.sh/install | bash 2>&1) || { echo "bun installer failed:" >&2; echo "$out" | tail -5 >&2; exit 1; }
echo "installed bun -> ~/.bun"
