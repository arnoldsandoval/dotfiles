# linux.zsh — Linux-only config

alias iplocal='hostname -I | awk "{print \$1}"'

# cargo env (rustup installs)
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env"

# homebrew on linux (linuxbrew)
[[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
