# skills.sh — skills layer: authored (in-repo, linked) + installed (manifest).
# shellcheck shell=bash

# Authored skills live in $DOTFILES/skills/<name>/ and are linked into
# ~/.claude/skills by the link engine (convention, see lib/link.sh).
#
# Installed (third-party) skills are declared in packages/skills.txt as
# "<name> <owner/repo|TBD>" and materialized via `npx skills add` — never
# vendored here (licensing + staleness). Lock stays in ~/.agents/.skill-lock.json
# as the skills CLI expects.

skills_manifest() { awk '!/^[[:space:]]*(#|$)/ {print $1, $2}' "$DOTFILES/packages/skills.txt" 2>/dev/null; }

# A manifest skill counts as present in the CLI's store (~/.agents/skills —
# where installs land for ANY agent target, incl. copilot) or claude's dir.
_skill_present() { [[ -e $HOME/.agents/skills/$1 || -e $HOME/.claude/skills/$1 ]]; }

skills_list() {
  ui_header "authored (in-repo)"
  local d; for d in "$DOTFILES"/skills/*/; do [[ -d $d ]] && echo "  $(basename "$d")"; done
  ui_header "installed (manifest)"
  local name src
  while read -r name src; do
    if [[ -e $HOME/.claude/skills/$name ]]; then echo "  $name ($src)"; else echo "  $name ($src) ${C_YLW}MISSING${C_OFF}"; fi
  done < <(skills_manifest)
}

# Install manifest skills that are missing. Needs a JS runtime for npx.
# -g global scope, -s exact skill (multi-skill repos), -a per-profile agent
# (this IS the per-agent adapter: claude-code everywhere except mac-work).
skills_install_manifest() {
  local runner=""
  if has npx; then runner="npx --yes"; elif has bunx; then runner="bunx"; fi
  local agent=claude-code
  [[ $(profile_get) == mac-work ]] && agent=github-copilot
  local name src n_skip=0
  while read -r name src; do
    _skill_present "$name" && continue
    if [[ $src == TBD ]]; then
      warn "skill '$name': source not yet classified"; n_skip=$((n_skip+1)); continue
    fi
    if [[ -z $runner ]]; then
      warn "skill '$name': needs node/bun for 'npx skills add $src' — skipping"; n_skip=$((n_skip+1)); continue
    fi
    log "installing skill $name ($src)"
    (cd "$HOME" && $runner skills add "$src" -g -y -s "$name" -a "$agent" </dev/null) \
      || warn "failed: $name"
  done < <(skills_manifest)
  [[ $n_skip -gt 0 ]] && warn "$n_skip manifest skill(s) skipped"
  return 0
}

# check_skills: doctor-mode.
check_skills() {
  local bad=0 d name src
  for d in "$DOTFILES"/skills/*/; do
    [[ -d $d ]] || continue
    name=$(basename "$d")
    [[ -L $HOME/.claude/skills/$name && $(readlink "$HOME/.claude/skills/$name") == "$DOTFILES/skills/$name" ]] \
      || { err "authored skill not linked: $name"; bad=$((bad+1)); }
  done
  while read -r name src; do
    _skill_present "$name" || { err "manifest skill missing: $name ($src)"; bad=$((bad+1)); }
  done < <(skills_manifest)
  return $((bad > 0))
}
