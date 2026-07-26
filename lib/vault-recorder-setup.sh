#!/usr/bin/env bash
# vault-recorder-setup.sh — provision THIS machine as the arnievault
# recorder (see config/vault.conf + the vault's vault-automation.md).
# Run with sudo, idempotent: safe to re-run until every step reports ok.
#
#   sudo bash ~/code/dotfiles/lib/vault-recorder-setup.sh
#
# What it sets up:
#   - `obsidian` system user (owns the live vault; agents cannot write it)
#   - /srv/arnievault  (owner obsidian, group arnie, group-read-only)
#   - Obsidian Linux build + CLI (headless Sync peer)
#   - write deploy key for the obsidian user, registered on the repo
#   - systemd: obsidian-sync.service + vault-recorder.{service,timer}
#   - /usr/local/bin/{vault-recorder,vault-note-helper} + scoped sudoers
# One MANUAL step remains at the end: signing the headless client into the
# Obsidian account (printed with instructions).
set -uo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

DOTFILES=${DOTFILES:-/home/arnie/code/dotfiles}
VAULT=/srv/arnievault
REPO_SSH="git@github-arnievault:arnoldsandoval/arnievault.git"
OWNER_USER=arnie
step() { printf '\n\033[35m== %s\033[0m\n' "$*"; }
ok()   { printf '\033[32mok\033[0m %s\n' "$*"; }

step "1/8 obsidian system user"
if ! id obsidian >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/obsidian --shell /usr/sbin/nologin obsidian
fi
ok "user obsidian ($(id obsidian | cut -d' ' -f1))"

step "2/8 vault directory (obsidian-owned, group-readable to $OWNER_USER)"
mkdir -p "$VAULT"
chown obsidian:"$OWNER_USER" "$VAULT"
chmod 750 "$VAULT"
if command -v setfacl >/dev/null 2>&1 || apt-get install -y acl >/dev/null 2>&1; then
  setfacl -R -m g:"$OWNER_USER":rX "$VAULT"
  setfacl -R -d -m g:"$OWNER_USER":rX "$VAULT"   # new files stay group-readable
  ok "$VAULT with default ACLs (agents read, never write)"
else
  ok "$VAULT (750; install 'acl' later so new files stay group-readable)"
fi

step "3/8 node.js 22+ and the obsidian-headless CLI (ob)"
# The recorder is a headless Sync PEER via the OFFICIAL obsidian-headless npm
# CLI (`ob`) — github.com/obsidianmd/obsidian-headless, shipped 2026-02 — NOT
# the desktop GUI (no display here) and NOT any `obsidian --headless` flag.
# It needs Node 22+, installed system-wide (/usr/local) so the `obsidian`
# service user and systemd can both run it off the default PATH.
node_major() { command -v node >/dev/null 2>&1 && node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }
if [[ $(node_major) -lt 22 ]]; then
  echo "installing Node.js 22 (system-wide, /usr/local)…"
  case "$(uname -m)" in x86_64) narch=x64;; aarch64) narch=arm64;; *) narch="";; esac
  if [[ -n $narch ]]; then
    # resolve the exact latest-v22 tarball from SHASUMS (capture-then-slice,
    # never `grep | head` on a live pipe — SIGPIPE-under-pipefail is banned)
    sums=$(curl -fsSL https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt 2>/dev/null) || sums=""
    tarball=$(grep -oE "node-v22\.[0-9]+\.[0-9]+-linux-$narch\.tar\.xz" <<<"$sums")
    tarball=${tarball%%$'\n'*}
    if [[ -n $tarball ]]; then
      curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/latest-v22.x/$tarball" \
        && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
        && rm -f /tmp/node.tar.xz \
        && hash -r
    else
      echo "!! could not resolve a Node 22 tarball — install Node 22+ manually, then re-run"
    fi
  else
    echo "!! unsupported arch $(uname -m) for auto Node install — install Node 22+ manually, then re-run"
  fi
fi
if [[ $(node_major) -ge 22 ]] && ! command -v ob >/dev/null 2>&1; then
  npm install -g obsidian-headless >/dev/null 2>&1 || echo "!! 'npm install -g obsidian-headless' failed"
fi
if command -v ob >/dev/null 2>&1; then
  ok "obsidian-headless present ($(command -v ob), node $(node --version 2>/dev/null))"
else
  echo "!! obsidian-headless (ob) still missing — need Node 22+ then 'npm install -g obsidian-headless'"
fi

step "4/8 deploy key for the obsidian user (write access, this repo only)"
KEY=/var/lib/obsidian/.ssh/arnievault_deploy
if [[ ! -f $KEY ]]; then
  sudo -u obsidian mkdir -p /var/lib/obsidian/.ssh
  sudo -u obsidian ssh-keygen -q -t ed25519 -N "" -C "vault-recorder@$(hostname -s)" -f "$KEY"
  sudo -u obsidian tee /var/lib/obsidian/.ssh/config >/dev/null <<EOF
Host github-arnievault
  HostName github.com
  User git
  IdentityFile $KEY
  IdentitiesOnly yes
EOF
fi
if sudo -H -u "$OWNER_USER" gh api repos/arnoldsandoval/arnievault/keys --jq '.[].title' 2>/dev/null | grep -q "vault-recorder@$(hostname -s)"; then
  ok "deploy key already registered"
else
  sudo -H -u "$OWNER_USER" gh api repos/arnoldsandoval/arnievault/keys \
    -f title="vault-recorder@$(hostname -s)" -f key="$(cat "$KEY.pub")" -F read_only=false >/dev/null \
    && ok "deploy key registered (write, repo-scoped)" \
    || { echo "!! deploy key registration failed — add $KEY.pub manually at github.com/arnoldsandoval/arnievault/settings/keys"; echo "   pub key: $(cat "$KEY.pub")"; }
fi

step "5/8 clone the vault as obsidian (git plane; Sync attaches to the same dir)"
if [[ ! -d $VAULT/.git ]]; then
  # a failed earlier run may have removed the dir — re-assert it first, then
  # clone INTO it (git clones into an existing empty dir fine; never rmdir)
  mkdir -p "$VAULT"; chown obsidian:"$OWNER_USER" "$VAULT"; chmod 750 "$VAULT"
  sudo -u obsidian git clone "$REPO_SSH" "$VAULT" \
    || echo "!! clone failed — usually the deploy key (step 4) isn't registered yet; fix that and re-run"
fi
sudo -u obsidian git -C "$VAULT" config user.name "vault-recorder"
sudo -u obsidian git -C "$VAULT" config user.email "vault-recorder@$(hostname -s)"
[[ -d $VAULT/.git ]] && ok "vault clone in place" || echo "!! clone failed (deploy key not yet accepted?)"

step "6/8 recorder + note-helper binaries"
install -m 755 "$DOTFILES/bin/vault-recorder" /usr/local/bin/vault-recorder
cat > /usr/local/bin/vault-note-helper <<'EOF'
#!/usr/bin/env bash
# Append a timestamped bullet to today's daily note in the live vault.
# Runs as the obsidian user (via the scoped sudoers rule) — the only
# sanctioned direct-write path for humans on the recorder machine.
set -uo pipefail
V=${VAULT_PATH:-/srv/arnievault}
text=$*
[[ -n $text ]] || { echo "usage: vault-note-helper <text>"; exit 1; }
f="$V/$(date +%F).md"
[[ -f $f ]] || printf '# %s\n' "$(date +%F)" > "$f"
printf -- '- %s — %s\n' "$(date +%H:%M)" "$text" >> "$f"
EOF
chmod 755 /usr/local/bin/vault-note-helper
printf '%s ALL=(obsidian) NOPASSWD: /usr/local/bin/vault-note-helper\n' "$OWNER_USER" > /etc/sudoers.d/vault-note
chmod 440 /etc/sudoers.d/vault-note
ok "binaries + scoped sudoers installed"

step "7/8 systemd units"
install -m 644 "$DOTFILES/services/systemd/obsidian-sync.service" /etc/systemd/system/
install -m 644 "$DOTFILES/services/systemd/vault-recorder.service" /etc/systemd/system/
install -m 644 "$DOTFILES/services/systemd/vault-recorder.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now vault-recorder.timer >/dev/null 2>&1 && ok "capture timer enabled (10 min)"
systemctl enable obsidian-sync.service >/dev/null 2>&1 && ok "sync daemon enabled (starts after login step)"

step "8/8 MANUAL: sign the headless client into Obsidian Sync"
cat <<EOF
Remaining one-time step (needs your Obsidian account + an active Sync plan).
Run everything as the obsidian user with -H so credentials land in the home
the daemon reads (/var/lib/obsidian):

  1. Check your Sync device list first (Settings → Sync on a mac) and remove a
     stale device if you are at the limit — the recorder is a new device.
  2. Log in and attach the remote vault to the already-cloned /srv/arnievault:
       sudo -u obsidian -H ob login                 # email, password, 2FA if enabled
       sudo -u obsidian -H ob sync-list-remote       # note the exact vault name
       sudo -u obsidian -H ob sync-setup --vault "arnievault" --path $VAULT \\
            --device-name vault-recorder-$(hostname -s)
     If the vault is END-TO-END ENCRYPTED, append  --password '<e2ee password>'
     to the sync-setup line (it is required for E2EE vaults).
  3. Start the daemon and check it:
       systemctl start obsidian-sync.service
       sudo -u obsidian -H ob sync-status --path $VAULT
  4. Watch $VAULT populate, then: dotfiles doctor
Until then, doctor will report the sync daemon down — the git plane
(pull/checkpoint/push of robot PRs + manual edits) already works.
EOF
