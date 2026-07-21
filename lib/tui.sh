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
  # gum-styled, gum-free: pure ANSI, so nothing probes the terminal with
  # escape queries (gum's ESC]11;? / ESC[6n replies arrive on stdin and can
  # swallow type-ahead on the login path). Rounded box, magenta accents.
  local c i opt w=0 hint
  hint="1-$# · enter = shell"
  (( ${#header} > w )) && w=${#header}
  (( ${#hint} + 2 > w )) && w=$(( ${#hint} + 2 ))
  for opt in "$@"; do (( ${#opt} + 3 > w )) && w=$(( ${#opt} + 3 )); done
  _hline() { local n=$1 s=""; while (( n-- > 0 )); do s+="─"; done; printf '%s' "$s"; }
  {
    printf '%s╭─ %s%s%s ' "$C_MAG" "$C_BLD$C_OFF$C_BLD" "$header" "$C_OFF$C_MAG"
    _hline $(( w - ${#header} + 1 )); printf '╮%s\n' "$C_OFF"
    i=1
    local pad
    for opt in "$@"; do
      # pad by character count, not printf's byte-width (● is multibyte)
      pad=$(( w - 1 - ${#opt} )); (( pad < 0 )) && pad=0
      printf '%s│%s  %s%d)%s %s%*s%s│%s\n' \
        "$C_MAG" "$C_OFF" "$C_MAG$C_BLD" "$i" "$C_OFF" "$opt" "$pad" "" "$C_MAG" "$C_OFF"
      i=$((i+1))
    done
    printf '%s╰' "$C_MAG"; _hline 1; printf ' %s%s%s ' "$C_DIM" "$hint" "$C_OFF$C_MAG"
    _hline $(( w - ${#hint} + 1 )); printf '╯%s\n' "$C_OFF"
  } >&2
  while true; do
    printf '%s❯%s ' "$C_MAG$C_BLD" "$C_OFF" >&2
    read -r c || { echo >&2; return 0; }
    [[ -z $c || $c == q ]] && return 0
    if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= $# )); then
      eval "echo \"\${$c}\""; return 0
    fi
    printf '  %s%s isn%st an option%s\n' "$C_YLW" "'$c'" "'" "$C_OFF" >&2
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
