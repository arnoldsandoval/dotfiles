# aliases.zsh — cross-platform aliases & small functions

alias c='cd ~/code'
alias dot='cd ~/code/dotfiles'

# tmux
alias dev='tmux new -A -s main'
alias dt='tmux detach'

# sessions picker (the dotfiles TUI sessions screen)
alias cc='dotfiles sessions'

# network
alias ip='dig +short myip.opendns.com @resolver1.opendns.com -4'
alias ipv6='dig +short AAAA myip.opendns.com @resolver1.opendns.com'

# git patches
alias gpatch='git diff > ~/patch-$(date +"%Y%m%d-%H%M%S").patch'
gpatchapply() {
  [[ -n ${1:-} && -f $1 ]] || { echo "usage: gpatchapply <file.patch>" >&2; return 1; }
  git apply "$1"
}

# ngrok tunnel on a port
tunnel() {
  [[ -n ${1:-} ]] || { echo "usage: tunnel <port>" >&2; return 1; }
  ngrok http --url=arnie.ngrok.dev "$1"
}
