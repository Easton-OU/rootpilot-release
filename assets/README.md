# assets/

Images referenced by the root `README.md`. Add these before the repo goes public.

| file | what it should show | requirements |
|---|---|---|
| `logo.png` | RootPilot mark (🍊 fruit logo) | square, ~144×144, transparent background |
| `report.png` | A diagnosis report: root cause + evidence chain + suggested commands | **English UI**, fully desensitized (no real IPs, domains, hostnames, or credentials), width ~1500px |

Desensitization checklist for screenshots:
- Replace real hostnames/IPs with placeholders (`prod-1`, `10.0.0.5`).
- No real domains, no license strings, no API keys.
- Use the English locale build of the console.

Until `logo.png` and `report.png` are added, the README image links will show broken-image placeholders on GitHub. That is expected for the first commit; swap them in before announcing the repo (see `MANUAL-RELEASE.md`).
