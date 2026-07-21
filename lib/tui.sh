# tui.sh — gum-enhanced UI primitives with plain-bash fallbacks.
# Everything here must work with gum ABSENT (Tier-0 guarantee).
# shellcheck shell=bash

# NOTE: check stdin+stderr, not stdout — ui_choose is called inside $(...)
# where stdout is a pipe; gum draws its UI on the tty and prints to stdout.
ui_has_gum() { has gum && [[ -t 0 && -t 2 ]]; }

# ui_choose HEADER OPTION... -> prints chosen option (empty on cancel)
# Numbered entry in both modes (type the number, enter). gum = styling only,
# so the muscle memory is identical with or without it. enter/q/esc = skip.
ui_choose() {
  local header=$1; shift
  # Pure bash on purpose: gum probes the terminal with escape queries
  # (ESC]11;? / ESC[6n) and reads replies from stdin — on the login path that
  # can swallow type-ahead or hang under a fed pty. A drawn box needs neither.
  local c i opt
  {
    printf '┌─ %s ' "$header"; printf '─%.0s' {1..8}; echo
    i=1
    for opt in "$@"; do printf '│  %d) %s\n' "$i" "$opt"; i=$((i+1)); done
    printf '└─'; echo
  } >&2
  while true; do
    printf "❯ 1-%d (enter = shell): " "$#" >&2
    read -r c || { echo >&2; return 0; }
    [[ -z $c || $c == q ]] && return 0
    if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= $# )); then
      eval "echo \"\${$c}\""; return 0
    fi
    echo "  '$c' isn't an option" >&2
  done
}

# ui_confirm PROMPT -> exit 0 yes / 1 no
ui_confirm() {
  if ui_has_gum; then gum confirm "$1"; else
    printf '%s [y/N] ' "$1" >&2
    local a; read -r a; [[ $a == y || $a == Y ]]
  fi
}

# ui_input PROMPT [DEFAULT]
ui_input() {
  local prompt=$1 def=${2:-}
  if ui_has_gum; then
    gum input --prompt "$prompt: " ${def:+--value "$def"}
  else
    printf '%s%s: ' "$prompt" "${def:+ [$def]}" >&2
    local v; read -r v; echo "${v:-$def}"
  fi
}

# ui_spin TITLE CMD... -> run command with a spinner when gum present
ui_spin() {
  local title=$1; shift
  if ui_has_gum; then gum spin --title "$title" -- "$@"; else log "$title"; "$@"; fi
}

# ui_header TEXT
ui_header() {
  if ui_has_gum; then
    gum style --border rounded --padding "0 2" --bold "$1"
  else
    echo; echo "== $1 =="
  fi
}
