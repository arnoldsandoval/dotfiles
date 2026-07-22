# Migration state & per-machine runbook

The 2026 refactor (PR #2) replaced dotbot with the bash `dotfiles` CLI/TUI.
This file tracks the per-machine rollout — update it as machines cut over.

## Status

| machine | profile | status |
| --- | --- | --- |
| hetzner vm (ubuntu-4gb-fsn1-6) | `vm` | ✅ done 2026-07-21, live-verified |
| personal mac | `mac-personal` | ✅ done 2026-07-22 — doctor all clear (pending: one 1Password signing smoke-test) |
| work mac | `mac-work` | ✅ done 2026-07-22 — doctor all clear, curated + cleaned (3.6GB freed) |

## Personal Mac runbook

1. If `~/code/dotfiles` already exists (old dotbot clone): `cd ~/code/dotfiles && git checkout main && git pull`.
   Otherwise: `git clone https://github.com/arnoldsandoval/dotfiles ~/code/dotfiles`.
2. `./bootstrap` → choose `mac-personal`. Notes:
   - The link engine **backs up** anything it replaces (old `~/.zshrc`, `~/.gitconfig`, …)
     to `~/.local/share/dotfiles/backups/<ts>/` — nothing is lost.
   - oh-my-zsh is no longer used; `~/.oh-my-zsh` can be deleted once the new shell
     is confirmed working.
   - A stray real `~/.gitconfig` shadows the new `~/.config/git/config` — doctor
     warns; move it aside (identity now lives in generated `~/.gitconfig.local`).
   - Requires Homebrew already installed (bootstrap warns, doesn't install it).
3. **Skills: DONE 2026-07-22.** All refs classified (see packages/skills.txt);
   4 authored skills live in skills/ (+ vendored MIT `editor`); 23 third-party
   install from upstream via `dotfiles skills install`. `dotfiles sync` (manual)
   also runs `npx skills update -g`. Old repo `arnoldsandoval/skills` is ARCHIVED.
4. **Mac finishing steps:** `git pull && dotfiles link && dotfiles skills install
   && dotfiles doctor`. NOTE: keep `~/.agents/skills` — it is the skills CLI's managed store now (installs live there).
5. Verify: `dotfiles doctor` clean; `git commit -S` signs via 1Password on a scratch
   repo; `brew bundle check` clean for core+personal; new terminal lands in zsh +
   starship with the hub… then update the table above and `dotfiles save`.

## Work Mac runbook (after personal mac)

1. Clone + `./bootstrap` → `mac-work` (prompts once for work git identity;
   dotfiles repo commits stay personal via includeIf).
2. Verify volta lands (`Brewfile.work`) and MDM allows the casks.
3. **Copilot wiring (verify on-machine, surface moves fast):**
   - Find Copilot CLI's global agent-skills discovery dir; set the one target
     variable in `lib/skills.sh` (link mode), or use generate mode as fallback.
   - Wire `agents/AGENTS.md` into VS Code Copilot's instructions setting.
   - Test a `cp-<project>` session from the sessions menu (the launcher's resume
     flags in `lib/menu-sessions.sh` are best-effort until tested against a real
     Copilot CLI).
4. Update the table above and `dotfiles save`.

## Deferred / optional

- Signed commits from VMs: register each VM's own `~/.ssh/id_ed25519.pub` as a
  GitHub **signing** key and point `~/.gitconfig.local` at it (no 1Password needed).
- Fork-friendliness: personal identity values are hardcoded in `lib/gen-local.sh`;
  move to an `identity.conf` if that ever matters.
- Committed-secrets note: old PG localhost dev creds existed in git history before
  2026-07-21 (values worthless, removed from HEAD, history not rewritten).
