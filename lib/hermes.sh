# hermes.sh — local inference host: LM Studio + a served model, gated to one
# machine by config/hermes.conf. Everything is a no-op elsewhere.
# shellcheck shell=bash

hermes_conf() { sed -n "s/^$1=//p" "$DOTFILES/config/hermes.conf" 2>/dev/null | head -1; }

# hermes_is_host -> 0 when this machine is the declared inference host.
hermes_is_host() {
  local h; h=$(hermes_conf host)
  [[ -n $h && $(hostname -s 2>/dev/null || hostname) == "$h" ]]
}

# The lms CLI ships inside LM Studio and is bootstrapped into ~/.lmstudio/bin.
hermes_lms() {
  local c; c=$(command -v lms 2>/dev/null)
  [[ -n $c ]] && { echo "$c"; return 0; }
  [[ -x $HOME/.lmstudio/bin/lms ]] && { echo "$HOME/.lmstudio/bin/lms"; return 0; }
  return 1
}

# hermes_doctor — drift the user cannot see: a missing model, a dead server,
# an unraised GPU ceiling, or a hook declared but not wired into the runner.
hermes_doctor() {
  hermes_is_host || return 0
  local lms; lms=$(hermes_lms) || { echo "hermes: lms CLI not found (open LM Studio once, then 'lms bootstrap')"; return 0; }

  "$lms" ls 2>/dev/null | grep -qF "$(hermes_conf model)" \
    || echo "hermes: model $(hermes_conf model) not downloaded"

  curl -sf --max-time 2 http://localhost:1234/v1/models >/dev/null 2>&1 \
    || echo "hermes: inference server not responding on :1234"

  # Only a problem if the ceiling was lowered below what the model needs. 0 means
  # the macOS default (~75% of RAM, ~27GB here), which clears the measured 22.4GiB
  # peak — so do not nag about the default, only about a too-small explicit cap.
  local have; have=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null)
  [[ ${have:-0} -eq 0 || ${have:-0} -ge 26000 ]] \
    || echo "hermes: iogpu.wired_limit_mb capped at ${have}MB, below the 22.4GiB the model needs"

  # On AC this box must never sleep: it serves the assistant and hosts the CI
  # runner. Note `displaysleep 0` masks this — powerd holds a "display is on"
  # assertion that vanishes the moment the lid closes, and then `sleep` applies.
  local acsleep
  acsleep=$(pmset -g custom 2>/dev/null | sed -n '/AC Power/,$p' | awk '/^ sleep /{print $2; exit}')
  [[ ${acsleep:-1} -eq 0 ]] \
    || echo "hermes: AC sleep is ${acsleep:-?} min, want 0 (sudo pmset -c sleep 0) — machine unreachable if it sleeps"

  if [[ $(hermes_conf evict_on_ci) == true ]]; then
    grep -q 'ACTIONS_RUNNER_HOOK_JOB_STARTED' "$HOME/actions-runner/.env" 2>/dev/null \
      || echo "hermes: evict_on_ci=true but no runner hook in ~/actions-runner/.env"
  fi
}
