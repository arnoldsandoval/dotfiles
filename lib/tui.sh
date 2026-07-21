# tui.sh — gum-enhanced UI primitives with plain-bash fallbacks.
# Everything here must work with gum ABSENT (Tier-0 guarantee).
# shellcheck shell=bash

# NOTE: check stdin+stderr, not stdout — ui_choose is called inside $(...)
# where stdout is a pipe; gum draws its UI on the tty and prints to stdout.
ui_has_gum() { has gum && [[ -t 0 && -t 2 ]]; }

# _ui_read_num MAX -> prints chosen number; returns 1 on cancel (esc/q/EOF).
# Raw key loop: digits build a number and AUTO-CONFIRM once no larger option
# could start with the buffer (single keypress for lists <=9). Enter confirms
# an ambiguous buffer, backspace edits, arrows and stray letters (muscle-
# memory type-ahead like 'dev') are ignored.
_ui_read_num() {
  local n=$1 buf="" k rest
  while true; do
    printf '\r\033[K%s❯%s %s' "$C_MAG$C_BLD" "$C_OFF" "$buf" >&2
    IFS= read -rsn1 k || { echo >&2; return 1; }
    case $k in
      $'\e')
        IFS= read -rsn1 -t 0.02 rest || true
        if [[ $rest == '[' || $rest == O ]]; then
          # swallow the rest of the CSI/SS3 sequence (ends at a letter or ~)
          while IFS= read -rsn1 -t 0.02 rest; do
            [[ $rest == [A-Za-z~] ]] && break
          done
        else
          echo >&2; return 1                        # bare esc (even typed rapidly)
        fi ;;
      q) echo >&2; return 1 ;;
      "")  # enter: confirm buffer if valid, else clear it
        if [[ -n $buf ]] && (( 10#$buf >= 1 && 10#$buf <= n )); then
          echo >&2; printf '%s' $((10#$buf)); return 0
        fi
        buf="" ;;
      $'\x7f') buf=${buf%?} ;;
      [0-9])
        buf+=$k
        if (( 10#$buf > n )); then buf=""; continue; fi
        if (( 10#$buf >= 1 && 10#$buf * 10 > n )); then
          echo >&2; printf '%s' $((10#$buf)); return 0
        fi ;;
      *) : ;;
    esac
  done
}

# ui_choose [--nested] HEADER OPTION... -> prints chosen option (empty on cancel)
# Single-keypress numbered selection; esc = shell at top level, back when
# --nested. gum stays out of this path (terminal probes; see note below).
ui_choose() {
  local esc_hint="esc = shell"
  [[ $1 == --nested ]] && { esc_hint="esc = back"; shift; }
  local header=$1; shift
  # gum-styled, gum-free: pure ANSI, so nothing probes the terminal with
  # escape queries (gum's ESC]11;? / ESC[6n replies arrive on stdin and can
  # swallow type-ahead on the login path). Rounded box, magenta accents.
  local c i opt w=0 hint
  hint="1-$# · $esc_hint"
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
  c=$(_ui_read_num $#) || return 0
  eval "echo \"\${$c}\""
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

# ui_header TEXT — pure ansi (gum style probes the terminal; see ui_choose)
ui_header() {
  echo
  printf '%s── %s%s%s ──%s\n' "$C_MAG" "$C_BLD" "$1" "$C_OFF$C_MAG" "$C_OFF"
}
