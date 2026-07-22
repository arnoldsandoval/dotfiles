# vault.sh — arnievault sync bridge + VM read-only clone.
# The personal Mac is the vault's git hub (see vault-automation.md in the
# vault): pull merged robot PRs in, checkpoint whatever Obsidian Sync
# delivered, push so the cloud routines see fresh data. The VM only pulls.
# shellcheck shell=bash

VAULT_REMOTE="https://github.com/arnoldsandoval/arnievault"

vault_dir() {
  case "$(profile_get)" in
    mac-personal) echo "$HOME/Documents/arnievault" ;;
    vm)           echo "$HOME/code/arnievault" ;;
    *)            echo "" ;;   # work mac: Obsidian Sync only, no git
  esac
}

# vault_sync [--force] — the hub bridge (mac-personal). Throttled to 1h unless
# forced. Never prompts; records vault_* keys in the status file for doctor.
vault_sync() {
  local dir; dir=$(vault_dir)
  [[ -n $dir && -d $dir/.git ]] || return 0
  local now ts; now=$(date +%s); ts=$(status_get vault_ts)
  [[ ${1:-} != --force && -n $ts && $((now - ts)) -lt 3600 ]] && return 0
  status_set vault_ts "$now"

  if ! GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only -q 2>/dev/null; then
    status_set vault_err "pull failed (diverged or offline) $now"
    return 0
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

# vault_settle — called from dotfiles sync on any profile with a vault role:
# hub → full bridge cycle (forced); vm → clone if missing, else ff pull.
vault_settle() {
  local dir; dir=$(vault_dir)
  [[ -n $dir ]] || return 0
  case "$(profile_get)" in
    mac-personal) vault_sync --force ;;
    vm)
      if [[ ! -d $dir/.git ]]; then
        if has_github_auth; then
          log "cloning arnievault (read-only touchpoint)"
          git clone -q "$VAULT_REMOTE" "$dir" 2>/dev/null || warn "vault clone failed"
        else
          warn "vault clone skipped: no GitHub auth"
        fi
      else
        GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only -q 2>/dev/null || true
      fi ;;
  esac
  return 0
}

# check_vault — doctor section. Read-only; no fetch (uses last-known refs).
check_vault() {
  local dir bad=0 age ahead behind err
  dir=$(vault_dir)
  [[ -n $dir ]] || return 0
  if [[ ! -d $dir/.git ]]; then
    case "$(profile_get)" in
      mac-personal) err "vault: $dir is not a git repo (hub bridge inactive)"; return 1 ;;
      vm)           warn "vault: not cloned yet (dotfiles sync will clone it)"; return 0 ;;
    esac
  fi
  err=$(status_get vault_err)
  [[ -n $err ]] && warn "vault: last sync problem: $err"
  if [[ $(profile_get) == mac-personal ]]; then
    age=$(( $(date +%s) - $(git -C "$dir" log -1 --format=%ct 2>/dev/null || echo 0) ))
    (( age > 10800 )) && { warn "vault: last commit $((age/3600))h ago — sync bridge silent (open a terminal more, or check vault_err)"; bad=$((bad+1)); }
    ahead=$(git -C "$dir" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    (( ahead > 0 )) && warn "vault: $ahead unpushed commit(s) — cloud routines see stale data"
  fi
  behind=$(git -C "$dir" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  (( behind > 0 )) && warn "vault: $behind commit(s) behind — merged robot PRs not yet local"
  return $((bad > 0))
}