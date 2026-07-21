#!/usr/bin/env bash
set -euo pipefail

preset="${PRESET:-b0}"
base="${BASE:-base}"
template="${TEMPLATE:-next}"
bare=0
name=""
image="oven/bun"

while [ $# -gt 0 ]; do
  case "$1" in
    --bare) bare=1; shift ;;
    --image) image="$2"; shift 2 ;;
    -*) echo "unknown option: $1" >&2; exit 1 ;;
    *) name="$1"; shift ;;
  esac
done

[ -n "$name" ] || { echo "usage: new-project <name> [--bare] [--image <docker-image>]" >&2; exit 1; }
printf '%s' "$name" | grep -qE '^[a-z0-9-]+$' || { echo "error: name must be lowercase letters, numbers, hyphens only" >&2; exit 1; }

code_dir="${CODE_DIR:-$HOME/code}"
proj="$code_dir/$name"
[ -e "$proj" ] && { echo "error: $proj already exists" >&2; exit 1; }

used="$(grep -hoE '127\.0\.0\.1:[0-9]+:[0-9]+' "$code_dir"/*/compose.yaml 2>/dev/null | sed -E 's/.*:([0-9]+):[0-9]+$/\1/' || true)"
next_free() { local p="$1"; while printf '%s\n' "$used" | grep -qx "$p"; do p=$((p+1)); done; printf '%s' "$p"; }
web="$(next_free 3001)"; used="$used
$web"; db="$(next_free 5433)"

mkdir -p "$code_dir"

if [ "$bare" -eq 0 ]; then
  ( cd "$code_dir" && bunx --bun shadcn@latest init --name "$name" --preset "$preset" --base "$base" --template "$template" --monorepo )
  app_image="oven/bun"
  vols=$'      - .:/workspace\n      - node_modules:/workspace/node_modules'
  named=$'\n  node_modules:'
else
  mkdir -p "$proj"
  app_image="$image"
  vols=$'      - .:/workspace'
  named=''
fi

cd "$proj"

cat > compose.yaml <<EOF
name: $name
services:
  app:
    build: .
    working_dir: /workspace
    volumes:
$vols
    command: sleep infinity
    ports:
      - "127.0.0.1:$web:3000"
    depends_on: [db]
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: $name
    ports:
      - "127.0.0.1:$db:5432"
    volumes:
      - db-data:/var/lib/postgresql/data
volumes:
  db-data:$named
EOF

cat > Dockerfile <<EOF
FROM $app_image
WORKDIR /workspace
EOF

if [ "$bare" -eq 0 ]; then
  cat > CLAUDE.md <<EOF
# $name

bun + shadcn Next.js monorepo (apps/web + packages/ui, Turborepo). Run commands in the \`app\` container:
- Install:  docker compose exec app bun install
- Dev:      docker compose exec app bun run dev -- -H 0.0.0.0   (bind 0.0.0.0 inside the container; host port $web)
- Add UI:   docker compose exec app bunx --bun shadcn@latest add <component> -c apps/web

View in browser, private over Tailscale: \`sudo tailscale serve $web\`, then open the printed https://<box-name>.<tailnet>.ts.net URL. The port is bound to host localhost, so use serve rather than hitting the port directly.

Postgres is the \`db\` service: from \`app\` at db:5432, from the box at localhost:$db.
First run: docker compose up -d, then docker compose exec app bun install.
For shadcn specifics, use the shadcn skill.
EOF
else
  cat > CLAUDE.md <<EOF
# $name

Container-only project (base image: $image). Add your toolchain to the Dockerfile, then run commands in the \`app\` container:
- e.g. docker compose exec app <your-command>   (host port $web; bind any web server to 0.0.0.0 inside the container)

View in browser, private over Tailscale: \`sudo tailscale serve $web\`, then open the printed https://<box-name>.<tailnet>.ts.net URL.

Postgres is the \`db\` service: from \`app\` at db:5432, from the box at localhost:$db.
Stack up: docker compose up -d
EOF
fi

[ -d .git ] || git init -q
grep -qxF 'node_modules/' .gitignore 2>/dev/null || echo 'node_modules/' >> .gitignore
git add -A && git commit -qm "add container layer for $name" || true

echo "Created $proj"
echo "  app -> host port $web"
echo "  db  -> host port $db"
