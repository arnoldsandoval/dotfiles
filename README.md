# dotfiles

One repo for every machine: personal Mac, work Mac, Linux VMs/servers.
Pure bash, no frameworks — a small CLI (`dotfiles`) with a [gum](https://github.com/charmbracelet/gum)-powered
TUI that degrades to plain menus when gum isn't installed.

## New machine

```bash
git clone https://github.com/arnoldsandoval/dotfiles ~/code/dotfiles
cd ~/code/dotfiles && ./bootstrap
```

Bootstrap asks **once** what this machine is and saves it:

| profile        | what you get |
| -------------- | ------------ |
| `mac-personal` | full setup: apps + fonts (brew), Claude Code config, 1Password git signing |
| `mac-work`     | work apps, volta (node/yarn), Copilot-oriented; personal identity only for this repo |
| `vm`           | CLI-only; auto-applies dotfiles updates on SSH login; session picker on connect |

Then it runs in tiers, each degrading gracefully:

- **Tier 0** — symlinks + shell config + local stubs. No network needed. Always works.
- **Tier 1** — public packages: `brew bundle` on macOS; apt/tdnf on Linux (prints the
  command to run yourself if sudo isn't available); sudo-free installers for
  starship/gum/bun/zoxide into `~/.local/bin`; third-party skills from `packages/skills.txt`.
- **Tier 2** — private extras (the private homebrew tap). **Skipped with a message**
  when you're not GitHub-authed — never blocks. Unlock later with
  `gh auth login && dotfiles bootstrap --tier 2`.

## Daily driving

| command | what |
| --- | --- |
| `dotfiles` | TUI hub: sessions, sync, doctor, skills, bootstrap |
| `cc` / `dotfiles sessions` | project session picker — persistent tmux sessions per project, resumable Claude (`cc-*`) or Copilot (`cp-*`) agents |
| `dotfiles sync` | fast-forward pull + relink (+ one-line summary) |
| `dotfiles doctor` | drift report: links, packages, skills, git state |
| `dev` / `dt` | attach/detach the `main` tmux session |

**Sync model:** every shell start kicks a *background* fetch (throttled, never blocks),
plus a 6h systemd/launchd timer. VMs auto-apply clean fast-forwards at SSH login;
workstations only show a `dotfiles ⇣N` nudge — applying is always your call where you edit.

**Made a change on this machine?** Configs are symlinks into the repo, so editing
`~/.zshrc` (or a Brewfile) *is* editing the repo. Run `dotfiles save` — it shows the
diff, commits, and pushes; every other machine picks it up on its next fetch.
`dotfiles doctor` flags the other direction too: brew packages installed by hand
that no Brewfile declares.

## Where things live

```
config/<tool>/     configs, symlinked via links.d/*.links (common → OS → profile)
packages/          intent.txt + Brewfiles + apt/tdnf maps + sudo-free installers
skills/            authored agent skills (any-agent SKILL.md format) → ~/.claude/skills
packages/skills.txt  third-party skills, installed from upstream via `npx skills add`
agents/AGENTS.md   shared agent instructions (CLAUDE.md includes it)
lib/ bin/          the bash that runs all of this
```

**Machine-local (never committed):** `~/.config/zsh/local.zsh` (secrets/overrides),
`~/.gitconfig.local` (identity + signer — generated at first bootstrap),
`~/.local/share/dotfiles/` (profile, status, backups).

The link engine never deletes: anything it replaces is backed up to
`~/.local/share/dotfiles/backups/<timestamp>/`.

## Escape hatches

- `DOTFILES_NO_ZSH=1 ssh box` — stay in bash on a VM (the zsh handoff is a bashrc
  hook, not chsh, so bash is always underneath).
- `dotfiles link` re-applies symlinks anytime; `dotfiles doctor` tells you what's off.

---

_Arnie's setup — fork at your own discretion._
