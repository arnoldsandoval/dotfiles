---
name: dotfiles-skills
description: >
  Add, create, or remove agent skills in the dotfiles system so they sync to
  every machine. Use when the user says "add this skill to my dotfiles",
  "track this skill", "make <skill> available everywhere", "create a new
  skill", or "remove <skill> from my dotfiles". Knows the authored-vs-
  third-party rule: never vendor someone else's skill.
compatibility: any-agent
user_invocable: true
---

# dotfiles-skills

Manages skills in `~/code/dotfiles`. Two categories, two mechanisms — picking
the right one is this skill's whole job:

- **Third-party** (someone else wrote it): one line in `packages/skills.txt`
  (`<skill-name> <owner/repo>`). Installed from upstream via the skills CLI.
  **Never copy third-party skill files into the repo** (licensing + staleness).
  Exception: upstream deleted + permissive license → vendor WITH attribution
  intact and a note in skills.txt (see `editor`).
- **Authored** (the user wrote it): a directory in `skills/<name>/SKILL.md`,
  auto-linked into `~/.claude/skills/` by the link engine.

## Add a third-party skill

1. Resolve the source. If the user gave a name but no repo, find it:
   `npx skills find <query>` or the find-skills skill. If they gave a repo,
   verify the skill name it exposes: `npx skills add <owner/repo> --list`
   (multi-skill repos: the manifest needs the EXACT upstream skill name).
2. Append `<skill-name> <owner/repo>` to `packages/skills.txt` (keep the
   file's grouping/comments tidy).
3. Install now: `dotfiles skills install` (uses `-g -y -s <name>` and the
   profile's agent). Confirm it landed in `~/.claude/skills/<name>`.
4. `dotfiles doctor` should be clean, then `dotfiles save` — every other
   machine picks it up on its next sync/bootstrap.

## Create an authored skill

1. Scaffold `skills/<kebab-name>/SKILL.md` with frontmatter: `name`,
   trigger-rich `description`, `compatibility: any-agent` (house rule —
   see agents/AGENTS.md). Supporting files go next to it; scripts in
   `skills/<name>/scripts/`.
2. `dotfiles link` (links it into `~/.claude/skills/`), test it, then
   `dotfiles save`.
3. If it's derived from someone else's skill, STOP — that's third-party;
   use the manifest instead.

## Remove a skill

- Third-party: delete its line from `packages/skills.txt`, then
  `npx skills remove <name> -g`. Authored: `git rm -r skills/<name>`.
- Either way finish with `dotfiles link` (prunes dead links), `dotfiles
  doctor`, `dotfiles save`.

## Guardrails

- Name collision: refuse if `~/.claude/skills/<name>` exists from the other
  category; ask the user which wins.
- Provenance check before authoring: if the content matches a public skill
  (frontmatter version/license/author, or a suspiciously parallel name),
  classify as third-party — this repo once vendored 13 skills that turned
  out to be mattpocock/skills under renamed labels.
- After any change, `dotfiles doctor` is the source of truth.
