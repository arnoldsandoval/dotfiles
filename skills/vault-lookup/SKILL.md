---
name: vault-lookup
description: >
  Consult arnievault (the user's Obsidian knowledge vault) for prior decisions,
  patterns, project notes, and conventions before designing or proposing.
  Use when starting design work, when the user asks "did we decide…" /
  "check the vault" / "what do my notes say", or when a past decision would
  change your recommendation. Read freely; write ONLY via branch + PR.
compatibility: any-agent
user_invocable: true
---

# vault-lookup

The vault is curated knowledge: decisions with rationale, patterns, learnings,
project notes. Consulting it grounds new work in what was already decided.

## Where the vault is

| machine | path | role |
|---|---|---|
| personal Mac | `~/Documents/arnievault` | git hub (dotfiles vault_sync) |
| work Mac | `~/Documents/arnievault` | Obsidian Sync only — no git |
| VM | `~/code/arnievault` | read-only clone (dotfiles sync pulls it) |

If the path is missing on the VM, `dotfiles sync` clones it (needs gh auth).

## Reading (always allowed)

1. **Read the vault's `AGENTS.md` first** — it is the constitution for naming,
   frontmatter, wikilinks, and LinkedIn/work rules. It outranks this skill.
2. Search with `rg`/grep (it is all markdown), or the obsidian-cli skill when
   installed. Useful entry points: `home.md`, `projects/<project>/`,
   `projects/*/decisions/`, `digests/digests.md`, `vault-automation.md`.
3. Cite what you find ("per decision NNN in <note>") so the user can verify.

## Writing (ceremony required — never casual)

- **Never commit to `main`. Never write directly into the vault working tree.**
  On Macs the tree belongs to Obsidian Sync; on the VM the clone is read-only
  by policy.
- The single sanctioned write path is the one the cloud routines use:
  branch → PR against `arnoldsandoval/arnievault` → the human gate (or the
  digests-only auto-merge rule) decides. See `vault-automation.md`
  § Routine contract before authoring anything.
- Promotion of session learnings goes through the session-digest skill's
  workflow: distill by hand, follow the vault frontmatter schema, only when
  the content earned it. Never bulk-ingest, never auto-promote.

## Boundaries

- Work-sensitive notes exist in the vault: quote them back to the user freely,
  but never move vault content into other repos, public artifacts, or logs.
- A failed lookup is fine — say the vault has nothing on the topic rather than
  inventing a decision.
