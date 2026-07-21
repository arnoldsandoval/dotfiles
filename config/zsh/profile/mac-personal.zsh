# mac-personal.zsh — personal Mac.

# Passive sync nudge, once per shell session (never auto-applies here).
_dotfiles_nudge() {
  local n; n=$(dotfiles nudge 2>/dev/null)
  [[ -n $n ]] && print -P "%F{yellow}$n%f"
  add-zsh-hook -d precmd _dotfiles_nudge
}
autoload -Uz add-zsh-hook && add-zsh-hook precmd _dotfiles_nudge
