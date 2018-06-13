#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin master;

function doDotfiles() {
    cd src &&
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".osx" \
		-avh --no-perms . ~;
    
    echo '🔗 Creating Symlink for ~/.vscode'

    # Delete the autogenerated settings/keybindings if you opened vscode before the script completed.
    [ -e ~/Library/Application\ Support/Code/User/settings.json ] && rm -rf ~/Library/Application\ Support/Code/User/settings.json
    [ -e ~/Library/Application\ Support/Code/User/keybindings.json ] && rm -rf ~/Library/Application\ Support/Code/User/keybindings.json

    ln -s ~/.vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
    ln -s ~/.vscode/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json

	# Delete autogenerated spectacle settings if you opened Spectacle before script completed.
	[ -e ~/Library/Application\ Support/Spectacle/Shortcuts.json ] && rm -rf ~/Library/Application\ Support/Spectacle/Shortcuts.json
    ln -s ~/.spectacle ~/Library/Application\ Support/Spectacle/Shortcuts.json

	source ~/.bash_profile;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doDotfiles;
else
	read -p "What would you like to boostrap? (dotfiles, casks, macOS) " TYPE;
	echo "";

	[[ "$TYPE" == "dotfiles" ]] && doDotfiles;
	[[ "$TYPE" == "casks" ]] && source ./brew.sh;
	[[ "$TYPE" == "macOS" ]] && source ./src/.macos;
	[[ "$TYPE" == "all" ]] && echo "all";
fi;
unset doDotfiles;