# profile.sh — machine profile: chosen once, saved to state. Sourced after core.sh.
# shellcheck shell=bash

PROFILES=(mac-personal mac-work vm)

profile_get() { [[ -f $PROFILE_FILE ]] && cat "$PROFILE_FILE" || true; }

profile_set() {
  local p=$1
  profile_valid "$p" || die "unknown profile: $p (want: ${PROFILES[*]})"
  ensure_state_dir
  printf '%s\n' "$p" >"$PROFILE_FILE"
  ok "profile saved: $p"
}

profile_valid() {
  local p=$1 q
  for q in "${PROFILES[@]}"; do [[ $q == "$p" ]] && return 0; done
  return 1
}

# Prompt (gum if available, plain read otherwise) and save. Used by bootstrap.
profile_prompt() {
  local choice
  if has gum; then
    choice=$(gum choose --header "What is this machine?" "${PROFILES[@]}")
  else
    echo "What is this machine?"
    local i=1; for p in "${PROFILES[@]}"; do echo "  $i) $p"; i=$((i+1)); done
    printf "> "
    read -r choice
    [[ $choice =~ ^[0-9]+$ ]] && choice=${PROFILES[$((choice-1))]:-}
  fi
  [[ -n $choice ]] || die "no profile chosen"
  profile_set "$choice"
}

# Ensure a profile exists; prompt if missing (or use $1 override).
profile_ensure() {
  local override=${1:-}
  if [[ -n $override ]]; then profile_set "$override"; return; fi
  [[ -n $(profile_get) ]] || profile_prompt
}
