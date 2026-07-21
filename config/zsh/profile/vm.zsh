# vm.zsh — servers/VMs: pure consumers of dotfiles.

# Auto-apply on SSH login when behind and clean (ff-only; one line of output),
# then offer the sessions picker. Skipped inside tmux so attaching never loops.
if [[ -o interactive && -n ${SSH_CONNECTION:-} && -z ${TMUX:-} && -t 1 ]]; then
  command -v dotfiles >/dev/null && dotfiles sync --auto || true
  dotfiles sessions
fi
