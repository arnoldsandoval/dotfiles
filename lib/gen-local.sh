#!/usr/bin/env bash
# gen-local.sh — first-run generation of machine-local (never-committed) files:
#   ~/.gitconfig.local        git identity + signer (per profile)
#   ~/.config/zsh/local.zsh   machine secrets/overrides stub
# Idempotent: existing files are left untouched.
set -euo pipefail
DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES/lib/core.sh"
source "$DOTFILES/lib/platform.sh"
source "$DOTFILES/lib/profile.sh"
source "$DOTFILES/lib/tui.sh"

profile=$(profile_get)

# --- ~/.config/zsh/local.zsh ------------------------------------------------
local_zsh="$HOME/.config/zsh/local.zsh"
if [[ ! -f $local_zsh ]]; then
  mkdir -p "$(dirname "$local_zsh")"
  cat >"$local_zsh" <<'EOF'
# local.zsh — machine-local shell config. NOT tracked by dotfiles.
# Put machine secrets and one-off overrides here, e.g.:
#   export PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres
EOF
  ok "wrote $local_zsh stub"
fi

# --- ~/.gitconfig.local -----------------------------------------------------
gc_local="$HOME/.gitconfig.local"
if [[ ! -f $gc_local ]]; then
  name="arnie"; email="arnold@arnie.io"
  signingkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICf21qywyaQtu+IGPKMu5nu32GMstbtbYUEzuppUcP5I"
  if [[ $profile == mac-work ]]; then
    if [[ -z ${DOTFILES_YES:-} ]]; then
      name=$(ui_input "git name (work)" "$name")
      email=$(ui_input "git email (work)" "")
    fi
    [[ -n $email ]] || email="SET-ME@work.example"
  fi
  {
    printf '[user]\n\tname = %s\n\temail = %s\n' "$name" "$email"
    if [[ $profile == mac-personal ]]; then
      printf '\tsigningkey = %s\n' "$signingkey"
      printf '[gpg "ssh"]\n\tprogram = /Applications/1Password.app/Contents/MacOS/op-ssh-sign\n'
      printf '[commit]\n\tgpgsign = true\n'
    fi
    if [[ $profile == mac-work ]]; then
      # dotfiles repo commits stay personal even on the work machine
      printf '[includeIf "gitdir:~/code/dotfiles/"]\n\tpath = ~/.gitconfig.personal\n'
    fi
  } >"$gc_local"
  ok "wrote $gc_local ($profile identity)"
  if [[ $profile == mac-work && ! -f $HOME/.gitconfig.personal ]]; then
    printf '[user]\n\tname = arnie\n\temail = arnold@arnie.io\n' >"$HOME/.gitconfig.personal"
    ok "wrote ~/.gitconfig.personal (dotfiles identity)"
  fi
fi
