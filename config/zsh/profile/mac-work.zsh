# mac-work.zsh — work Mac (Copilot-oriented).
# (sync nudge is universal — printed by zshrc at shell open; macs never auto-apply)

# Copilot CLI self-updates in-place and can drift onto prerelease builds even
# when Homebrew thinks it's still on a pinned stable version. Disable the
# built-in auto-updater entirely; update only via `brew upgrade --cask
# copilot-cli` (stable-only cask, never prerelease).
export COPILOT_AUTO_UPDATE=false

# volta (work standard for node/yarn)
if [[ -d $HOME/.volta ]]; then
  export VOLTA_HOME="$HOME/.volta"
  path=("$VOLTA_HOME/bin" $path)
fi
