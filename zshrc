# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Source nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Plugins {{{
    # Load the Antibody plugin manager for zsh.
    source <(antibody init)

    # Setup required env var for oh-my-zsh plugins
    export ZSH="$(antibody home)/https-COLON--SLASH--SLASH-github.com-SLASH-robbyrussell-SLASH-oh-my-zsh"

    antibody bundle robbyrussell/oh-my-zsh
    antibody bundle robbyrussell/oh-my-zsh path:plugins/git
    antibody bundle robbyrussell/oh-my-zsh path:plugins/git-flow
    antibody bundle robbyrussell/oh-my-zsh path:plugins/httpie
    antibody bundle robbyrussell/oh-my-zsh path:plugins/jsontools
    antibody bundle robbyrussell/oh-my-zsh path:plugins/jump
    antibody bundle robbyrussell/oh-my-zsh path:plugins/nmap
    antibody bundle robbyrussell/oh-my-zsh path:plugins/rsync
    antibody bundle robbyrussell/oh-my-zsh path:plugins/tmux
    antibody bundle robbyrussell/oh-my-zsh path:plugins/tmuxinator
    antibody bundle robbyrussell/oh-my-zsh path:plugins/web-search
    antibody bundle robbyrussell/oh-my-zsh path:plugins/z

    # Other bundles
    antibody bundle sampson-chen/sack
    antibody bundle zsh-users/zsh-autosuggestions

    # This needs to be the last bundle.
    antibody bundle zsh-users/zsh-syntax-highlighting

    # Load the theme.
    # antibody bundle robbyrussell/oh-my-zsh path:themes/robbyrussell.zsh-theme
    antibody bundle romkatv/powerlevel10k
# }}}

# Base16 Shell
BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        eval "$("$BASE16_SHELL/profile_helper.sh")"

source ~/.aliases

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
