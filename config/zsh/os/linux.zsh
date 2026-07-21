# linux.zsh — Linux-only config

alias iplocal='hostname -I | awk "{print \$1}"'

# cargo env (rustup installs)
[[ -f $HOME/.cargo/env ]] && source "$HOME/.cargo/env"
