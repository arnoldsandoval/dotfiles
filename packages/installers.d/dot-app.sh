#!/usr/bin/env bash
# Dot.app — compile the notifier applet (macOS only). Banners attribute to
# "Dot" instead of terminal-notifier; clicking one focuses the session.
set -uo pipefail
[[ $(uname -s) == Darwin ]] || exit 0
command -v osacompile >/dev/null || exit 0
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/macos/dot-notifier.applescript"
app="$HOME/Applications/Dot.app"
[[ -f $src ]] || exit 0
# rebuild only when the source is newer than the app
if [[ -d $app && $app -nt $src ]]; then exit 0; fi
mkdir -p "$HOME/Applications"
if osacompile -o "$app" "$src" 2>/dev/null; then
  # new/updated sender needs its own notification permission -> re-run the
  # first-hub-open probe (the onboarding stamp pattern)
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/notify-ok"
  echo "built Dot.app notifier -> ~/Applications"
fi
