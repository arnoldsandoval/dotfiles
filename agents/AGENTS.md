# Agent instructions

Shared instructions for AI coding agents (Claude Code, GitHub Copilot). This file
is the single source; `CLAUDE.md` includes it so both agents read the same rules.

## About this environment

- All code lives under `~/code`, one directory per project.
- This machine is managed by [arnoldsandoval/dotfiles](https://github.com/arnoldsandoval/dotfiles):
  `dotfiles doctor` shows drift, `dotfiles sync` applies updates, `dotfiles sessions`
  opens the project session picker (persistent tmux sessions: `cc-*` claude, `cp-*` copilot).
- Machine-local secrets live in `~/.config/zsh/local.zsh` and `~/.gitconfig.local` —
  never commit secrets to this or any repo.

## Conventions

- Commits: prefer [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, `chore:`, …), lowercase subjects — unless a repo explicitly enforces a different convention.
- Prefer `bun` for JS tooling on personal machines; work projects use their own standard (volta/yarn).
- Skills in `skills/` are `compatibility: any-agent` — write new ones the same way.
