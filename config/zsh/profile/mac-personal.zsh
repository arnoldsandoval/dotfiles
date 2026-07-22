# mac-personal.zsh — personal Mac.
# (sync nudge is universal — printed by zshrc at shell open; macs never auto-apply)

# vault sync bridge (this mac is the arnievault git hub): throttled hourly,
# disowned so the prompt never waits. See vault-automation.md in the vault.
command -v dotfiles >/dev/null && dotfiles vault-sync >/dev/null 2>&1 &!
