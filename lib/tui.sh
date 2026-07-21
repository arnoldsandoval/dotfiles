# tui.sh — gum-enhanced UI primitives with plain-bash fallbacks.
# Everything here must work with gum ABSENT (Tier-0 guarantee).
# shellcheck shell=bash

# NOTE: check stdin+stderr, not stdout — ui_choose is called inside $(...)
# where stdout is a pipe; gum draws its UI on the tty and prints to stdout.
ui_has_gum() { has gum && [[ -t 0 && -t 2 ]]; }

# ui_choose HEADER OPTION... -> prints chosen option (empty on cancel)
ui_choose() {
  local header=$1; shift
  if ui_has_gum; then
    gum choose --header "$header" "$@" || true
  else
    echo "$header" >&2
    local i=1 opt
    for opt in "$@"; do echo "  $i) $opt" >&2; i=$((i+1)); done
    # loop until a valid number; empty line or q = cancel (prints nothing).
    # never bail on stray input — type-ahead during shell startup lands here.
    local c
    while true; do
      printf "choice (1-%d, enter=skip): " "$#" >&2
      read -r c || { echo >&2; return 0; }
      [[ -z $c || $c == q ]] && return 0
      if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= $# )); then
        eval "echo \"\${$c}\""; return 0
      fi
      echo "  '$c' isn't an option" >&2
    done
  fi
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
