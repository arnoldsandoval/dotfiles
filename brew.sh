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
brew services start mongodb

# Install macOS apps
echo '📦 Installing Mac App Store CLI'
brew install mas

echo '📦 Install OS X apps from Brewfile'
brew bundle install

# Node
echo '📦 Installing Node Version Manager'
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash

# VSCode Extensions
# NOTE: You can always generate this list on any computer by running the following:
#   `code --list-extensions | xargs -L 1 echo code --install-extension`

code --install-extension akamud.vscode-theme-onedark
code --install-extension christian-kohler.npm-intellisense
code --install-extension dbaeumer.vscode-eslint
code --install-extension eamodio.gitlens
code --install-extension EditorConfig.EditorConfig
code --install-extension EQuimper.react-native-react-redux
code --install-extension esbenp.prettier-vscode
code --install-extension FallenMax.mithril-emmet
code --install-extension flowtype.flow-for-vscode
code --install-extension formulahendry.auto-close-tag
code --install-extension jaspernorth.vscode-pigments
code --install-extension msjsdiag.debugger-for-chrome
code --install-extension shinnn.stylelint
code --install-extension silvenon.mdx
code --install-extension TimonVS.ReactSnippetsStandard
code --install-extension wayou.vscode-todo-highlight
code --install-extension xabikos.JavaScriptSnippets
code --install-extension zhuangtongfa.Material-theme
code --install-extension Zignd.html-css-class-completion

echo '⌨️ Install Pure Prompt'
npm install --global pure-prompt

echo -e "
✅ Setup script complete

\e[1mTo finish setup, you will need to restart Terminal and do the following:\e[0m
    - Install latest node: \e[4mnvm install node\e[0m
    - Use the newly installed node version: \e[4mnvm use node\e[0m
    - Verify the installation version: \e[4mnode -v\e[0m
"