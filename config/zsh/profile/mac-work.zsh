# mac-work.zsh — work Mac (Copilot-oriented).
# (sync nudge is universal — printed by zshrc at shell open; macs never auto-apply)

# volta (work standard for node/yarn)
if [[ -d $HOME/.volta ]]; then
  export VOLTA_HOME="$HOME/.volta"
  path=("$VOLTA_HOME/bin" $path)
fi
