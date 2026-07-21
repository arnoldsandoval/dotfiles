# vm.zsh — servers/VMs: pure consumers of dotfiles.

# Auto-apply on SSH login when behind and clean (ff-only; one line of output),
# then open the dotfiles hub. Skipped inside tmux so attaching never loops.
if [[ -o interactive && -n ${SSH_CONNECTION:-} && -z ${TMUX:-} && -t 1 ]]; then
  command -v dotfiles >/dev/null && dotfiles sync --auto || true
  dotfiles
fi
# (dirty-tree nudge still prints via zshrc — auto-sync only handles the behind case)
