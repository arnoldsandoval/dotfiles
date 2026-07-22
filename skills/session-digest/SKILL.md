---
name: session-digest
description: >
  Review a past AI coding session and, when it produced something worth keeping,
  promote a distilled note into the relevant arnievault project. Reads local agent
  session stores read-only (Copilot CLI sqlite + Claude Code JSONL) and prints a digest; it never auto-writes
  into the vault. Use when the user wants to capture a decision or learning from
  a session, or asks "what did we do in that session" / "save this to the vault".
user_invocable: true
---

# session-digest

Promote-what-matters, not auto-archive. A knowledge vault should hold deliberate
knowledge (decisions, learnings, patterns), not a log of every AI session. This skill
helps you look back at a session and, only when it earned it, write a distilled note
into the right project by hand.

The raw records live in each agent's local store — Copilot CLI's `~/.copilot/session-store.db` and Claude Code's `~/.claude/projects/*/…jsonl`. This tool reads them read-only (`--tool copilot|claude|auto`) and prints digests to your terminal. It does not create files in the
vault. You (with the user) decide what, if anything, is worth promoting.

## Workflow

1. **List recent sessions** to find the one in question:
   ```bash
   python3 ~/.agents/skills/session-digest/session_digest.py list            # recent 20
   python3 ~/.agents/skills/session-digest/session_digest.py list --scope runway
   ```
2. **Show its digest** (summary, what was asked, work done, files, PR/commit refs):
   ```bash
   python3 ~/.agents/skills/session-digest/session_digest.py show <id-prefix>
   ```
   An 8-char id prefix is enough.
3. **Decide with the user whether it is worth keeping.** Most sessions are not. Ask:
   did this produce a durable decision, a reusable pattern, or a learning that a future
   reader would want? If not, stop here. Nothing goes in the vault.
4. **If yes, author a distilled note by hand** into the relevant project folder
   (e.g. `projects/<project>/decisions/NNN-<slug>.md` for a decision, or a
   `reference`/`pattern` note). Write it as knowledge, not a transcript: capture the
   decision and its rationale, the learning, or the outcome, in the user's voice.
   Follow the vault frontmatter schema in `~/Documents/arnievault/AGENTS.md`
   (`title, aliases, type, project, status, tags, created, updated`). You may cite the
   session id in the body for provenance, but do not paste the raw digest wholesale.

## Why not auto-sync every session

- The vault is curated knowledge; session logs are activity exhaust. Auto-dumping
  inverts the signal-to-noise ratio as session count grows.
- arnievault syncs to Obsidian cloud; deliberately promoting a distilled note is far
  lower governance risk than auto-flowing every session's file/repo metadata there.
- The session store is already the durable source of truth. Re-derive a digest any time
  instead of keeping a second, staleable copy.

## Notes

- Read-only DB access; safe to run any time.
- `list` with no `--scope` shows recent sessions across all working directories.
- Adapters: `copilot` (sqlite) and `claude` (JSONL) emit the same digest shape; future agents get new adapters.
- Digest output masks token-shaped strings — transcripts can contain pasted secrets; never bypass that by quoting raw transcripts.
