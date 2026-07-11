# Deployment & access guide

## Where to run RootPilot

Run RootPilot on a machine that can reach the servers you want to diagnose over SSH:

- **Your laptop / workstation** — simplest. Reaches hosts over your normal SSH access.
- **A small ops/bastion VM** — good if your servers are only reachable from inside a network. Run RootPilot there and tunnel in.

RootPilot needs Docker; the servers it diagnoses do **not** — there is no agent to install on them. They only need to accept your SSH connection.

## Install

Requirements: **Docker 20.10+**, **Docker Compose v2** (`docker compose`), ~2 GB free memory.

### One command

```bash
# Linux / macOS
curl -fsSL https://rootpilotx.com/install.sh | sh
```

```powershell
# Windows PowerShell
irm https://rootpilotx.com/install.ps1 | iex
```

The installer downloads the compose file, generates `DB_PASSWORD` and `ROOTPILOT_ENCRYPT_KEY` into `.env` on first run (and reuses them afterward), then starts the stack.

### Manual (compose)

```bash
curl -fsSLO https://raw.githubusercontent.com/Easton-OU/rootpilot-release/main/docker-compose.yml
curl -fsSLO https://raw.githubusercontent.com/Easton-OU/rootpilot-release/main/.env.example
cp .env.example .env
# set DB_PASSWORD and ROOTPILOT_ENCRYPT_KEY (see comments in .env)
docker compose up -d
```

## Accessing the console

The console **binds to `127.0.0.1` only** and has no separate login, so it is never exposed to the internet by default.

- **Local install:** open `http://localhost:18081`.
- **Remote install:** tunnel over SSH from your laptop:

  ```bash
  ssh -L 18081:localhost:18081 user@your-rootpilot-host
  # then open http://localhost:18081 locally
  ```

- **Want a permanent URL?** Put RootPilot behind your own reverse proxy (nginx/Caddy/Traefik) **with authentication** and TLS. Do not publish port 18081 directly.

## Connecting target hosts (credentials)

In the console, add each server you want to diagnose:

- **Prefer a dedicated, least-privilege SSH user** for diagnostics rather than root. The whitelist is read-only, but the account should reflect that intent. A key-based login is recommended over a password.
- Credentials are encrypted at rest with AES-256-GCM (`ROOTPILOT_ENCRYPT_KEY`). Keep that key stable — see [security.md](security.md).
- Some commands read more with elevated rights (`dmesg`, `iptables`, full `journalctl`). RootPilot degrades gracefully when a command is not permitted; grant passwordless read-only sudo for those only if you want the extra evidence.

## Multiple hosts

Add as many hosts as your edition allows (Free: 1; Pro: 2–10). Each host keeps its own history. When an alert fires (or you ask), RootPilot diagnoses the specific host involved.

## Jump hosts / bastions

If a target is only reachable through a bastion, give the RootPilot machine transparent access via your SSH config, then add the target by its internal address:

```
# ~/.ssh/config on the RootPilot host
Host internal-db
  HostName 10.0.0.5
  User ops
  ProxyJump bastion.example.com
```

RootPilot uses the resulting connection like any other. (Native in-app jump-host configuration is on the roadmap.)

## Upgrades & maintenance

```bash
cd ~/rootpilot            # wherever your compose + .env live
docker compose pull
docker compose up -d
```

Stop:

```bash
docker compose down       # add -v only if you also want to drop the MySQL volume
```

Back up: your `.env` (especially `ROOTPILOT_ENCRYPT_KEY`) and the `mysql-data` volume. Losing the encryption key means re-adding host credentials.

## Optional: Prometheus context

Set `ROOTPILOT_PROMETHEUS_URL` in `.env` (e.g. `http://prometheus:9090`) to let diagnoses include metric trends for the incident window. Leave it empty to skip metrics entirely.
