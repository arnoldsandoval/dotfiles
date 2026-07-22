#!/usr/bin/env python3
"""On-demand digest of a chosen AI coding session (multi-agent).

Adapters read each agent's local session store READ-ONLY and emit one shared
digest shape. It never writes into the vault. The point is "promote what
matters": you review a digest, then deliberately author a distilled note into
the relevant project only when the session produced something worth keeping
(a decision, a learning), rather than auto-dumping every session.

Adapters:
    copilot   ~/.copilot/session-store.db   (SQLite)
    claude    ~/.claude/projects/*/<id>.jsonl (Claude Code transcripts)

Usage:
    session_digest.py list [--tool copilot|claude|auto] [--scope SUBSTR] [--limit N] [--all]
    session_digest.py show <session_id_prefix> [--tool ...]

Default --tool auto: every store present on this machine. `show` searches all
selected stores for the id prefix. Digest only: summary, what was asked, work
done, files touched, refs. No transcripts, no assistant text.
"""
import argparse
import datetime as dt
import json
import re
import sqlite3
import sys
from pathlib import Path

COPILOT_DB = Path.home() / ".copilot/session-store.db"
CLAUDE_DIR = Path.home() / ".claude/projects"


def to_date(ts: str) -> str:
    if not ts:
        return dt.date.today().isoformat()
    m = re.match(r"(\d{4}-\d{2}-\d{2})", str(ts))
    return m.group(1) if m else dt.date.today().isoformat()


def squash(text: str, n: int) -> str:
    text = re.sub(r"\[image:[^\]]*\]", "", text or "")
    # mask token-shaped strings — transcripts contain pasted secrets, and a
    # digest must never re-emit them (defense in depth on top of the
    # promote-by-hand rule)
    text = re.sub(r"[A-Za-z0-9_\-:]{24,}", "[redacted]", text)
    return re.sub(r"\s+", " ", text).strip()[:n]


# ---------------------------------------------------------------- copilot ---
class CopilotStore:
    tool = "copilot-cli"

    def __init__(self, db=COPILOT_DB):
        self.db = Path(db)

    def available(self):
        return self.db.exists()

    def _con(self):
        # Read-only, but NOT immutable: immutable=1 ignores the -wal file and
        # would miss the most recent (still-in-WAL) sessions.
        con = sqlite3.connect(f"file:{self.db}?mode=ro", uri=True)
        con.row_factory = sqlite3.Row
        return con

    def list_sessions(self, scope, limit):
        con = self._con()
        where = "WHERE s.cwd LIKE ?" if scope else ""
        args = [f"%{scope}%"] if scope else []
        rows = con.execute(
            f"""SELECT s.id, s.cwd, s.summary, s.updated_at,
                   (SELECT COUNT(*) FROM turns t WHERE t.session_id = s.id) AS turns
                FROM sessions s {where} ORDER BY s.updated_at DESC LIMIT ?""",
            args + [limit],
        ).fetchall()
        return [dict(id=r["id"], date=to_date(r["updated_at"]), turns=r["turns"],
                     summary=r["summary"] or (Path(r["cwd"]).name if r["cwd"] else ""),
                     tool=self.tool) for r in rows]

    def match_ids(self, prefix):
        con = self._con()
        rows = con.execute("SELECT id FROM sessions WHERE id LIKE ? ORDER BY updated_at DESC",
                           (prefix + "%",)).fetchall()
        return [r["id"] for r in rows]

    def digest(self, sid):
        con = self._con()
        s = con.execute(
            "SELECT id, cwd, repository, branch, summary, updated_at, "
            "(SELECT COUNT(*) FROM turns t WHERE t.session_id=sessions.id) AS turns "
            "FROM sessions WHERE id=?", (sid,)).fetchone()
        asks = [squash(r["user_message"], 160) for r in con.execute(
            "SELECT user_message FROM turns WHERE session_id=? AND user_message IS NOT NULL "
            "AND TRIM(user_message)<>'' ORDER BY turn_index LIMIT 10", (sid,)).fetchall()]
        cp = con.execute(
            "SELECT overview, work_done, next_steps FROM checkpoints "
            "WHERE session_id=? ORDER BY checkpoint_number DESC LIMIT 1", (sid,)).fetchone()
        frows = con.execute(
            "SELECT file_path, tool_name FROM session_files WHERE session_id=? "
            "ORDER BY first_seen_at", (sid,)).fetchall()
        refs = [(r["ref_type"], r["ref_value"]) for r in con.execute(
            "SELECT ref_type, ref_value FROM session_refs WHERE session_id=? "
            "ORDER BY ref_type", (sid,)).fetchall()]
        return dict(
            id=sid, tool=self.tool, cwd=s["cwd"], repo=s["repository"], branch=s["branch"],
            date=to_date(s["updated_at"]), turns=s["turns"],
            summary=s["summary"] or (asks[0][:60] if asks else ""),
            overview=cp["overview"] if cp else "", work_done=cp["work_done"] if cp else "",
            next_steps=cp["next_steps"] if cp else "", asks=asks,
            files=[(r["file_path"], r["tool_name"] or "") for r in frows][:30],
            files_total=len(frows), refs=refs,
        )


# ----------------------------------------------------------------- claude ---
class ClaudeStore:
    tool = "claude-code"

    def __init__(self, root=CLAUDE_DIR):
        self.root = Path(root)

    def available(self):
        return self.root.is_dir()

    def _files(self):
        # top-level session transcripts only; subagent transcripts live deeper
        return sorted(self.root.glob("*/*.jsonl"),
                      key=lambda p: p.stat().st_mtime, reverse=True)

    @staticmethod
    def _user_text(obj):
        if obj.get("type") != "user":
            return ""
        c = (obj.get("message") or {}).get("content")
        if isinstance(c, list):
            c = " ".join(p.get("text", "") for p in c if isinstance(p, dict))
        if not isinstance(c, str):
            return ""
        t = c.strip()
        if not t or t.startswith("<") or "continued from" in t[:120]:
            return ""
        return t

    def _scan(self, path, deep=False):
        """One pass over a transcript. Cheap fields always; asks/files if deep."""
        info = dict(cwd="", turns=0, first="", asks=[], files=[], files_seen=set())
        try:
            with open(path, errors="replace") as fh:
                for line in fh:
                    if '"cwd"' in line and not info["cwd"]:
                        m = re.search(r'"cwd"\s*:\s*"([^"]+)"', line)
                        if m:
                            info["cwd"] = m.group(1)
                    if '"type":"user"' not in line and '"type": "user"' not in line:
                        if deep and '"file_path"' in line and '"name"' in line:
                            m = re.search(r'"name"\s*:\s*"(Write|Edit|NotebookEdit)"', line)
                            f = re.search(r'"file_path"\s*:\s*"([^"]+)"', line)
                            if m and f and f.group(1) not in info["files_seen"]:
                                info["files_seen"].add(f.group(1))
                                info["files"].append((f.group(1), m.group(1)))
                        continue
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    t = self._user_text(obj)
                    if not t:
                        continue
                    info["turns"] += 1
                    if not info["first"]:
                        info["first"] = squash(t, 280)
                    if deep and len(info["asks"]) < 10:
                        info["asks"].append(squash(t, 160))
        except OSError:
            pass
        return info

    def list_sessions(self, scope, limit):
        out = []
        for p in self._files():
            if len(out) >= limit:
                break
            info = self._scan(p)
            if scope and scope not in info["cwd"]:
                continue
            if info["turns"] == 0:
                continue
            out.append(dict(
                id=p.stem, date=dt.date.fromtimestamp(p.stat().st_mtime).isoformat(),
                turns=info["turns"],
                summary=info["first"][:44] or (Path(info["cwd"]).name if info["cwd"] else ""),
                tool=self.tool))
        return out

    def match_ids(self, prefix):
        return [p.stem for p in self._files() if p.stem.startswith(prefix)]

    def _path(self, sid):
        for p in self._files():
            if p.stem == sid:
                return p
        return None

    def digest(self, sid):
        p = self._path(sid)
        info = self._scan(p, deep=True)
        return dict(
            id=sid, tool=self.tool, cwd=info["cwd"], repo="", branch="",
            date=dt.date.fromtimestamp(p.stat().st_mtime).isoformat(),
            turns=info["turns"], summary=info["first"][:60],
            overview="", work_done="", next_steps="", asks=info["asks"],
            files=info["files"][:30], files_total=len(info["files"]), refs=[],
        )


# ----------------------------------------------------------------- output ---
def render(d):
    out = [f"# {d['summary'] or 'Session ' + d['id'][:8]}", ""]
    meta = []
    if d["repo"]:
        meta.append(f"Repo: `{d['repo']}`")
    if d["branch"]:
        meta.append(f"Branch: `{d['branch']}`")
    if d["cwd"]:
        meta.append(f"CWD: `{d['cwd']}`")
    meta.append(f"Date: {d['date']}  ·  Turns: {d['turns']}  ·  "
                f"Tool: {d['tool']}  ·  Session `{d['id'][:8]}`")
    out += ["  \n".join(meta), ""]
    if d["overview"] or d["work_done"]:
        if d["overview"]:
            out += ["## Overview", d["overview"].strip(), ""]
        if d["work_done"]:
            out += ["## Work done", d["work_done"].strip(), ""]
        if d["next_steps"]:
            out += ["## Next steps", d["next_steps"].strip(), ""]
    elif d["asks"]:
        out += ["## What was asked"] + [f"- {a}" for a in d["asks"]] + [""]
    if d["files"]:
        extra = f" ({d['files_total']})" if d["files_total"] > len(d["files"]) else ""
        out += [f"## Files touched{extra}"]
        out += [f"- `{p}`" + (f" ({t})" if t else "") for p, t in d["files"]] + [""]
    if d["refs"]:
        out += ["## References"] + [f"- {rt}: {rv}" for rt, rv in d["refs"]] + [""]
    print("\n".join(out).rstrip())


def stores_for(tool):
    all_stores = {"copilot": CopilotStore(), "claude": ClaudeStore()}
    if tool != "auto":
        return [all_stores[tool]]
    return [s for s in all_stores.values() if s.available()]


def main():
    ap = argparse.ArgumentParser(description="On-demand digest of a chosen AI session.")
    ap.add_argument("--tool", choices=["auto", "copilot", "claude"], default="auto")
    sub = ap.add_subparsers(dest="cmd")
    pl = sub.add_parser("list")
    pl.add_argument("--scope", default="")
    pl.add_argument("--all", action="store_true")
    pl.add_argument("--limit", type=int, default=20)
    ps = sub.add_parser("show")
    ps.add_argument("session_id")
    args = ap.parse_args()

    stores = stores_for(args.tool)
    stores = [s for s in stores if s.available()]
    if not stores:
        print("no session stores found on this machine", file=sys.stderr)
        return 1

    if args.cmd == "show":
        hits = [(s, i) for s in stores for i in s.match_ids(args.session_id)]
        if not hits:
            print(f"No session matches prefix '{args.session_id}'.", file=sys.stderr)
            return 1
        if len(hits) > 1:
            print(f"Ambiguous ({len(hits)}): " + ", ".join(f"{i[:8]}({s.tool})" for s, i in hits[:8]),
                  file=sys.stderr)
            return 1
        render(hits[0][0].digest(hits[0][1]))
        return 0

    scope = getattr(args, "scope", "")
    limit = getattr(args, "limit", 20)
    rows = []
    for s in stores:
        rows += s.list_sessions(scope, limit)
    rows.sort(key=lambda r: r["date"], reverse=True)
    rows = rows[:limit]
    if not rows:
        print("No sessions found.")
        return 0
    print(f"{'id':10} {'date':11} {'turns':>5} {'tool':13} summary / cwd")
    print("-" * 78)
    for r in rows:
        print(f"{r['id'][:8]:10} {r['date']:11} {r['turns']:>5} {r['tool']:13} {r['summary'][:38]}")
    print("\nRun: session_digest.py show <id-prefix>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
