# sync.sh — fetch/apply split. Fetch is always safe; apply is profile-gated.
# shellcheck shell=bash

# Quiet fetch; records behind-count + stamp in status file. Never prompts.
do_fetch() {
  ensure_state_dir
  if GIT_TERMINAL_PROMPT=0 git -C "$DOTFILES" fetch --quiet 2>/dev/null; then
    local behind
    behind=$(git -C "$DOTFILES" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    status_set behind "$behind"
    status_set fetch_ts "$(date +%s)"
    status_set fetch_err ""
  else
    status_set fetch_err "fetch failed at $(date +%s)"
  fi
}

# Fire-and-forget fetch if the last one is older than 1h. Prompt-path safe.
maybe_fetch_async() {
  local ts now
  ts=$(status_get fetch_ts); now=$(date +%s)
  [[ -n $ts && $((now - ts)) -lt 3600 ]] && return 0
  ( do_fetch >/dev/null 2>&1 & ) 2>/dev/null
}

# do_sync [--auto]: ff-only pull + relink + skills + one summary line.
# --auto (login hook): silent when nothing to do; applies only on vm profile.
do_sync() {
  local auto=${1:-}
  local dirty behind profile; profile=$(profile_get)
  dirty=$(git -C "$DOTFILES" status --porcelain)
  do_fetch
  behind=$(status_get behind); behind=${behind:-0}
  if [[ $auto == --auto ]]; then
    [[ $profile == vm ]] || return 0            # workstations never auto-apply
    [[ $behind -gt 0 && -z $dirty ]] || return 0
  fi
  if [[ $behind -eq 0 ]]; then [[ $auto == --auto ]] || ok "up to date"; return 0; fi
  if [[ -n $dirty ]]; then warn "dotfiles tree is dirty — not pulling (commit/stash first)"; return 1; fi
  if git -C "$DOTFILES" merge --ff-only @{u} >/dev/null 2>&1; then
    apply_links --quiet || true
    status_set behind 0
    ok "dotfiles synced: pulled $behind commit(s) + relinked"
  else
    warn "cannot fast-forward (diverged) — resolve manually in $DOTFILES"
    return 1
  fi
}

# do_save [message] — the "I tweaked something on this machine" verb:
# commit everything + push, so other machines pick it up on their next fetch.
# (Configs are symlinks into the repo, so editing ~/.zshrc edits the repo.)
do_save() {
  local msg=${1:-"chore: update from $(hostname -s 2>/dev/null || hostname)"}
  if [[ -z $(git -C "$DOTFILES" status --porcelain) ]]; then ok "nothing to save — tree is clean"; return 0; fi
  git -C "$DOTFILES" add -A
  git -C "$DOTFILES" status --short
  if ! ui_confirm "commit + push the above as '$msg'?"; then warn "aborted"; return 1; fi
  git -C "$DOTFILES" commit -qm "$msg"
  if git -C "$DOTFILES" push -q 2>/dev/null; then
    ok "saved + pushed — other machines will see it on their next fetch"
  else
    warn "committed but push failed (offline?) — push manually later"
  fi
}

# Nudge line for workstation shells (empty when nothing to say).
sync_nudge() {
  local behind; behind=$(status_get behind)
  [[ -n $behind && $behind -gt 0 ]] && echo "dotfiles ⇣$behind — run 'dotfiles sync'"
  return 0
}
