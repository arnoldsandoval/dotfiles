# bashrc-hook.sh — sourced from the managed block in ~/.bashrc on Linux.
# Hands interactive shells to zsh when available; bash remains the safety net.
#
#   DOTFILES_NO_ZSH=1 ssh box     # rescue hatch: stay in bash

if [[ $- == *i* && -z "${DOTFILES_NO_ZSH:-}" ]] && command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh
fi

# --- bash fallback (zsh not installed yet) ---------------------------------
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
alias dev='tmux new -A -s main'
alias dt='tmux detach'
alias cc='dotfiles sessions'

# session picker on SSH login (same behavior as the zsh vm profile)
if [[ $- == *i* && -n "${SSH_CONNECTION:-}" && -z "${TMUX:-}" && -t 1 ]] \
   && command -v dotfiles >/dev/null 2>&1; then
  dotfiles sync --auto || true
  dotfiles sessions
fi
