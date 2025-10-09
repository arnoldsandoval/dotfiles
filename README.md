# dotfiles

macOS development environment setup powered by [Dotbot](https://github.com/anishathalye/dotbot).

## Quick Start

**First time setup** (requires Homebrew):
```bash
# Install Homebrew first (requires password)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then install dotfiles
git clone https://github.com/arnoldsandoval/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./install
```

The install script will:
- ✅ Set up Zsh + Oh-My-Zsh + Antidote
- ✅ Install all apps and dev tools
- ✅ Create symlinks for all configs

## What You Get

**Shell**: Zsh + Starship prompt + useful aliases  
**Node**: nodenv for version management  
**Apps**: Cursor, VS Code, Docker, Raycast, 1Password, and more  
**Git**: Custom configuration with useful aliases

## Daily Usage

| Command       | What it does        |
| ------------- | ------------------- |
| `c`           | Jump to ~/code      |
| `dot`         | Jump to dotfiles    |
| `tunnel 3000` | Create ngrok tunnel |

See all aliases in [`aliases`](./aliases)

## Customization

**Add an alias**: Edit `~/.aliases`  
**Install an app**: Add to `Brewfile`, run `brew bundle`  
**Add Zsh plugin**: Edit `~/.zsh_plugins.txt`

## Files

- `aliases` - Shell shortcuts and functions
- `Brewfile` - Homebrew packages
- `zshrc` - Zsh configuration
- `starship.toml` - Prompt theme
- `gitconfig` - Git settings

---

_This is Arnie's personal setup - use at your own discretion_
