#!/bin/bash

# Homebrew
if ! which brew > /dev/null; then
    echo '📦 Installing Homebrew'
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi;

# zsh/ohmyzsh
echo '📦 Installing zsh'
brew install zsh

echo '📦 Installing Oh My Zsh!'
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# MongoDB
echo '📦 Install MongoDB'
brew install mongodb

echo '📦 Create directory where mongo data files will live'
sudo mkdir -p /data/db

echo '📦 Change permissions for data directory'
sudo chown -R `id -un` /data/db

echo '📦 Run mongo daemon'
mongod

# Install macOS apps
echo '📦 Installing Mac App Store CLI'
brew install mas

echo '📦 Install OS X apps from Brewfile'
brew bundle install

# Node
echo '📦 Installing Node Version Manager'
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash

# VSCode Extensions
echo '⌨️ Installing VSCode Extension: Theme, Night Owl'
code --install-extension sdras.night-owl

echo '⌨️ Installing VSCode Extension: Pigments'
code --install-extension jaspernorth.vscode-pigments

echo '⌨️ Installing VSCode Extension: Prettier'
code --install-extension esbenp.prettier-vscode

echo '⌨️ Installing VSCode Extension: Emmet'
code --install-extension FallenMax.mithril-emmet

echo '⌨️ Installing VSCode Extension: Debugger for Chrome'
code --install-extension msjsdiag.debugger-for-chrome

echo '⌨️ Installing VSCode Extension: JavaScript (ES6) code snippets'
code --install-extension xabikos.JavaScriptSnippets

echo '⌨️ Installing VSCode Extension: React-Native/React/Redux snippets for es6/es7'
code --install-extension EQuimper.react-native-react-redux

echo '⌨️ Installing VSCode Extension: React Standard Style code snippets'
code --install-extension TimonVS.ReactSnippetsStandard

echo '⌨️ Installing VSCode Extension: TODO Highlight'
code --install-extension wayou.vscode-todo-highlight

echo '⌨️ Installing VSCode Extension: Auto Close Tag'
code --install-extension formulahendry.auto-close-tag

echo '⌨️ Installing VSCode Extension: GitLens — Git supercharged'
code --install-extension eamodio.gitlens

echo '⌨️ Installing VSCode Extension: Live Server'
code --install-extension ritwickdey.LiveServer

echo -e "
✅ Setup script complete

\e[1mTo finish setup, you will need to restart Terminal and do the following:\e[0m
    - Install latest node: \e[4mnvm install node\e[0m
    - Use the newly installed node version: \e[4mnvm use node\e[0m
    - Verify the installation version: \e[4mnode -v\e[0m
"