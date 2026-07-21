# doctor.sh — read-only drift report. Exit nonzero on any finding.
# shellcheck shell=bash

run_doctor() {
  local bad=0 profile behind ts err_
  profile=$(profile_get)

  ui_header "dotfiles doctor"
  echo "  platform: $OS/$DISTRO ($PKG_MGR)   profile: ${profile:-UNSET}"
  [[ -n $profile ]] || { err "no profile set — run 'dotfiles bootstrap'"; bad=$((bad+1)); }

  log "links"
  check_links || bad=$((bad+1))

  log "packages"
  check_packages || bad=$((bad+1))

  log "skills"
  check_skills || bad=$((bad+1))

  log "git"
  behind=$(status_get behind); ts=$(status_get fetch_ts); err_=$(status_get fetch_err)
  [[ -n $err_ ]] && { warn "last fetch failed: $err_"; }
  [[ -n $behind && $behind -gt 0 ]] && { warn "behind origin by $behind commit(s) — 'dotfiles sync'"; bad=$((bad+1)); }
  [[ -n $(git -C "$DOTFILES" status --porcelain 2>/dev/null) ]] && warn "working tree dirty (commit when intentional)"
  if [[ -n $ts ]]; then
    local age=$(( $(date +%s) - ts ))
    (( age > 86400 )) && warn "last fetch was $((age/3600))h ago"
  fi

  log "auth"
  if has_github_auth; then ok "GitHub auth available (tier 2 unlocked)"; else warn "no GitHub auth (tier 2 will skip)"; fi

  # stray legacy config that should have been retired
  [[ -f $HOME/.gitconfig && ! -L $HOME/.gitconfig ]] && warn "stray ~/.gitconfig (config now lives at ~/.config/git/config)"

  echo
  if [[ $bad -eq 0 ]]; then ok "all clear"; else err "$bad problem group(s) found"; fi
  return $((bad > 0))
}
