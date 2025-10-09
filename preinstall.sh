#!/bin/bash

# Check if we need to add Homebrew to PATH first (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]] && ! command -v brew &> /dev/null; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# check for homebrew
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH (Apple Silicon)
  if [[ -f /opt/homebrew/bin/brew ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Error: Homebrew installation failed"
    exit 1
  fi
  
  echo "Homebrew installed successfully"
else
  echo "Homebrew already installed, updating..."
  brew update
fi

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
if [ ! -d "${ZDOTDIR:-~}/.antidote" ]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
else
    echo "Antidote is already installed"
fi
