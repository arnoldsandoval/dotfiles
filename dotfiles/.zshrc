# Ensure .bash_profile is loaded
if [ -f ~/.bash_profile ]; then
  . ~/.bash_profile
fi

# Theme
ZSH_THEME=""

# 256 color
export TERM=xterm-256color
[ -n "$TMUX" ] && export TERM=screen-256color
autoload -U promptinit; promptinit   # prompt support
autoload -Uz compinit; compinit      # suggestion support
prompt pure                          # prompt - pure via https://github.com/sindresorhus/pure