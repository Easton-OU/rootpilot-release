# Changelog

All notable changes to the RootPilot release (docs + deployment) are recorded here.
This file tracks the public release artifact; the product itself is versioned by its image tags.

## v1.0.0

First public release.

- **Root-cause diagnosis** over SSH using a fixed 38-command read-only whitelist.
- **Calibrated**: 89.7% root-cause accuracy across 29 standard failure scenarios, zero false alarms on healthy hosts. Scenarios cover disk-full (including deleted-but-open files), inode exhaustion, OOM kills, container crash loops, IO saturation, connection-state floods, DNS failure, clock drift, and fd exhaustion, among others.
- **Alert-triggered auto-diagnosis** and per-host history ("medical record").
- **Bring-your-own-key** LLM integration; optional Prometheus context for metric trends.
- **Self-hosted deployment** via Docker Compose; console bound to loopback, reachable over SSH tunnel or your own reverse proxy.
- **Encrypted credentials** at rest (AES-256-GCM).
- Editions: Free (1 host), Pro (2–10 hosts), Max.

### Docs
- English deployment, security (full whitelist), and FAQ guides, with Simplified Chinese versions under `docs/zh/`.
