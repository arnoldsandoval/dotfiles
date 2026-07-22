#!/usr/bin/env bash
# Regression harness for _agent_alive / _session_mark / _enter husk logic.
# Uses fake agent binaries (scripts named claude/copilot) under real tmux
# wrapper shells — deterministic, no real agents required.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source lib/core.sh; source lib/platform.sh; source lib/tui.sh; source lib/menu-sessions.sh

fake=$(mktemp -d -p "$HOME/.cache")   # NOT /tmp: often mounted noexec
trap 'tmux kill-session -t cc-marktest 2>/dev/null; tmux kill-session -t cp-marktest 2>/dev/null; rm -rf "$fake"' EXIT
# real binaries (comm = executable basename, like the real agents). NB: not
# scripts (comm=bash) and not coreutils sleep (multi-call binary dispatches on
# argv0 and dies when renamed) — a copied bash accepts any name.
for a in claude copilot; do
  cp "$(command -v bash)" "$fake/$a"; chmod +x "$fake/$a"
done

pass=0 fail=0
check() { # check DESC EXPECTED ACTUAL
  if [[ $2 == "$3" ]]; then pass=$((pass+1)); echo "  ok: $1"
  else fail=$((fail+1)); echo "  FAIL: $1 (want '$2' got '$3')"; fi
}

# 1. active copilot as CHILD of wrapper shell (the reported bug) -> ● shown
tmux new-session -d -s cp-marktest "$fake/copilot --resume=x 2>/dev/null || $fake/copilot -c 'sleep 60; :'; exec bash"
sleep 1
check "active copilot child -> cp dot" "●" "$(_session_mark cp marktest)"

# 2. copilot exits, wrapper shell remains -> husk, no dot
tmux list-panes -t =cp-marktest -F '#{pane_pid}' >/dev/null   # session alive
pkill -f "$fake/copilot" 2>/dev/null; sleep 1
check "exited copilot, wrapper shell only -> no dot" " " "$(_session_mark cp marktest)"

# 2b. husk respawn fires for the dead agent (and ONLY then)
_agent_alive cp marktest && check "husk not alive" "dead" "alive" || check "husk not alive" "dead" "dead"

# 3. active claude -> cc dot (no regression)
tmux new-session -d -s cc-marktest "$fake/claude -c 'sleep 60; :'; exec bash"
sleep 1
check "active claude -> cc dot" "●" "$(_session_mark cc marktest)"

# 3b. live-agent protection: _enter's respawn gate must see claude as alive
_agent_alive cc marktest && check "live claude protected from respawn" "alive" "alive" \
                         || check "live claude protected from respawn" "alive" "dead"

# 4. missing session -> no dot
check "missing session -> no dot" " " "$(_session_mark cc nosuchproject)"

echo
echo "passed: $pass  failed: $fail"
exit $((fail > 0))
