# pkg.sh — package layer: intent list resolved per platform, tier gating.
# shellcheck shell=bash

# packages/intent.txt: one tool name per line (the command we expect on PATH).
# packages/linux/{apt,tdnf}.map: "intent pkgname" lines, only where names differ.
# darwin uses Brewfiles instead of the intent list (brew bundle is better there).

_map_lookup() { # _map_lookup MAPFILE INTENT -> package name (default: intent)
  local f=$1 intent=$2 hit
  hit=$(awk -v i="$intent" '$1==i {print $2}' "$f" 2>/dev/null)
  echo "${hit:-$intent}"
}

_intents() { awk '!/^[[:space:]]*(#|$)/ {print $1}' "$DOTFILES/packages/intent.txt"; }

# missing_intents -> intents whose command is absent
missing_intents() {
  local i
  for i in $(_intents); do has "$i" || echo "$i"; done
}

# install_packages_tier1: public packages for this platform+profile
install_packages_tier1() {
  local profile; profile=$(profile_get)
  if [[ $OS == darwin ]]; then
    has brew || { warn "homebrew not installed — skipping brew packages (install from https://brew.sh then re-run)"; return 0; }
    # run bundles VISIBLY (no gum spin): it swallows brew errors whole —
    # a failed personal bundle once went completely unnoticed behind it
    local pf="$DOTFILES/packages/darwin/Brewfile.${profile#mac-}"   # personal|work
    _trust_declared_taps "$DOTFILES/packages/darwin/Brewfile.core" "$pf"
    log "brew bundle (core)"
    brew bundle --no-upgrade --file "$DOTFILES/packages/darwin/Brewfile.core" || warn "core bundle had failures (see above)"
    if [[ -f $pf ]]; then
      log "brew bundle (${profile#mac-})"
      brew bundle --no-upgrade --file "$pf" || warn "${profile#mac-} bundle had failures (see above)"
    fi
  else
    _install_linux_pkgs
  fi
  _run_installers
}

_install_linux_pkgs() {
  local mgr_missing=() i pkg map="$DOTFILES/packages/linux/$PKG_MGR.map"
  for i in $(missing_intents); do
    pkg=$(_map_lookup "$map" "$i")
    [[ $pkg == SKIP ]] && continue   # handled by installers.d instead
    mgr_missing+=("$pkg")
  done
  [[ ${#mgr_missing[@]} -eq 0 ]] && { ok "system packages: all present"; return 0; }
  case $PKG_MGR in
    apt)  _pkg_cmd=(sudo apt-get install -y "${mgr_missing[@]}") ;;
    tdnf) _pkg_cmd=(sudo tdnf install -y "${mgr_missing[@]}") ;;
    *) warn "no known package manager ($DISTRO); install manually: ${mgr_missing[*]}"; return 0 ;;
  esac
  if has_passive_sudo; then
    ui_spin "installing: ${mgr_missing[*]}" "${_pkg_cmd[@]}"
  elif [[ -t 0 ]] && ui_confirm "sudo needed to install: ${mgr_missing[*]} — try now?"; then
    "${_pkg_cmd[@]}" || warn "package install failed; continuing"
  else
    warn "no sudo — run this yourself later:"
    warn "  ${_pkg_cmd[*]}"
  fi
}

# Newer brew refuses formulae from untrusted third-party taps. A tap listed
# in our Brewfiles is declared intent, so trust those automatically (no-op on
# brew versions without the trust command, and on already-trusted taps).
_trust_declared_taps() {
  brew trust --help >/dev/null 2>&1 || return 0
  local f tap
  for f in "$@"; do
    [[ -f $f ]] || continue
    while IFS= read -r tap; do
      [[ -n $tap ]] || continue
      # visible on purpose: brew trust may prompt or refuse, and suppressing
      # that left taps silently untrusted on two machines
      brew trust "$tap" || warn "could not trust tap $tap (run 'brew trust $tap' manually)"
    done < <(sed -n "s/^tap '\([^']*\)'.*/\1/p" "$f")
  done
}

# Sudo-free fallbacks/user-space tools: every script in installers.d is
# idempotent (guards on command -v) and installs to ~/.local/bin.
_run_installers() {
  local s
  for s in "$DOTFILES"/packages/installers.d/*.sh; do
    [[ -f $s ]] || continue
    # shellcheck disable=SC1090
    bash "$s" || warn "installer failed: $(basename "$s")"
  done
}

# install_packages_tier2: private tap — skip loudly without auth, never block.
install_packages_tier2() {
  if ! has_github_auth; then
    warn "tier 2 SKIPPED: no GitHub auth. Run 'gh auth login' then 'dotfiles bootstrap --tier 2'."
    return 0
  fi
  if [[ $OS == darwin ]] && has brew; then
    _trust_declared_taps "$DOTFILES/packages/darwin/Brewfile.private"
    log "brew bundle (private)"
    brew bundle --no-upgrade --file "$DOTFILES/packages/darwin/Brewfile.private" || warn "private bundle had failures (see above)"
  else
    ok "tier 2: nothing to do on $DISTRO"
  fi
}

# check_packages: doctor-mode. Prints problems, returns nonzero if any.
check_packages() {
  local bad=0 i out pf profile
  if [[ $OS == darwin ]] && has brew; then
    profile=$(profile_get)
    for pf in Brewfile.core "Brewfile.${profile#mac-}"; do
      [[ -f $DOTFILES/packages/darwin/$pf ]] || continue
      # trust the exit code; show only the actionable lines (brew mixes in
      # unrelated warnings like circular-dependency notices). NO_UPGRADE:
      # doctor verifies presence, not freshness — outdated != missing
      if ! out=$(HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle check --verbose --file "$DOTFILES/packages/darwin/$pf" 2>&1); then
        err "missing from $pf:"
        printf '%s\n' "$out" | grep -E "needs to be installed|→" | sed 's/^/    /'
        bad=$((bad+1))
      fi
    done
    _check_brew_drift
  fi
  for i in $(missing_intents); do err "missing tool: $i"; bad=$((bad+1)); done
  return $((bad > 0))
}

# Combined manifest (core + profile + private) — cleanup MUST run against all
# of them together or one file's apps read as another's orphans.
_combined_brewfile() {
  local profile combined; profile=$(profile_get)
  combined=$(mktemp)
  cat "$DOTFILES/packages/darwin/Brewfile.core" \
      "$DOTFILES/packages/darwin/Brewfile.${profile#mac-}" \
      "$DOTFILES/packages/darwin/Brewfile.private" 2>/dev/null >"$combined"
  echo "$combined"
}

# Drift the other way: things installed by hand that no Brewfile declares.
# Informational (warn, not error) — the fix is 'add to a Brewfile, dotfiles save'.
_check_brew_drift() {
  local combined extras
  combined=$(_combined_brewfile)
  extras=$(brew bundle cleanup --file "$combined" 2>/dev/null | sed 's/^/    /')
  rm -f "$combined"
  [[ -n $extras ]] && { warn "installed but not in any Brewfile (add + 'dotfiles save', or uninstall):"; printf '%s\n' "$extras"; }
  return 0
}

# pkg_cleanup — remove everything no Brewfile declares (darwin only).
# Shows the would-remove list, then confirms before --force.
pkg_cleanup() {
  [[ $OS == darwin ]] || { warn "cleanup is brew-only (nothing to do on $DISTRO)"; return 0; }
  has brew || return 0
  local profile combined; profile=$(profile_get)
  # trust declared taps first — cleanup's final check loads every declared
  # formula and hard-fails on untrusted taps
  _trust_declared_taps "$DOTFILES/packages/darwin/Brewfile.core" \
    "$DOTFILES/packages/darwin/Brewfile.${profile#mac-}" \
    "$DOTFILES/packages/darwin/Brewfile.private"
  combined=$(_combined_brewfile)
  brew bundle cleanup --file "$combined" || true
  if ui_confirm "uninstall everything listed above?"; then
    brew bundle cleanup --force --file "$combined" \
      && ok "cleanup done — doctor should be quiet about drift now" \
      || warn "cleanup finished with errors (see above) — run 'dotfiles doctor' to see what remains"
  else
    warn "aborted — nothing removed"
  fi
  rm -f "$combined"
}
