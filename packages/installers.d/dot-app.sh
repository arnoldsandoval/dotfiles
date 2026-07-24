#!/usr/bin/env bash
# Dot.app — compile the notifier applet (macOS only). Banners attribute to
# "Dot" instead of terminal-notifier; clicking one focuses the session.
#
# Raw osacompile output is NOT enough for Notification Center: applets ship
# without a real CFBundleIdentifier and unsigned, and modern macOS silently
# drops their notifications (no banner, no permission prompt, app never
# appears in Settings -> Notifications). So after compiling: stamp a stable
# bundle id, mark it a background app (no Dock bounce per ping), and ad-hoc
# sign it.
set -uo pipefail
[[ $(uname -s) == Darwin ]] || exit 0
command -v osacompile >/dev/null || exit 0
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/macos/dot-notifier.applescript"
app="$HOME/Applications/Dot.app"
me="${BASH_SOURCE[0]}"
[[ -f $src ]] || exit 0
# rebuild when the applescript OR this build recipe changed
if [[ -d $app && $app -nt $src && $app -nt $me ]]; then exit 0; fi
mkdir -p "$HOME/Applications"
rm -rf "$app"   # never layer over a stale bundle
if osacompile -o "$app" "$src" 2>/dev/null; then
  plist="$app/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "sh.dotfiles.dot" "$plist"
  plutil -replace CFBundleName -string "Dot" "$plist"
  plutil -replace LSUIElement -bool true "$plist"
  codesign --force -s - "$app" 2>/dev/null || true
  # refresh LaunchServices so the new identity is seen immediately
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$app" 2>/dev/null || true
  # new/updated sender needs its own notification permission -> re-run the
  # first-hub-open probe (the onboarding stamp pattern)
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/notify-ok"
  echo "built Dot.app notifier -> ~/Applications"
fi
