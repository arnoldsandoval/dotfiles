export PATH=/opt/homebrew/bin:$PATH

eval "$(starship init zsh)"

export ZSH="$HOME/Library/Caches/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Set the root name of the plugins files (.txt and .zsh) antidote will use.
zsh_plugins=${ZDOTDIR:-~}/.zsh_plugins

# Ensure the .zsh_plugins.txt file exists so you can add plugins.
[[ -f ${zsh_plugins}.txt ]] || touch ${zsh_plugins}.txt

# Lazy-load antidote from its functions directory.
fpath=(${ZDOTDIR:-~}/.antidote/functions $fpath)
autoload -Uz antidote

# Generate a new static file whenever .zsh_plugins.txt is updated.
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  antidote bundle <${zsh_plugins}.txt >|${zsh_plugins}.zsh
fi

# Source your static plugins file.
source ${zsh_plugins}.zsh

# Lazy load nodenv to improve startup time
nodenv() {
  unfunction "$0"
  eval "$(command nodenv init -)"
  $0 "$@"
}

source ~/.aliases

export PATH="$HOME/bin:/usr/local/sbin:$PATH"

# Lazy load fzf
[ -f ~/.fzf.zsh ] && {
  fzf() {
    unfunction "$0"
    source ~/.fzf.zsh
    $0 "$@"
  }
}

# Local dev database credentials only - not for production use
export PGHOST=localhost
export PGUSER=localhost
export PGPASSWORD=localhost

# bun completions
[ -s "/Users/arnie/.bun/_bun" ] && source "/Users/arnie/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
