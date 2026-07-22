#!/usr/bin/env bash
# Harness for vault_sync/check_vault against a throwaway repo + bare remote.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source lib/core.sh; source lib/platform.sh; source lib/tui.sh; source lib/vault.sh

work=$(mktemp -d -p "$HOME/.cache")
trap 'rm -rf "$work"' EXIT
export STATE_DIR="$work/state"; mkdir -p "$STATE_DIR"
STATUS_FILE="$STATE_DIR/status"

# fake vault: local clone tracking a bare remote
git init -q --bare "$work/remote.git"
git clone -q "$work/remote.git" "$work/vault" 2>/dev/null
git -C "$work/vault" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
git -C "$work/vault" push -q -u origin main 2>/dev/null || git -C "$work/vault" push -q -u origin master

# point the lib at the fake (override the profile-based resolver + identity)
vault_dir() { echo "$work/vault"; }
profile_get() { echo mac-personal; }
git -C "$work/vault" config user.email t@t; git -C "$work/vault" config user.name t

pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass+1)); echo "  ok: $1"; else fail=$((fail+1)); echo "  FAIL: $1 (want '$2' got '$3')"; fi }

# 1. dirty tree -> checkpoint commit + push
echo "note" > "$work/vault/inbox.md"
vault_sync --force
check "dirty -> checkpointed" "0" "$(git -C "$work/vault" status --porcelain | wc -l | tr -d ' ')"
check "dirty -> pushed" "0" "$(git -C "$work/vault" rev-list --count @{u}..HEAD)"

# 2. throttle: second run within the hour is a no-op (no --force)
echo "more" >> "$work/vault/inbox.md"
vault_sync
check "throttled run leaves tree dirty" "1" "$(git -C "$work/vault" status --porcelain | wc -l | tr -d ' ')"
git -C "$work/vault" checkout -q -- inbox.md

# 3. behind remote -> pull brings it current
git clone -q "$work/remote.git" "$work/other"
git -C "$work/other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "robot pr merge"
git -C "$work/other" push -q
vault_sync --force
check "behind -> pulled" "0" "$(git -C "$work/vault" rev-list --count HEAD..@{u})"

# 4. doctor: fresh commit -> no heartbeat warning; backdated -> warning
out=$(check_vault 2>&1); check "fresh heartbeat quiet" "" "$(grep -o 'sync bridge silent' <<<"$out")"
GIT_COMMITTER_DATE="2026-07-01T00:00:00" git -C "$work/vault" -c user.email=t@t -c user.name=t commit -q --allow-empty --date="2026-07-01T00:00:00" -m old
out=$(check_vault 2>&1); check "stale heartbeat warns" "sync bridge silent" "$(grep -o 'sync bridge silent' <<<"$out")"

echo; echo "passed: $pass  failed: $fail"
exit $((fail > 0))
