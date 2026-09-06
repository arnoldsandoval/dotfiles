#!/usr/bin/env bash
# hermes-runner-hook — run by the Actions runner before each job via
# ACTIONS_RUNNER_HOOK_JOB_STARTED. Unloads the local inference model so the
# build gets the whole machine.
#
# Contract, because the runner enforces none of it: hooks have NO timeout and
# a non-zero exit FAILS the CI job. So this must be fast, idempotent, and
# always exit 0 — a broken assistant must never break a build.
set -u
exec 2>/dev/null

DOTFILES="${DOTFILES:-$HOME/code/dotfiles}"
conf() { sed -n "s/^$1=//p" "$DOTFILES/config/hermes.conf" 2>/dev/null | head -1; }

[ "$(conf evict_on_ci)" = "true" ]            || exit 0
[ "$(conf host)" = "$(hostname -s)" ]         || exit 0

LMS="$(command -v lms 2>/dev/null)"
[ -n "$LMS" ] || LMS="$HOME/.lmstudio/bin/lms"
[ -x "$LMS" ] || exit 0

# Watchdog: macOS has no timeout(1), and an lms hang would stall CI forever.
"$LMS" unload --all &
worker=$!
( sleep 20; kill -9 "$worker" 2>/dev/null ) &
watchdog=$!
wait "$worker" 2>/dev/null
kill "$watchdog" 2>/dev/null

exit 0
