# vault.sh — arnievault roles: recorder (single git writer), readers, and
# sync-devices. See config/vault.conf (role declaration) and the vault's own
# vault-automation.md (architecture + governance).
# shellcheck shell=bash

VAULT_REMOTE="https://github.com/arnoldsandoval/arnievault"

vault_conf() { sed -n "s/^$1=//p" "$DOTFILES/config/vault.conf" 2>/dev/null | head -1; }

# vault_role -> recorder | reader | sync-device | none
# The recorder is whichever machine vault.conf names (any platform — a mac
# can hold the role as transitional fallback). Otherwise: VMs read via git,
# macs are Obsidian Sync devices.
vault_role() {
  local rec; rec=$(vault_conf recorder)
  if [[ -n $rec && $(hostname -s 2>/dev/null || hostname) == "$rec" ]]; then
    echo recorder; return
  fi
  case "$(profile_get)" in
    vm)                        echo reader ;;
    mac-personal|mac-work)     echo sync-device ;;
    *)                         echo none ;;
  esac
}

# The agent-facing local copy (reader clone on VMs, Sync folder on macs).
vault_dir() {
  case "$(profile_get)" in
    mac-personal|mac-work) echo "$HOME/Documents/arnievault" ;;
    vm)                    echo "$HOME/code/arnievault" ;;
    *)                     echo "" ;;
  esac
}

# vault_sync [--force] — mac-recorder fallback cycle (pull, checkpoint,
# push on ~/Documents/arnievault). Inert unless this mac IS the recorder:
# on the normal topology the linux recorder's systemd timer does this job
# via bin/vault-recorder instead.
vault_sync() {
  [[ $(vault_role) == recorder && $OS == darwin ]] || return 0
  local dir; dir=$(vault_dir)
  [[ -d $dir/.git ]] || return 0
  local now ts; now=$(date +%s); ts=$(status_get vault_ts)
  [[ ${1:-} != --force && -n $ts && $((now - ts)) -lt 3600 ]] && return 0
  status_set vault_ts "$now"
  if ! GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only -q 2>/dev/null; then
    status_set vault_err "pull failed (diverged or offline) $now"; return 0
  fi
  if [[ -n $(git -C "$dir" status --porcelain) ]]; then
    git -C "$dir" add -A
    git -C "$dir" commit -qm "vault checkpoint: $(hostname -s 2>/dev/null || hostname) $(date +%F-%H%M)" || true
  fi
  if GIT_TERMINAL_PROMPT=0 git -C "$dir" push -q 2>/dev/null; then
    status_set vault_err ""
  else
    status_set vault_err "push failed $now"
  fi
  return 0
}

# vault_settle — from dotfiles sync. Readers (and the linux recorder, which
# also keeps a reader clone for agents) clone/pull; a mac-recorder runs its
# fallback cycle.
vault_settle() {
  local role; role=$(vault_role)
  if [[ $role == recorder && $OS == darwin ]]; then
    vault_sync --force
    return 0
  fi
  # readers, and the linux recorder's agent-facing reader clone
  if [[ $role == reader || $role == recorder ]]; then
    local dir; dir=$(vault_dir)
    [[ -n $dir ]] || return 0
    if [[ ! -d $dir/.git ]]; then
      if has_github_auth; then
        log "cloning arnievault (read-only touchpoint)"
        git clone -q "$VAULT_REMOTE" "$dir" 2>/dev/null || warn "vault clone failed"
      else
        warn "vault clone skipped: no GitHub auth"
      fi
    else
      GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only -q 2>/dev/null || true
    fi
  fi
  return 0
}

# vault_note TEXT — quick-capture into today's daily note.
# Macs: direct append into the Sync-owned folder (human-initiated edit).
# Linux recorder: append via the scoped sudo helper into /srv (runs as the
# obsidian user — agents' own shells still cannot write the vault).
# Other VMs: refuse; writes go via branch+PR.
vault_note() {
  local text=$*
  [[ -n $text ]] || { warn "usage: dotfiles note <text>"; return 1; }
  local macdir; macdir=$(vault_dir)
  if [[ $OS == darwin && -d $macdir ]]; then
    local today file; today=$(date +%F); file="$macdir/$today.md"
    [[ -f $file ]] || printf '# %s\n' "$today" > "$file"
    printf -- '- %s — %s\n' "$(date +%H:%M)" "$text" >> "$file"
    ok "noted in $today.md"; return 0
  fi
  if [[ $(vault_role) == recorder && -x /usr/local/bin/vault-note-helper ]]; then
    if sudo -n -u obsidian /usr/local/bin/vault-note-helper "$text" 2>/dev/null; then
      ok "noted in $(date +%F).md (via recorder)"; return 0
    fi
    warn "note helper failed (sudoers rule missing? see vault-recorder-setup)"; return 1
  fi
  warn "quick-capture needs a mac or the recorder: vault writes elsewhere go via branch+PR (see vault-lookup skill)"
  return 1
}

# check_vault — doctor section, role-aware. Read-only; no fetch.
check_vault() {
  local role bad=0 dir age ahead behind err
  role=$(vault_role)
  case $role in
    recorder)
      if [[ $OS == darwin ]]; then
        dir=$(vault_dir)
        [[ -d $dir/.git ]] || { err "vault: mac holds recorder role but $dir is not a git repo"; return 1; }
        err=$(status_get vault_err); [[ -n $err ]] && warn "vault: last sync problem: $err"
        age=$(( $(date +%s) - $(git -C "$dir" log -1 --format=%ct 2>/dev/null || echo 0) ))
        (( age > 10800 )) && { warn "vault: recorder silent $((age/3600))h (open a terminal, or move the role to an always-on box)"; bad=$((bad+1)); }
      else
        local srv; srv=$(vault_conf recorder_path); srv=${srv:-/srv/arnievault}
        if [[ ! -d $srv/.git ]]; then
          warn "vault: recorder not provisioned — run: sudo bash \$DOTFILES/lib/vault-recorder-setup.sh"
          bad=$((bad+1))
        else
          systemctl is-active obsidian-sync.service >/dev/null 2>&1 \
            || { warn "vault: obsidian sync daemon not running (recorder blind to device edits)"; bad=$((bad+1)); }
          systemctl is-active vault-recorder.timer >/dev/null 2>&1 \
            || { warn "vault: recorder timer inactive (no git capture)"; bad=$((bad+1)); }
          age=$(( $(date +%s) - $(git -C "$srv" log -1 --format=%ct 2>/dev/null || echo 0) ))
          (( age > 1800 )) && warn "vault: recorder last commit $((age/60))m ago (quiet vault, or capture stuck)"
          behind=$(git -C "$srv" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
          (( behind > 0 )) && warn "vault: recorder $behind behind — merged robot PRs not yet pulled"
        fi
        # the recorder also keeps the agents' reader clone
        dir=$(vault_dir)
        [[ -n $dir && ! -d $dir/.git ]] && warn "vault: reader clone missing (dotfiles sync will clone it)"
      fi ;;
    reader)
      dir=$(vault_dir)
      if [[ ! -d $dir/.git ]]; then
        warn "vault: not cloned yet (dotfiles sync will clone it)"
      else
        behind=$(git -C "$dir" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
        (( behind > 0 )) && warn "vault: $behind commit(s) behind — run dotfiles sync"
      fi ;;
    sync-device)
      # Obsidian Sync owns the folder; the only check is CLI availability
      # so agents can drive the app (see obsidian-cli skill)
      if [[ -d /Applications/Obsidian.app ]] && ! has obsidian; then
        warn "vault: Obsidian CLI not registered — enable in Obsidian Settings → General (agents use it to read the vault)"
      fi ;;
  esac
  return $((bad > 0))
}