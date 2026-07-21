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
    ui_spin "brew bundle (core)" brew bundle --no-upgrade --file "$DOTFILES/packages/darwin/Brewfile.core"
    local pf="$DOTFILES/packages/darwin/Brewfile.${profile#mac-}"   # personal|work
    [[ -f $pf ]] && ui_spin "brew bundle (${profile#mac-})" brew bundle --no-upgrade --file "$pf"
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
    ui_spin "brew bundle (private tap)" brew bundle --no-upgrade --file "$DOTFILES/packages/darwin/Brewfile.private"
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
      out=$(brew bundle check --verbose --file "$DOTFILES/packages/darwin/$pf" 2>&1 | grep -v "satisfied") || true
      [[ -n $out ]] && { err "missing from $pf:"; printf '%s\n' "$out" | sed 's/^/    /'; bad=$((bad+1)); }
    done
    _check_brew_drift
  fi
  for i in $(missing_intents); do err "missing tool: $i"; bad=$((bad+1)); done
  return $((bad > 0))
}

# Drift the other way: things installed by hand that no Brewfile declares.
# Informational (warn, not error) — the fix is 'add to a Brewfile, dotfiles save'.
_check_brew_drift() {
  local profile combined extras
  profile=$(profile_get)
  combined=$(mktemp)
  cat "$DOTFILES/packages/darwin/Brewfile.core" \
      "$DOTFILES/packages/darwin/Brewfile.${profile#mac-}" \
      "$DOTFILES/packages/darwin/Brewfile.private" 2>/dev/null >"$combined"
  extras=$(brew bundle cleanup --file "$combined" 2>/dev/null | sed 's/^/    /')
  rm -f "$combined"
  [[ -n $extras ]] && { warn "installed but not in any Brewfile (add + 'dotfiles save', or uninstall):"; printf '%s\n' "$extras"; }
  return 0
}
