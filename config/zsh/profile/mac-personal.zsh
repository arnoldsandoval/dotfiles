# mac-personal.zsh — personal Mac.
# (sync nudge is universal — printed by zshrc at shell open; macs never auto-apply)

# vault sync bridge — only fires while this mac holds the recorder role in
# config/vault.conf (role check is inside vault_sync); throttled hourly,
# disowned so the prompt never waits. See vault-automation.md in the vault.
command -v dotfiles >/dev/null && dotfiles vault-sync >/dev/null 2>&1 &!
