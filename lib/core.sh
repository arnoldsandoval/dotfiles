# core.sh — logging, state paths, small helpers. Sourced by everything.
# shellcheck shell=bash

# Repo root: every entry point sets DOTFILES before sourcing lib; fall back to
# resolving from this file's location for direct `bash -c 'source lib/core.sh'` use.
: "${DOTFILES:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export DOTFILES

STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles"
PROFILE_FILE="$STATE_DIR/profile"
STATUS_FILE="$STATE_DIR/status"
BACKUP_ROOT="$STATE_DIR/backups"

# Colors only when stdout is a tty.
if [[ -t 1 || -t 2 ]]; then
  C_RED=$'\e[31m' C_GRN=$'\e[32m' C_YLW=$'\e[33m' C_BLU=$'\e[34m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'
  C_MAG=$'\e[35m' C_BLD=$'\e[1m'
else
  C_RED='' C_GRN='' C_YLW='' C_BLU='' C_DIM='' C_OFF='' C_MAG='' C_BLD=''
fi

log()  { printf '%s\n' "${C_BLU}::${C_OFF} $*"; }
ok()   { printf '%s\n' "${C_GRN}ok${C_OFF} $*"; }
warn() { printf '%s\n' "${C_YLW}!!${C_OFF} $*" >&2; }
err()  { printf '%s\n' "${C_RED}ERR${C_OFF} $*" >&2; }
die()  { err "$*"; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

ensure_state_dir() { mkdir -p "$STATE_DIR"; }

# Read a key=value from the status file (empty if absent).
status_get() { [[ -f $STATUS_FILE ]] && sed -n "s/^$1=//p" "$STATUS_FILE" | head -1 || true; }

# Upsert key=value into the status file.
status_set() {
  ensure_state_dir
  local key=$1 val=$2 tmp
  tmp=$(mktemp)
  [[ -f $STATUS_FILE ]] && grep -v "^$key=" "$STATUS_FILE" >"$tmp" || true
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$STATUS_FILE"
}
