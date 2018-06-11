# New macOS setup 
The purpose of this repository is to install Applications, dotfiles and set preferences that I rely on in an attempt to quickly get a new computers setup and maintain *some* consistency across my computers. This project relies heavily on:

Homebrew Casks - for installing the applications I use most
dotfiles - aliases, vscode settings, gitconfig
setup.sh - Sets OS X preferences, creates a Sites Directory copies dotfiles to apropriate places and installs nvm/node

If you wish to do this yourself, feel free to fork this repository and make whatever changes you like.

## Customizing
If you wish to customize this for your own use, feel free to fork this repository and make any changes to the `Brewfile`, `dotfiles` directory or `setup.sh` script to make it your own.

If nothing else, please be sure to update the `.gitconfig` to include your own information.

### To Run
Simply pull this repository and run `sh setup.sh`