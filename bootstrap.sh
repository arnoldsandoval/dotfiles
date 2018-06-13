#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin master;

function doDotfiles() {
    cd src &&
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		-avh --no-perms . ~;
	source ~/.bash_profile;
}

function doBrew () {
	source ./brew.sh;
}

function doMacOs () {
	source ./src/.macOS;
}

function doAll () {
	doBrew && doMacOs && doDotFiles
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doDotfiles;
else
	read -p "What would you like to boostrap? (dotfiles, casks, macOS) " TYPE;
	echo "";

	[[ "$TYPE" == "dotfiles" ]] && doDotfiles;
	[[ "$TYPE" == "casks" ]] && doBrew;
	[[ "$TYPE" == "macOS" ]] && doMacOs;
	[[ "$TYPE" == "all" ]] && doAll;
fi;

unset doDotfiles;