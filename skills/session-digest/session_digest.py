#!/usr/bin/env python3
"""On-demand digest of a chosen AI coding session.

Reads GitHub Copilot CLI's local session store (SQLite) and either lists recent
sessions or prints a concise digest of one chosen session to stdout. It never
writes into the vault. The point is "promote what matters": you review a digest,
then deliberately author a distilled note into the relevant project only when the
session produced something worth keeping (a decision, a learning), rather than
auto-dumping every session.

Usage:
    session_digest.py list [--scope SUBSTR] [--limit N] [--all]
    session_digest.py show <session_id_prefix>

Defaults: db=~/.copilot/session-store.db. `list` shows recent sessions (default
20). `show` prints the digest for the session whose id starts with the prefix.
Digest only: summary, what was asked, work done (from checkpoints when present),
files touched, PR/commit refs. No transcripts, no assistant text.
"""
import argparse
import datetime as dt
import re
import sqlite3
import sys
from pathlib import Path

TOOL = "copilot-cli"
DEFAULT_DB = Path.home() / ".copilot/session-store.db"


def to_date(ts: str) -> str:
    if not ts:
        return dt.date.today().isoformat()
    m = re.match(r"(\d{4}-\d{2}-\d{2})", ts)
    return m.group(1) if m else dt.date.today().isoformat()


def connect_ro(db: Path) -> sqlite3.Connection:
    # Read-only, but NOT immutable: immutable=1 ignores the -wal file and would
    # read a stale snapshot that misses the most recent (still-in-WAL) sessions.
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    return con


def first_user_ask(con, sid):
    r = con.execute(
        "SELECT user_message FROM turns WHERE session_id=? AND user_message IS NOT NULL "
        "AND TRIM(user_message)<>'' ORDER BY turn_index LIMIT 1",
        (sid,),
    ).fetchone()
    if not r:
        return ""
    return re.sub(r"\s+", " ", r["user_message"]).strip()[:280]


def user_asks(con, sid, limit=10):
    rows = con.execute(
        "SELECT user_message FROM turns WHERE session_id=? AND user_message IS NOT NULL "
        "AND TRIM(user_message)<>'' ORDER BY turn_index LIMIT ?",
        (sid, limit),
    ).fetchall()
    out = []
    for r in rows:
        m = re.sub(r"\[image:[^\]]*\]", "", r["user_message"])
        m = re.sub(r"\s+", " ", m).strip()
        if m:
            out.append(m[:160])
    return out


def latest_checkpoint(con, sid):
    return con.execute(
        "SELECT overview, work_done, next_steps FROM checkpoints "
        "WHERE session_id=? ORDER BY checkpoint_number DESC LIMIT 1",
        (sid,),
    ).fetchone()


def files_touched(con, sid, limit=30):
    rows = con.execute(
        "SELECT file_path, tool_name FROM session_files WHERE session_id=? ORDER BY first_seen_at",
        (sid,),
    ).fetchall()
    return [(r["file_path"], r["tool_name"] or "") for r in rows][:limit], len(rows)


def refs(con, sid):
    rows = con.execute(
        "SELECT ref_type, ref_value FROM session_refs WHERE session_id=? ORDER BY ref_type",
        (sid,),
    ).fetchall()
    return [(r["ref_type"], r["ref_value"]) for r in rows]


def cmd_list(con, scope, want_all, limit):
    where = "" if want_all else "WHERE s.cwd LIKE ?"
    args = [] if want_all else [f"%{scope}%"]
    rows = con.execute(
        f"""
        SELECT s.id, s.cwd, s.summary, s.updated_at,
               (SELECT COUNT(*) FROM turns t WHERE t.session_id = s.id) AS turns
        FROM sessions s
        {where}
        ORDER BY s.updated_at DESC
        LIMIT ?
        """,
        args + [limit],
    ).fetchall()
    if not rows:
        print("No sessions found.")
        return 0
    print(f"{'id':10} {'date':11} {'turns':>5}  summary / cwd")
    print("-" * 72)
    for r in rows:
        summ = r["summary"] or (Path(r["cwd"]).name if r["cwd"] else "")
        print(f"{r['id'][:8]:10} {to_date(r['updated_at']):11} {r['turns']:>5}  {summ[:44]}")
    print("\nRun: session_digest.py show <id-prefix>")
    return 0


def resolve_id(con, prefix):
    rows = con.execute(
        "SELECT id FROM sessions WHERE id LIKE ? ORDER BY updated_at DESC",
        (prefix + "%",),
    ).fetchall()
    return [r["id"] for r in rows]


def cmd_show(con, prefix):
    ids = resolve_id(con, prefix)
    if not ids:
        print(f"No session matches prefix '{prefix}'.", file=sys.stderr)
        return 1
    if len(ids) > 1:
        print(f"Prefix '{prefix}' is ambiguous ({len(ids)} matches): "
              + ", ".join(i[:8] for i in ids[:8]), file=sys.stderr)
        return 1
    sid = ids[0]
    s = con.execute(
        "SELECT id, cwd, repository, branch, summary, created_at, updated_at, "
        "(SELECT COUNT(*) FROM turns t WHERE t.session_id=sessions.id) AS turns "
        "FROM sessions WHERE id=?",
        (sid,),
    ).fetchone()

    title = s["summary"] or first_user_ask(con, sid)[:60] or f"Session {sid[:8]}"
    cp = latest_checkpoint(con, sid)
    fls, fcount = files_touched(con, sid)
    rfs = refs(con, sid)

    out = [f"# {title}", ""]
    meta = []
    if s["repository"]:
        meta.append(f"Repo: `{s['repository']}`")
    if s["branch"]:
        meta.append(f"Branch: `{s['branch']}`")
    if s["cwd"]:
        meta.append(f"CWD: `{s['cwd']}`")
    meta.append(f"Date: {to_date(s['updated_at'])}  \u00b7  Turns: {s['turns']}  \u00b7  "
                f"Tool: {TOOL}  \u00b7  Session `{sid[:8]}`")
    out.append("  \n".join(meta))
    out.append("")

    if cp and (cp["overview"] or cp["work_done"]):
        if cp["overview"]:
            out += ["## Overview", cp["overview"].strip(), ""]
        if cp["work_done"]:
            out += ["## Work done", cp["work_done"].strip(), ""]
        if cp["next_steps"]:
            out += ["## Next steps", cp["next_steps"].strip(), ""]
    else:
        asks = user_asks(con, sid)
        if asks:
            out += ["## What was asked"] + [f"- {a}" for a in asks] + [""]

    if fls:
        out += ["## Files touched" + (f" ({fcount})" if fcount > len(fls) else "")]
        out += [f"- `{p}`" + (f" ({t})" if t else "") for p, t in fls] + [""]
    if rfs:
        out += ["## References"] + [f"- {rt}: {rv}" for rt, rv in rfs] + [""]

    print("\n".join(out).rstrip())
    return 0


def main():
    ap = argparse.ArgumentParser(description="On-demand digest of a chosen AI session.")
    ap.add_argument("--db", default=str(DEFAULT_DB))
    sub = ap.add_subparsers(dest="cmd")

    pl = sub.add_parser("list", help="list recent sessions")
    pl.add_argument("--scope", default="")
    pl.add_argument("--all", action="store_true")
    pl.add_argument("--limit", type=int, default=20)

    ps = sub.add_parser("show", help="print a session's digest")
    ps.add_argument("session_id")

    args = ap.parse_args()
    db = Path(args.db).expanduser()
    if not db.exists():
        print(f"session store not found: {db}", file=sys.stderr)
        return 1
    con = connect_ro(db)

    if args.cmd == "show":
        return cmd_show(con, args.session_id)
    scope = getattr(args, "scope", "")
    want_all = getattr(args, "all", False) or not scope
    return cmd_list(con, scope, want_all, getattr(args, "limit", 20))


if __name__ == "__main__":
    raise SystemExit(main())
