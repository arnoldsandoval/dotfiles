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

# check for homebrew
which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  brew update
fi

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# change default shell
if [! $0 = "-zsh"]; then
  echo 'Changing default shell to zsh'
  chsh -s /bin/zsh
else
  echo 'Already using zsh'
fi