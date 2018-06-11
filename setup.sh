#!/bin/bash

# macOS stuff
echo '💻 Turning on AppleShowAllFiles'
defaults write com.apple.finder AppleShowAllFiles TRUE;

echo '💻 Turning on AppleShowAllExtensions'
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo '💻 Turning on AppleInterfaceTheme Dark'
defaults write /Library/Preferences/.GlobalPreferences AppleInterfaceTheme Dark

echo '💻 Show Library Folder'
chflags nohidden ~/Library

killall Finder

echo '📁 Making ~/Sites directory'
mkdir ~/Sites
 
# dotfiles
echo '📤 Copying dotfiles'
cp -i ./dotfiles/.bash_profile ~/.bash_profile
cp -i ./dotfiles/.gitconfig ~/.gitconfig
cp -i ./dotfiles/.zshrc ~/.zshrc
cp -i -a ./dotfiles/.vscode ~/.vscode

echo '🔗 Creating Symlink for ~/.vscode'
ln -s ~/.vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
ln -s ~/.vscode/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json

# zsh/ohmyzsh
echo '📦 Installing zsh'
brew install zsh

echo '📦 Installing Oh My Zsh!'
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

source ~/.bash_profile

# Homebrew
if ! which brew > /dev/null; then
    echo '📦 Installing Homebrew'
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi;

echo '📦 Installing Mac App Store CLI'
brew install mas

echo '📦 Install OS X apps from Brewfile'
brew bundle install

# Node
echo '📦 Installing Node Version Manager'
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash

echo -e "
✅ Setup script complete

\e[1mTo finish setup, you will need to restart Terminal and do the following:\e[0m
    - Install latest node: \e[4mnvm install node\e[0m
    - Use the newly installed node version: \e[4mnvm use node\e[0m
    - Verify the installation version: \e[4mnode -v\e[0m
"