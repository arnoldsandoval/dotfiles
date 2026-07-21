#!/usr/bin/env bash
# install-hooks.sh — idempotent install of:
#   - the ~/.bashrc managed block (linux: exec-zsh guard + fallback aliases)
#   - the background-fetch timer (systemd user on linux / launchd on macOS)
set -euo pipefail
DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES/lib/core.sh"
source "$DOTFILES/lib/platform.sh"

# --- bashrc managed block (linux only) --------------------------------------
if [[ $OS == linux ]]; then
  rc="$HOME/.bashrc"
  begin="# >>> dotfiles >>>"
  end="# <<< dotfiles <<<"
  block=$(cat <<EOF
$begin
# managed by dotfiles — do not edit inside the markers (rerun 'dotfiles bootstrap')
[ -f "$DOTFILES/config/bash/bashrc-hook.sh" ] && . "$DOTFILES/config/bash/bashrc-hook.sh"
$end
EOF
)
  touch "$rc"
  if grep -qF "$begin" "$rc"; then
    # replace existing block in place
    awk -v b="$begin" -v e="$end" -v repl="$block" '
      $0==b {inblk=1; print repl; next}
      $0==e {inblk=0; next}
      !inblk {print}
    ' "$rc" >"$rc.tmp" && mv "$rc.tmp" "$rc"
  else
    printf '\n%s\n' "$block" >>"$rc"
  fi
  ok "bashrc managed block installed"
fi

# --- fetch timer -------------------------------------------------------------
if [[ $OS == linux ]] && has systemctl; then
  unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$unit_dir"
  for u in dotfiles-fetch.service dotfiles-fetch.timer; do
    src="$DOTFILES/services/systemd/$u"
    [[ -L $unit_dir/$u && $(readlink "$unit_dir/$u") == "$src" ]] || ln -sf "$src" "$unit_dir/$u"
  done
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now dotfiles-fetch.timer 2>/dev/null \
    && ok "systemd fetch timer enabled" \
    || warn "could not enable fetch timer (no systemd user session?)"
elif [[ $OS == darwin ]]; then
  plist_src="$DOTFILES/services/launchd/io.arnie.dotfiles-fetch.plist"
  plist_dst="$HOME/Library/LaunchAgents/io.arnie.dotfiles-fetch.plist"
  mkdir -p "$(dirname "$plist_dst")"
  # launchd refuses symlinked plists in some versions — copy with path substitution
  sed "s|__DOTFILES__|$DOTFILES|g" "$plist_src" >"$plist_dst"
  launchctl bootstrap "gui/$(id -u)" "$plist_dst" 2>/dev/null || true
  ok "launchd fetch agent installed"
fi
