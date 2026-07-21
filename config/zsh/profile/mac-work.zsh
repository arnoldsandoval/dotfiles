# mac-work.zsh — work Mac (Copilot-oriented).

# volta (work standard for node/yarn)
if [[ -d $HOME/.volta ]]; then
  export VOLTA_HOME="$HOME/.volta"
  path=("$VOLTA_HOME/bin" $path)
fi

# Passive sync nudge, once per shell session (never auto-applies here).
_dotfiles_nudge() {
  local n; n=$(dotfiles nudge 2>/dev/null)
  [[ -n $n ]] && print -P "%F{yellow}$n%f"
  add-zsh-hook -d precmd _dotfiles_nudge
}
autoload -Uz add-zsh-hook && add-zsh-hook precmd _dotfiles_nudge
