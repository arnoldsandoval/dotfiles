# plugins.zsh — tiny own plugin loader (replaces oh-my-zsh + antidote).
# For each pinned repo: shallow-clone once into ~/.local/share/zsh-plugins,
# then source its entry file. Add/remove plugins by editing this list.

_zplug_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh-plugins"

_zplug() {  # _zplug owner/repo entryfile
  local repo=$1 entry=$2 dir="$_zplug_dir/${1##*/}"
  if [[ ! -d $dir ]]; then
    command -v git >/dev/null || return 0
    git clone --depth=1 "https://github.com/$repo" "$dir" 2>/dev/null || return 0
  fi
  [[ -f $dir/$entry ]] && source "$dir/$entry"
}

_zplug zsh-users/zsh-completions              zsh-completions.plugin.zsh
_zplug zsh-users/zsh-autosuggestions          zsh-autosuggestions.zsh
_zplug zdharma-continuum/fast-syntax-highlighting fast-syntax-highlighting.plugin.zsh

autoload -Uz compinit && compinit -C

unset -f _zplug
unset _zplug_dir
