# menu-sessions.sh — dual-agent session picker (absorbs claude-menu).
# Projects under ~/code become persistent per-project tmux sessions:
#   cc-<name>  claude    (claude --resume <newest session id> --remote-control)
#   cp-<name>  copilot   (copilot resumed in the project dir)
# `tmux new-session -A` = attach-or-create, so reconnecting never duplicates.
# shellcheck shell=bash

CODE_DIR="$HOME/code"
CLAUDE_PROJ="$HOME/.claude/projects"

_encode_claude_dir() { printf '%s' "$1" | sed 's#[/.]#-#g'; }

_ago() {
  local s=$1
  if   (( s < 60 ));    then echo "just now"
  elif (( s < 3600 ));  then echo "$((s/60))m ago"
  elif (( s < 86400 )); then echo "$((s/3600))h ago"
  else                       echo "$((s/86400))d ago"
  fi
}

# discover_projects -> lines: "mtime<TAB>name<TAB>dir<TAB>claude_session_id"
# (claude_session_id empty when the project has no Claude history)
discover_projects() {
  local d pdir newest sid mt
  for d in "$CODE_DIR"/*/; do
    d="${d%/}"
    [[ -d $d ]] || continue
    sid=""; mt=$(stat -c %Y "$d" 2>/dev/null || echo 0)
    pdir="$CLAUDE_PROJ/$(_encode_claude_dir "$d")"
    if [[ -d $pdir ]]; then
      newest=$(ls -t "$pdir"/*.jsonl 2>/dev/null | head -1)
      if [[ -n $newest ]]; then
        sid=$(basename "$newest" .jsonl)
        mt=$(stat -c %Y "$newest")
      fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$mt" "$(basename "$d")" "$d" "$sid"
  done | sort -rn
}

_session_mark() { # _session_mark PREFIX NAME -> "●" if tmux session exists
  tmux has-session -t "=$1-$2" 2>/dev/null && echo "●" || echo " "
}

# _launch AGENT NAME DIR SID — exec into the tmux session (never returns)
_launch() {
  local agent=$1 name=$2 dir=$3 sid=$4 cmd
  case $agent in
    claude)
      local bin; bin=$(command -v claude || echo "$HOME/.local/bin/claude")
      if [[ -n $sid ]]; then cmd="$bin --resume $sid --remote-control $name"
      else cmd="$bin --remote-control $name"; fi
      exec tmux new-session -A -s "cc-$name" -c "$dir" "$cmd; exec \$SHELL" ;;
    copilot)
      local bin; bin=$(command -v copilot || command -v github-copilot-cli || true)
      [[ -n $bin ]] || die "copilot CLI not installed"
      # NOTE: resume flags verified per Copilot CLI version; --resume falls back to fresh
      exec tmux new-session -A -s "cp-$name" -c "$dir" "$bin --resume 2>/dev/null || $bin; exec \$SHELL" ;;
  esac
}

sessions_menu() {
  local rows=() names=() dirs=() sids=() now line mt name dir sid
  now=$(date +%s)
  while IFS=$'\t' read -r mt name dir sid; do
    [[ -n $name ]] || continue
    names+=("$name"); dirs+=("$dir"); sids+=("$sid")
    rows+=("$(printf '%s%s %-26s %s' "$(_session_mark cc "$name")" "$(_session_mark cp "$name")" "$name" "$(_ago $((now - mt)))")")
  done < <(discover_projects)
  [[ ${#names[@]} -gt 0 ]] || { warn "no projects under $CODE_DIR"; return 0; }

  local choice idx=-1 i
  choice=$(ui_choose "Sessions  (●=claude ●=copilot running)" "${rows[@]}") || true
  [[ -n $choice ]] || return 0
  for i in "${!rows[@]}"; do [[ ${rows[$i]} == "$choice" ]] && idx=$i; done
  [[ $idx -ge 0 ]] || return 0

  # agent choice: only offer what's installed
  local agents=()
  has claude && agents+=(claude)
  { has copilot || has github-copilot-cli; } && agents+=(copilot)
  [[ ${#agents[@]} -gt 0 ]] || die "no agent CLI installed (claude/copilot)"
  local agent=${agents[0]}
  [[ ${#agents[@]} -gt 1 ]] && agent=$(ui_choose "Agent for ${names[$idx]}" "${agents[@]}")
  [[ -n $agent ]] || return 0

  _launch "$agent" "${names[$idx]}" "${dirs[$idx]}" "${sids[$idx]}"
}
