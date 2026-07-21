---
name: new-project
description: Use when the user asks to scaffold, create, bootstrap, or spin up a new project on this dev box. Default is a bun + shadcn Next.js monorepo; --bare makes a plain container-only project. Generates compose.yaml (app + Postgres), Dockerfile, and CLAUDE.md with auto-assigned host ports.
allowed-tools: Bash
---

# new-project

Scaffold a new project under `~/code`, wrapped in containers.

## Usage
    bash ~/.claude/skills/new-project/scripts/scaffold.sh <name> [--bare] [--image <docker-image>]

- `<name>`: lowercase letters, numbers, hyphens (e.g. payments-api).
- default: a bun + shadcn Next.js monorepo (apps/web + packages/ui, Turborepo).
- `--bare`: skip shadcn, just a container skeleton. Pair with `--image` for the base image (e.g. python:3.12-slim).

Ports are auto-assigned (web from 3001, Postgres from 5433), so projects never collide. Default shadcn preset is `b0`; override with the PRESET env var.

## After scaffolding
Report the assigned ports, then tell the user:
- `cd ~/code/<name> && docker compose up -d` starts the stack.
- For the monorepo, run `docker compose exec app bun install` once, then `docker compose exec app bun run dev -- -H 0.0.0.0` (bind 0.0.0.0 inside the container).
- View it in a browser with `sudo tailscale serve <web-port>`, then open the printed `https://<box-name>.<tailnet>.ts.net` URL. Ports are bound to host localhost, so use serve rather than hitting the port directly.
- Add UI with `docker compose exec app bunx --bun shadcn@latest add <component> -c apps/web`.
- For shadcn specifics, defer to the installed shadcn skill.