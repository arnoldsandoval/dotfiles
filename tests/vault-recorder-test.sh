#!/usr/bin/env bash
# Harness for the recorder role: vault_role resolution matrix, the
# bin/vault-recorder capture cycle against a fake repo + bare remote, and
# the mode-bit enforcement claim (agents can't write a group-read-only dir).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO=$PWD
source lib/core.sh; source lib/platform.sh; source lib/tui.sh; source lib/vault.sh

work=$(mktemp -d -p "$HOME/.cache")
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT
export STATE_DIR="$work/state"; mkdir -p "$STATE_DIR"

pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass+1)); echo "  ok: $1"; else fail=$((fail+1)); echo "  FAIL: $1 (want '$2' got '$3')"; fi }

# --- 1. vault_role matrix (conf × profile × hostname via overrides) ---
REC="" PROF="" HOSTN=""
vault_conf() { case $1 in recorder) echo "$REC" ;; *) echo "" ;; esac; }
profile_get() { echo "$PROF"; }
hostname() { echo "$HOSTN"; }

REC=box1 HOSTN=box1 PROF=vm
check "declared host -> recorder" "recorder" "$(vault_role)"
REC=box1 HOSTN=box2 PROF=vm
check "other vm -> reader" "reader" "$(vault_role)"
REC=box1 HOSTN=mac PROF=mac-personal
check "mac, role elsewhere -> sync-device" "sync-device" "$(vault_role)"
REC=mymac HOSTN=mymac PROF=mac-personal
check "mac holding role -> recorder (fallback)" "recorder" "$(vault_role)"
REC="" HOSTN=box2 PROF=vm
check "no declaration, vm -> reader" "reader" "$(vault_role)"
REC="" HOSTN=x PROF=mystery
check "unknown profile -> none" "none" "$(vault_role)"

# --- 2. bin/vault-recorder capture cycle ---
git init -q --bare "$work/remote.git"
git clone -q "$work/remote.git" "$work/srv" 2>/dev/null
git -C "$work/srv" config user.email r@t; git -C "$work/srv" config user.name recorder
git -C "$work/srv" commit -q --allow-empty -m seed
git -C "$work/srv" push -q -u origin main 2>/dev/null || git -C "$work/srv" push -q -u origin master
recorder() { VAULT_PATH="$work/srv" "$REPO/bin/vault-recorder"; }

# dirty tree -> checkpoint commit + push
echo "phone edit via sync" > "$work/srv/inbox.md"
recorder >/dev/null
check "dirty -> checkpointed" "0" "$(git -C "$work/srv" status --porcelain | wc -l | tr -d ' ')"
check "dirty -> pushed" "0" "$(git -C "$work/srv" rev-list --count @{u}..HEAD)"
check "checkpoint message" "1" "$(git -C "$work/srv" log -1 --format=%s | grep -c 'vault checkpoint: recorder')"

# behind remote (merged robot PR) -> pulled current
git clone -q "$work/remote.git" "$work/other"
git -C "$work/other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "robot pr merge"
git -C "$work/other" push -q
recorder >/dev/null
check "behind -> pulled" "0" "$(git -C "$work/srv" rev-list --count HEAD..@{u})"

# diverged -> refuses quietly, exit 0 (timer must not enter failed state)
git -C "$work/other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m remote-side
git -C "$work/other" push -q
git -C "$work/srv" commit -q --allow-empty -m local-side
out=$(recorder); rc=$?
check "diverged -> exit 0" "0" "$rc"
check "diverged -> flagged" "1" "$(grep -c 'pull failed' <<<"$out")"
git -C "$work/srv" reset -q --hard @{u}   # heal for anything after

# --- 3. mode-bit enforcement: no write bit => writes rejected ---
mkdir -p "$work/locked"; echo hi > "$work/locked/note.md"; chmod 555 "$work/locked"
if { echo nope > "$work/locked/new.md"; } 2>/dev/null; then wrote=yes; else wrote=no; fi
check "read-only dir rejects new files" "no" "$wrote"
check "existing files still readable" "hi" "$(cat "$work/locked/note.md")"

echo; echo "passed: $pass  failed: $fail"
exit $((fail > 0))
