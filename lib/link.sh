# link.sh — the symlink engine. Replaces dotbot. Sourced after core+platform+profile.
# shellcheck shell=bash

# Manifest format (links.d/*.links): two whitespace-separated columns, # comments:
#   TARGET(~-relative ok)    SOURCE(repo-relative)
# Applied layers: common -> <os> -> <profile>; later layers override earlier ones.

_link_backup_dir=""   # one timestamped dir per run, created lazily

_backup() {
  local target=$1
  [[ -n $_link_backup_dir ]] || _link_backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  local dest="$_link_backup_dir${target/#$HOME/}"
  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  warn "backed up $target -> $dest"
}

# Collect effective target->source map for current (OS, profile).
_link_manifest() {
  local layer files=() f
  for layer in common "$OS" "$(profile_get)"; do
    f="$DOTFILES/links.d/$layer.links"
    [[ -f $f ]] && files+=("$f")
  done
  # last-wins per target (portable — no tac on macOS)
  awk '!/^[[:space:]]*(#|$)/ {map[$1]=$2; if (!($1 in ord)) ord[$1]=++n}
       END {for (t in map) print ord[t], t, map[t]}' "${files[@]}" 2>/dev/null \
    | sort -n | cut -d' ' -f2-
}

# Link every dir in skills/ into ~/.claude/skills (convention, not manifest).
_link_skills_entries() {
  local d
  for d in "$DOTFILES"/skills/*/; do
    [[ -d $d ]] || continue
    printf '%s %s\n' "$HOME/.claude/skills/$(basename "$d")" "skills/$(basename "$d")"
  done
}

# apply_links [--quiet]: returns nonzero if any entry errored.
apply_links() {
  local quiet=${1:-} target source abs n_ok=0 n_fix=0 n_err=0
  while read -r target source; do
    [[ -n $target ]] || continue
    target=${target/#\~/$HOME}
    abs="$DOTFILES/$source"
    if [[ ! -e $abs ]]; then err "missing source: $source"; n_err=$((n_err+1)); continue; fi
    mkdir -p "$(dirname "$target")"
    if [[ -L $target ]]; then
      [[ $(readlink "$target") == "$abs" ]] && { n_ok=$((n_ok+1)); continue; }
      rm "$target"
    elif [[ -e $target ]]; then
      _backup "$target"
    fi
    ln -s "$abs" "$target" && n_fix=$((n_fix+1)) || n_err=$((n_err+1))
  done < <(_link_manifest; _link_skills_entries)
  # prune skill links whose repo source is gone (skill removed/reclassified);
  # only touches symlinks pointing into this repo, never other entries
  local l
  for l in "$HOME"/.claude/skills/*; do
    [[ -L $l && ! -e $l && $(readlink "$l") == "$DOTFILES"/skills/* ]] || continue
    rm "$l" && n_fix=$((n_fix+1))
  done
  [[ $quiet == --quiet ]] || log "links: $n_ok ok, $n_fix created/fixed, $n_err errors"
  [[ $n_err -eq 0 ]]
}

# check_links: doctor-mode, read-only. Prints problems; returns nonzero if any.
check_links() {
  local target source abs bad=0
  while read -r target source; do
    [[ -n $target ]] || continue
    target=${target/#\~/$HOME}
    abs="$DOTFILES/$source"
    if [[ ! -e $abs ]]; then err "manifest source missing: $source"; bad=$((bad+1))
    elif [[ ! -L $target ]]; then
      if [[ -e $target ]]; then err "not a symlink (real file): $target"; else err "missing link: $target"; fi
      bad=$((bad+1))
    elif [[ $(readlink "$target") != "$abs" ]]; then
      err "wrong link: $target -> $(readlink "$target")"; bad=$((bad+1))
    fi
  done < <(_link_manifest; _link_skills_entries)
  # Broken repo-pointing symlinks anywhere interesting. Deliberately NO
  # process substitution and NO comments/quotes inside one: the bash 3.2
  # parser (macOS) scans substitution bodies naively and trips on both.
  local broken f
  broken=$(find "$HOME/.config" "$HOME/.local/bin" "$HOME/.claude/skills" "$HOME" \
             -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    [[ $(readlink "$f") == "$DOTFILES"/* ]] || continue
    err "broken repo link: $f -> $(readlink "$f")"; bad=$((bad+1))
  done <<EOF
$broken
EOF
  return $((bad > 0))
}
