#!/bin/bash

# Add Homebrew to PATH for Apple Silicon (in case it's not in PATH)
if [[ -f /opt/homebrew/bin/brew ]] && ! command -v brew &> /dev/null; then
  export PATH="/opt/homebrew/bin:$PATH"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Verify Homebrew is available
if ! command -v brew &> /dev/null; then
  echo "Error: Homebrew not found. Please install Homebrew first:"
  echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

echo "Homebrew found, updating..."
brew update

# change default shell
if [ ! "$SHELL" = "/bin/zsh" ]; then
  echo 'Changing default shell to zsh'
  chsh -s /bin/zsh
else
  echo 'Already using zsh'
fi

# install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh is already installed"
fi

# install antidote
ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
if [ ! -d "$ANTIDOTE_DIR" ]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
else
    echo "Antidote is already installed"
fi
