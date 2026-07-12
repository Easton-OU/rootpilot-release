# MANUAL-RELEASE.md — human steps to publish rootpilot-release

This repo contains only docs + deployment config (no application source). The steps below need a human (accounts, image push, screenshots).

## 1. Fill in placeholders

- [x] GitHub owner set to `Easton-OU` in `docker-compose.yml` (image ref), `README.md` (raw URLs, related repo link), and `docs/deployment.md` + `docs/zh/deployment.md` (raw URLs).
- [x] Confirm the tagline, editions table, and pricing in `README.md` match the current offer on rootpilotx.com.

## 2. Publish the image to ghcr.io

- [x] `docker login ghcr.io` with a token that has `write:packages`.
- [x] Run the publish script against the already-built product image (defaults to owner `Easton-OU`):
      ```bash
      VERSION=1.0.0 SOURCE_IMAGE=<built-image> ./scripts/publish-image.sh
      ```
- [x] Make the ghcr package **public** (ghcr package settings → change visibility).
- [x] Verify `docker pull ghcr.io/easton-ou/rootpilot:latest` works from a clean machine.

## 3. Add screenshots (English UI)

- [x] Produce `assets/logo.png` and `assets/report.png` per `assets/README.md` (English locale build, fully desensitized).
- [x] Confirm they render in the README on GitHub.

## 4. Create the GitHub repo (public)

- [x] `git init && git add . && git commit`, then push to a new **public** repo `rootpilot-release`.
- [x] Repo **About**: website `https://rootpilotx.com`; **topics**: `docker`, `devops`, `self-hosted`, `troubleshooting`, `aiops`, `sre`.
- [x] Verify README renders cleanly (tables, ASCII diagram, badges).

## 5. Cross-link

- [x] On rootpilotx.com: add a GitHub link in the site footer and on the download page.
- [x] Link the `rootpilot-mcp` repo from the README's **Related** section (already stubbed) and link back from `rootpilot-mcp`.
- [ ] Once the calibration scenario library is published, fill the "link coming" note in the README's **Tested, not vibes** section.

## 6. Self-check (verified locally)

- [x] No stray internal-port reference, no legacy `.dev` domain, no `.java` / `.vue` / prompt files anywhere in the repo.
- [x] All metrics use the latest calibration report: 38 read-only commands, 89.7% across 29 standard failure scenarios, zero false alarms.
- [x] Port is 18081 throughout; console bound to loopback.
- [ ] Final human read-through of README for tone (no marketing filler) before announcing.
