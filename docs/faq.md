# FAQ

**Where does my data go?**
Nowhere but between your RootPilot container, your own hosts (over SSH), and the LLM API you point it at with your own key. There is no RootPilot-hosted middleman and no telemetry. See [security.md](security.md).

**Which LLM models are supported?**
Bring your own key. RootPilot works with mainstream LLM APIs; you choose the provider and model, and the cost is billed to your account, not ours.

**Can RootPilot change or break my server?**
No. It runs only a fixed set of read-only inspection commands — there is no arbitrary-command feature, not even behind a confirmation. The full 38-command whitelist is in [security.md](security.md).

**Does it need an agent on each server?**
No. Target servers only need to accept your SSH connection. RootPilot itself is the only thing you install, and it runs on one machine.

**How is this different from Prometheus / Grafana / Datadog?**
Monitoring tells you a metric crossed a threshold. RootPilot picks up from there and explains *why* — it collects evidence from the affected host and produces a root-cause report. It can read your Prometheus for trend context, but it complements monitoring rather than replacing it.

**Is there a 2FA / login on the console?**
The console binds to `127.0.0.1` only and is meant to be reached over an SSH tunnel or behind your own authenticated reverse proxy — that is the access-control boundary. Do not expose port 18081 directly to the internet.

**How accurate is it, really?**
On the current calibration set: **89.7% root-cause accuracy across 29 standard failure scenarios, with zero false alarms on healthy hosts** — using 38 read-only commands. Accuracy depends on the model you bring and how much evidence the host exposes. The full scenario list, rubric, and per-scenario results (misses included) are in [calibration.md](calibration.md), and the scenario library keeps expanding.

**How do I import a license?**
Paste the license string on the console's license page. Free needs no license; Pro/Max licenses come from [rootpilotx.com](https://rootpilotx.com). The license is verified locally — no license-server call is required to run.

**What are the resource requirements?**
Docker 20.10+, Docker Compose v2, and about 2 GB of free memory for the app + MySQL. It runs comfortably on a small VM.

**Something failed and RootPilot got it wrong. What now?**
Open an issue with the (redacted) evidence and what the real cause turned out to be. Genuine misses become calibration cases — that is literally how the accuracy number improves.
