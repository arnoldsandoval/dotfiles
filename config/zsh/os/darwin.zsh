# darwin.zsh — macOS-only config

# Homebrew (Apple Silicon or Intel)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Android SDK
if [[ -d $HOME/Library/Android/sdk ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  path+=("$ANDROID_HOME/emulator" "$ANDROID_HOME/platform-tools")
fi

alias update='softwareupdate --all --install --force'
alias iplocal='ipconfig getifaddr en0'
