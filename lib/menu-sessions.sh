# menu-sessions.sh — dual-agent session picker (absorbs claude-menu).
# Projects under ~/code become persistent per-project tmux sessions:
#   cc-<name>  claude    (claude --resume <newest session id> --remote-control)
#   cp-<name>  copilot   (copilot resumed in the project dir)
# `tmux new-session -A` = attach-or-create, so reconnecting never duplicates.
# shellcheck shell=bash

CODE_DIR="$HOME/code"
CLAUDE_PROJ="$HOME/.claude/projects"

_encode_claude_dir() { printf '%s' "$1" | sed 's#[/.]#-#g'; }

# mtime, portable: GNU stat (-c) on linux, BSD stat (-f) on macOS
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

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
  local d pdir newest sid mt all
  for d in "$CODE_DIR"/*/; do
    d="${d%/}"
    [[ -d $d ]] || continue
    sid=""; mt=$(_mtime "$d")
    pdir="$CLAUDE_PROJ/$(_encode_claude_dir "$d")"
    if [[ -d $pdir ]]; then
      # capture then take the first line in pure bash: `ls -t | head -1`
      # SIGPIPEs ls on big session dirs, and under pipefail that killed the
      # whole discovery loop (projects silently missing from the menu)
      all=$(ls -t "$pdir"/*.jsonl 2>/dev/null) || all=""
      newest=${all%%$'\n'*}
      if [[ -n $newest ]]; then
        sid=$(basename "$newest" .jsonl)
        mt=$(_mtime "$newest")
      fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$mt" "$(basename "$d")" "$d" "$sid"
  done | sort -rn
}

# _agent_alive PREFIX NAME -> 0 iff the expected agent process is running
# beneath (or as) the pane's process tree. pane_current_command is NOT enough:
# copilot's wrapper (`a || b; exec $SHELL`) keeps the shell as the surface
# process while the agent runs as its child — which both hid the ● and made
# the husk-respawn think a LIVE copilot was dead.
_agent_alive() {
  local prefix=$1 name=$2 want root psout members pid ppid comm base grew w
  case $prefix in
    cc) want="claude" ;;
    cp) want="copilot github-copilot-cli" ;;
    *)  return 1 ;;
  esac
  root=$(tmux list-panes -t "=$prefix-$name" -F '#{pane_pid}' 2>/dev/null) || return 1
  root=${root%%$'\n'*}
  [[ -n $root ]] || return 1
  psout=$(ps -ax -o pid= -o ppid= -o comm= 2>/dev/null) || return 1
  # collect the pane's full descendant set (loop to fixpoint; ps order varies)
  members=" $root "
  grew=1
  while (( grew )); do
    grew=0
    while read -r pid ppid comm; do
      [[ $members == *" $ppid "* && $members != *" $pid "* ]] || continue
      members+="$pid "
      grew=1
    done <<< "$psout"
  done
  # match ONLY the expected agent names — unrelated children never count
  while read -r pid ppid comm; do
    [[ $members == *" $pid "* ]] || continue
    base=${comm##*/}
    for w in $want; do [[ $base == "$w" ]] && return 0; done
  done <<< "$psout"
  return 1
}

_session_mark() { # _session_mark PREFIX NAME -> "●" only if the AGENT is alive
  _agent_alive "$1" "$2" && echo "●" || echo " "
}

# _enter TARGET DIR CMD — put the user in the tmux session (never returns).
# Outside tmux: attach-or-create. Inside tmux: create detached if needed and
# SWITCH this client (new-session -A would trip the nesting guard).
_enter() {
  local target=$1 dir=$2 cmd=$3 pane
  ui_alt_off   # leaving the menu app for tmux — restore the real screen first
  if tmux has-session -t "=$target" 2>/dev/null; then
    # true husk = agent dead by process-tree check AND surface is a bare shell
    # (never respawn over a live agent hidden under its wrapper, nor over
    # something the user left running in the husk, e.g. vim)
    if ! _agent_alive "${target%%-*}" "${target#*-}"; then
      pane=$(tmux list-panes -t "=$target" -F '#{pane_current_command}' 2>/dev/null)
      case ${pane:-} in
        zsh|bash|sh)
          tmux respawn-pane -k -t "=$target:" -c "$dir" \
            "printf '\\033[2J\\033[H⏳ resuming %s…\\n' '$target'; $cmd" ;;
      esac
    fi
  elif [[ -n ${TMUX:-} ]]; then
    tmux new-session -d -s "$target" -c "$dir" "$cmd"
  fi
  if [[ -n ${TMUX:-} ]]; then
    exec tmux switch-client -t "=$target"   # nesting-safe
  else
    exec tmux new-session -A -s "$target" -c "$dir" "$cmd"
  fi
}

# _newest_sid DIR -> newest claude session id for the project, or nothing
_newest_sid() {
  local pdir all newest
  pdir="$CLAUDE_PROJ/$(_encode_claude_dir "$1")"
  [[ -d $pdir ]] || return 0
  all=$(ls -t "$pdir"/*.jsonl 2>/dev/null) || all=""
  newest=${all%%$'\n'*}
  [[ -n $newest ]] && basename "$newest" .jsonl
  return 0
}

# _agent_cmd AGENT NAME SID -> print the session's launch/resume command
_agent_cmd() {
  local agent=$1 name=$2 sid=$3 bin
  case $agent in
    claude)
      bin=$(command -v claude || echo "$HOME/.local/bin/claude")
      if [[ -n $sid ]]; then printf '%s' "$bin --resume $sid --remote-control $name; exec \$SHELL"
      else printf '%s' "$bin --remote-control $name; exec \$SHELL"; fi ;;
    copilot)
      bin=$(command -v copilot || command -v github-copilot-cli || true)
      [[ -n $bin ]] || return 1
      # Name-based resume: sessions are NAMED after the project (--name) and
      # resumed by that name — self-bootstrapping, no dependency on copilot
      # storage internals (session-store.db ids are NOT resumable).
      printf '%s' "$bin --resume=$name 2>/dev/null || $bin --name=$name; exec \$SHELL" ;;
  esac
}

# _launch AGENT NAME DIR SID — build the agent command and enter its session
_launch() {
  local agent=$1 name=$2 dir=$3 sid=$4 cmd pfx=cc
  [[ $agent == copilot ]] && pfx=cp
  cmd=$(_agent_cmd "$agent" "$name" "$sid") || die "copilot CLI not installed"
  _enter "$pfx-$name" "$dir" "$cmd"
}

# sessions_restart [project] — respawn cc-*/cp-* sessions into their resume
# commands (e.g. to pick up new hook config); optional arg limits to one
# project. One confirm covers them all; panes whose foreground is neither
# the agent nor a bare shell (vim, tails, …) are skipped and reported,
# never killed.
sessions_restart() {
  local only=${1:-} all s prefix name pane dir targets=() skipped=() agent sid cmd
  all=$(tmux list-sessions -F '#{session_name}' 2>/dev/null) || { log "no tmux server running — nothing to restart"; return 0; }
  for s in $all; do
    case $s in cc-*|cp-*) ;; *) continue ;; esac
    if [[ -n $only ]]; then
      case $s in "$only"|"cc-$only"|"cp-$only") ;; *) continue ;; esac
    fi
    prefix=${s%%-*}; name=${s#*-}
    if _agent_alive "$prefix" "$name"; then
      targets+=("$s")
    else
      pane=$(tmux list-panes -t "=$s" -F '#{pane_current_command}' 2>/dev/null)
      pane=${pane%%$'\n'*}
      case ${pane:-} in
        zsh|bash|sh) targets+=("$s") ;;
        *)           skipped+=("$s:$pane") ;;
      esac
    fi
  done
  [[ ${#skipped[@]} -gt 0 ]] && warn "skipped (foreground program, not an agent): ${skipped[*]}"
  [[ ${#targets[@]} -gt 0 ]] || { log "no agent sessions to restart"; return 0; }
  ui_confirm "restart ${#targets[@]} session(s): ${targets[*]}? in-flight agent work is interrupted (conversations resume from history)" || return 0
  for s in "${targets[@]}"; do
    prefix=${s%%-*}; name=${s#*-}
    agent=claude; [[ $prefix == cp ]] && agent=copilot
    dir="$CODE_DIR/$name"
    [[ -d $dir ]] || dir=$(tmux display-message -t "=$s:" -p '#{pane_current_path}' 2>/dev/null)
    [[ -d ${dir:-} ]] || { warn "$s: no project dir — skipped"; continue; }
    sid=""; [[ $agent == claude ]] && sid=$(_newest_sid "$dir")
    cmd=$(_agent_cmd "$agent" "$name" "$sid") || { warn "$s: agent CLI not installed — skipped"; continue; }
    tmux respawn-pane -k -t "=$s:" -c "$dir" \
      "printf '\\033[2J\\033[H⏳ restarting %s…\\n' '$s'; $cmd"
    ok "restarted $s"
  done
}

sessions_menu() {
  local ctx=()   # --nested when opened from the hub: esc = back, not shell
  [[ ${1:-} == --nested ]] && ctx=(--nested)
  local rows=() names=() dirs=() sids=() now line mt name dir sid
  now=$(date +%s)
  while IFS=$'\t' read -r mt name dir sid; do
    [[ -n $name ]] || continue
    names+=("$name"); dirs+=("$dir"); sids+=("$sid")
    rows+=("$(printf '%s%s %-26s %s' "$(_session_mark cc "$name")" "$(_session_mark cp "$name")" "$name" "$(_ago $((now - mt)))")")
  done < <(discover_projects)
  [[ ${#names[@]} -gt 0 ]] || { warn "no projects under $CODE_DIR"; return 0; }

  local choice idx=-1 i
  choice=$(ui_choose "${ctx[@]}" "Sessions  (●=claude ●=copilot running)" "${rows[@]}") || true
  [[ -n $choice ]] || return 0
  for i in "${!rows[@]}"; do [[ ${rows[$i]} == "$choice" ]] && idx=$i; done
  [[ $idx -ge 0 ]] || return 0

  # agent choice: only offer what's installed
  local agents=()
  has claude && agents+=(claude)
  { has copilot || has github-copilot-cli; } && agents+=(copilot)
  [[ ${#agents[@]} -gt 0 ]] || die "no agent CLI installed (claude/copilot)"
  local agent=${agents[0]}
  [[ ${#agents[@]} -gt 1 ]] && agent=$(ui_choose --nested "Agent for ${names[$idx]}" "${agents[@]}")
  [[ -n $agent ]] || return 0

  _launch "$agent" "${names[$idx]}" "${dirs[$idx]}" "${sids[$idx]}"
}
