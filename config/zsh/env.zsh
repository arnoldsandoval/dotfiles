# env.zsh — environment + background dotfiles fetch (async, never blocks)

export EDITOR=vim
export BUN_INSTALL="$HOME/.bun"

# kick a quiet dotfiles fetch at most once an hour (prompt-path safe: disowned)
command -v dotfiles >/dev/null && dotfiles fetch --maybe >/dev/null 2>&1 &!

# guarded opt-in tools
command -v thefuck >/dev/null && eval "$(thefuck --alias)"

# bun completions (path is $HOME-relative — no hardcoded usernames)
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
