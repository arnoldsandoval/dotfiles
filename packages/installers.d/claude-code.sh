#!/usr/bin/env bash
# claude code cli -> ~/.local/bin (no sudo) — official installer.
# linux only: macOS gets it via the claude-code cask (Brewfile.personal).
set -euo pipefail
[[ $(uname -s) == Linux ]] || exit 0
command -v claude >/dev/null && exit 0
curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || exit 0
echo "installed claude code -> ~/.local/bin"
