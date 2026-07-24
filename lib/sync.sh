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
  if [[ $behind -eq 0 ]]; then
    # still settle: a manual git pull leaves new links.d entries unapplied
    # and new manifest skills uninstalled
    apply_links --quiet || true
    vault_settle
    if [[ $auto != --auto ]]; then
      _run_installers
      has npx && skills_install_manifest
      ok "up to date (links + skills + vault settled)"
    fi
    return 0
  fi
  if [[ -n $dirty ]]; then warn "dotfiles tree is dirty — not pulling (commit/stash first)"; return 1; fi
  if git -C "$DOTFILES" merge --ff-only @{u} >/dev/null 2>&1; then
    apply_links --quiet || true
    status_set behind 0
    ok "dotfiles synced: pulled $behind commit(s) + relinked"
    # manual sync also settles skills: install anything newly declared in the
    # manifest on another machine, then refresh installed ones from upstream
    # (skipped in --auto/login mode: no network storms on ssh)
    if [[ $auto != --auto ]] && has npx; then
      skills_install_manifest
      log "updating installed skills from upstream"
      (cd "$HOME" && npx --yes skills update -g -y </dev/null) 2>/dev/null || warn "skills update failed (non-fatal)"
    fi
    # settle user-space installers too (idempotent, guarded): a pulled
    # installers.d addition otherwise waits for the next full bootstrap
    [[ $auto != --auto ]] && _run_installers
    vault_settle
  else
    warn "cannot fast-forward (diverged) — resolve manually in $DOTFILES"
    return 1
  fi
}

# Ask the machine's agent (claude, else copilot) to write a one-line
# conventional commit message from the diff. Prints it; fails silently on
# no agent / timeout / malformed reply — caller falls back to the default.
_gen_commit_msg() {
  local agent="" out msg prompt
  if has claude; then agent="claude -p"
  elif has copilot; then agent="copilot -p"
  else return 1; fi
  prompt="Write a one-line conventional commit message (type: feat/fix/chore/docs/refactor, lowercase subject, max 65 chars, no quotes or backticks) for this dotfiles change. Reply with ONLY the message line, nothing else.

$(git -C "$DOTFILES" status --short; git -C "$DOTFILES" diff HEAD | head -300)"
  if ui_has_gum; then
    out=$(gum spin --show-output --title "✎ ${agent%% *} is writing a commit message…" -- \
          timeout 45 $agent "$prompt" 2>/dev/null) || return 1
  else
    log "asking ${agent%% *} for a commit message…" >&2
    out=$(timeout 45 $agent "$prompt" 2>/dev/null) || return 1
  fi
  # capture first, then filter — a -m1 grep on a live pipe would SIGPIPE
  msg=$(printf '%s\n' "$out" | grep -m1 -E '^[a-z]+(\([a-z0-9./-]+\))?: .{1,70}$') || return 1
  printf '%s' "$msg"
}

# do_save [message] — the "I tweaked something on this machine" verb:
# commit everything + push, so other machines pick it up on their next fetch.
# (Configs are symlinks into the repo, so editing ~/.zshrc edits the repo.)
do_save() {
  local msg=${1:-}
  if [[ -z $(git -C "$DOTFILES" status --porcelain) ]]; then ok "nothing to save — tree is clean"; return 0; fi
  if [[ -z $msg ]]; then
    msg=$(_gen_commit_msg) || msg="chore: update from $(hostname -s 2>/dev/null || hostname)"
  fi
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

# (the shell-startup nudge lives as a fast path in bin/dotfiles — no lib load)
