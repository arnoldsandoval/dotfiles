---
name: arnievault-housekeeping
description: >
  Audit the arnievault Obsidian vault against its conventions (kebab naming,
  frontmatter schema, wikilink integrity, orphans, MOC coverage, hygiene) and
  report findings. Audit-first: never mutate files until the user confirms a fix.
  Use when asked to tidy, audit, lint, or health-check arnievault.
user_invocable: true
---

# arnievault housekeeping

Audits `~/Documents/arnievault` against the conventions defined in that vault's
`AGENTS.md`. **Audit-first and non-destructive:** run the checks, present the report,
then apply fixes only for the items the user explicitly approves. Never edit, rename,
move, or delete a file before the user confirms.

The canonical rules live in `~/Documents/arnievault/AGENTS.md`. If that file and this
skill ever disagree, AGENTS.md wins — read it first.

## What it checks

1. **Naming** — files/folders must be lowercase kebab-case, ASCII, no spaces. Reserved
   uppercase names allowed: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CONTEXT.md`,
   `GLOSSARY.md`. Daily notes (`YYYY-MM-DD.md`) are allowed.
2. **Duplicate ordered prefixes** — within a folder, no two files share the same `NN-`
   number prefix (this catches the "two ADR 012s" class of bug).
3. **Frontmatter** — every content note starts with valid YAML frontmatter carrying
   `title, type, status, tags, created, updated`; notes under `projects/` also need
   `project`. Pointer files (`CLAUDE.md`, `GEMINI.md`) and daily notes are exempt.
4. **Wikilink integrity** — every `[[link]]` resolves to a real note (by path or
   basename). Links inside code fences/backticks are ignored.
5. **Orphans** — content notes with no incoming and no outgoing wikilinks.
6. **MOC coverage** — every `projects/*` folder has an index/MOC note; `home.md` links
   every top-level area.
7. **Hygiene** — `.gitignore` ignores `.DS_Store`; no trailing whitespace, no double
   blank lines, no em dashes (—) in notes (house style uses periods/commas/colons).

## How to run

Run the audit script below. It is read-only — it prints findings and changes nothing.

```bash
VAULT="${ARNIEVAULT:-$HOME/Documents/arnievault}"
python3 - "$VAULT" <<'PY'
import sys, os, re, glob, json
from pathlib import Path

vault = Path(sys.argv[1])
RESERVED = {"AGENTS.md","CLAUDE.md","GEMINI.md","CONTEXT.md","GLOSSARY.md"}
POINTERS = {"CLAUDE.md","GEMINI.md"}
REQ = {"title","type","status","tags","created","updated"}
SKIP_DIRS = {".git",".obsidian","graphify-out",".trash"}
daily = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")

def notes():
    for p in vault.rglob("*.md"):
        if any(part in SKIP_DIRS for part in p.relative_to(vault).parts): continue
        yield p

def rel(p): return str(p.relative_to(vault))

# ---- 1 & 2: naming + duplicate prefixes ----
naming, dupes = [], []
for p in vault.rglob("*"):
    parts = p.relative_to(vault).parts
    if any(x in SKIP_DIRS for x in parts): continue
    name = p.name
    if name in RESERVED or daily.match(name): continue
    if name == ".gitignore" or name == ".DS_Store": continue
    stem_ok = re.fullmatch(r"[a-z0-9._-]+", name)
    if not stem_ok:
        naming.append(rel(p))
from collections import defaultdict
byfolder = defaultdict(lambda: defaultdict(list))
for p in notes():
    m = re.match(r"(\d{2,3})-", p.name)
    if m: byfolder[str(p.parent)][m.group(1)].append(rel(p))
for folder, pref in byfolder.items():
    for num, files in pref.items():
        if len(files) > 1: dupes.append((num, files))

# ---- 3: frontmatter ----
fm_missing = []
for p in notes():
    if p.name in POINTERS or daily.match(p.name): continue
    txt = p.read_text(encoding="utf-8", errors="replace")
    if not txt.startswith("---\n"):
        fm_missing.append((rel(p), "no frontmatter")); continue
    end = txt.find("\n---\n", 4)
    if end < 0:
        fm_missing.append((rel(p), "unterminated frontmatter")); continue
    body = txt[4:end]
    keys = set(re.findall(r"^([a-zA-Z_]+):", body, re.M))
    need = set(REQ)
    if rel(p).startswith("projects/"): need = need | {"project"}
    miss = need - keys
    if miss: fm_missing.append((rel(p), "missing " + ",".join(sorted(miss))))

# ---- 4 & 5: wikilinks + orphans ----
byname, byrel = {}, set()
for p in notes():
    r = rel(p)[:-3]; byrel.add(r)
    byname.setdefault(os.path.basename(r), set()).add(r)
lr = re.compile(r"(?<!`)\[\[([^\]]+)\]\]")
broken, has_out, targeted = [], set(), set()
for p in notes():
    r = rel(p)[:-3]
    for m in lr.finditer(p.read_text(encoding="utf-8", errors="replace")):
        t = m.group(1).split("|")[0].split("#")[0].strip()
        if not t or t.endswith(".base") or t.endswith(".canvas"): continue
        has_out.add(r)
        ok = (t in byrel) if "/" in t else (t in byname)
        if ok:
            targeted.update(byname.get(t, {t}) if "/" not in t else {t})
        else:
            broken.append((rel(p), m.group(1)))
orphans = []
for p in notes():
    if p.name in POINTERS or daily.match(p.name): continue
    r = rel(p)[:-3]
    if r not in targeted and r not in has_out: orphans.append(rel(p))

# ---- 6: MOC coverage ----
moc_missing = []
for d in sorted((vault/"projects").glob("*")):
    if not d.is_dir(): continue
    idx = d/(d.name + ".md")
    if not idx.exists():
        # any note with type: moc inside?
        has_moc = any("type: moc" in (f.read_text(encoding="utf-8", errors="replace")[:400])
                      for f in d.glob("*.md"))
        if not has_moc: moc_missing.append(rel(d))

# ---- 7: hygiene ----
hygiene = []
gi = vault/".gitignore"
if not gi.exists() or ".DS_Store" not in gi.read_text(encoding="utf-8", errors="replace"):
    hygiene.append(".gitignore does not ignore .DS_Store")
ws, dbl, emd = [], [], []
for p in notes():
    txt = p.read_text(encoding="utf-8", errors="replace")
    if any(l.rstrip("\n") != l.rstrip() for l in txt.splitlines()): ws.append(rel(p))
    if "\n\n\n" in txt: dbl.append(rel(p))
    body = re.sub(r"^---\n.*?\n---\n", "", txt, flags=re.S)  # skip frontmatter
    if "\u2014" in body: emd.append(rel(p))

def sec(title, items, fmt=lambda x: f"  - {x}"):
    print(f"\n## {title}: {len(items)}")
    for it in items[:40]: print(fmt(it))
    if len(items) > 40: print(f"  ... and {len(items)-40} more")

print("# arnievault housekeeping audit")
print(f"vault: {vault}")
print(f"notes scanned: {sum(1 for _ in notes())}")
sec("Naming violations", naming)
sec("Duplicate number prefixes", dupes, lambda x: f"  - {x[0]}: {', '.join(x[1])}")
sec("Frontmatter issues", fm_missing, lambda x: f"  - {x[0]} ({x[1]})")
sec("Broken wikilinks", broken, lambda x: f"  - {x[0]}: [[{x[1]}]]")
sec("Orphan notes", orphans)
sec("Project folders missing a MOC", moc_missing)
sec("Hygiene: .gitignore", hygiene, lambda x: f"  - {x}")
sec("Hygiene: trailing whitespace", ws)
sec("Hygiene: double blank lines", dbl)
sec("Hygiene: em dashes", emd)
total = (len(naming)+len(dupes)+len(fm_missing)+len(broken)+len(orphans)
         +len(moc_missing)+len(hygiene)+len(ws)+len(dbl)+len(emd))
print(f"\n# TOTAL findings: {total}")
PY
```

## After running

1. Summarize the report for the user grouped by category, leading with the highest-signal
   issues (broken wikilinks, missing frontmatter, duplicate prefixes) and ending with
   style nits (em dashes, whitespace).
2. If total findings is 0, say the vault is clean and stop.
3. Otherwise **ask which categories to fix** before changing anything. Do not batch a
   rename, a frontmatter edit, and a link rewrite into one blind pass — propose the fix
   for a category, get a yes, then apply it.
4. When fixing:
   - Renames: update every wikilink that points at the renamed file in the same change,
     keeping a readable `[[kebab-name|Human Alias]]` display.
   - Frontmatter: follow the schema in `AGENTS.md` exactly; infer `title` from the H1,
     `type`/`project` from the folder, dates from the file mtime.
   - Never touch `_archive/` status values or delete notes without explicit confirmation.
5. Re-run the audit after fixes to confirm the count dropped.

## Notes

- The audit is read-only and safe to run any time.
- Override the vault path with the `ARNIEVAULT` env var if it lives elsewhere.
- This skill encodes conventions; the source of truth is `~/Documents/arnievault/AGENTS.md`.
