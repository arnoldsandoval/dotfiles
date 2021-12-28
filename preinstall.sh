#!/bin/bash

# check for ~/.config/nvim dir
DIR_NEOVIM="$HOME/.config/nvim/"
if [ ! -d "$DIR_NEOVIM" ]; then
  echo "Creating $DIR_NEOVIM"
  mkdir -p $DIR_NEOVIM
fi

# check if nvm is installed
DIR_NVM="$HOME/.nvm"
if [ ! -d "$DIR_NVM" ]; then
  echo 'Installing nvm'
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
fi

# check if base16-shell is installed
DIR_B16="$HOME/.config/base16-shell"
if [ ! -d "$DIR_B16" ]; then
  echo 'Cloning chriskempson/base16-shell'
  git clone https://github.com/chriskempson/base16-shell.git $DIR_B16
else
  echo 'Already using base16-shell'
fi

# change default shell
if [! $0 = "-zsh"]; then
  echo 'Changing default shell to zsh'
  chsh -s /bin/zsh
else
  echo 'Already using zsh'
fi
