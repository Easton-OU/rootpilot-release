# Calibration — what "89.7%" actually means

Every accuracy number RootPilot quotes comes from one fixed benchmark: **29 failure scenarios plus 2 healthy controls**, injected for real on a real host and diagnosed through the product's normal flow. This page publishes the full scenario list, the scoring rubric, and the per-scenario results — including the scenarios we do **not** score full marks on.

> **38 read-only commands · 29 standard failure scenarios · 89.7% root-cause accuracy (26.0/29) · zero false alarms across 4 healthy-control runs.**

## Method

- **Real faults, not mocks.** Each scenario is injected on a real Ubuntu 22.04 host — real containers, loop devices, connection floods, stopped services — verified to produce its expected evidence, diagnosed, then cleaned up. No canned logs, no synthetic transcripts.
- **Rubric written before the run.** Every scenario has a pre-written expected root cause and a 1 / 0.5 / 0 grading rubric. All runs count; nothing is cherry-picked or re-rolled.
- **Product path, no hand-holding.** Diagnoses go through the standard flow — base collection → scenario-group collection → at most one follow-up round — using the same fixed [38-command read-only whitelist](security.md#5-the-full-38-command-whitelist) every user gets. No scenario-specific hints.
- **Economical default model.** All scores below were produced with DeepSeek (`deepseek-v4-flash`), the cheapest sensible default. Where it drops points, a stronger model scores higher on the same evidence (see [Where the points were lost](#where-the-points-were-lost)); BYOK means that trade-off is yours to make.
- **Healthy controls are a hard gate.** Inventing a problem on a healthy host is an automatic fail of the whole exercise. Two healthy scenarios were each run in both calibration rounds: **4/4 clean, zero false alarms.**

## Scoring rubric

| score | meaning |
|---|---|
| **1** | Root cause correct per the scenario's pre-written criteria — right mechanism, backed by the right evidence |
| **0.5** | Right direction, but the mechanism is wrong or incomplete |
| **0** | Missed or misattributed |

## The 29 scenarios

### Resources — 5.0/5

| scenario | injected fault | score |
|---|---|:---:|
| `container-oom` | Workload exceeds a hard 64 MiB memory limit; kernel cgroup OOM-killer kills the container (ExitCode 137, `OOMKilled: true`, dmesg entry) | 1 |
| `memory-leak` | Process leaks ~3 MB every 3 s until it hits the limit and is killed — graded on identifying the *leak*, not just the OOM | 1 |
| `disk-full` | A mount filled to 100%; the victim container's writes fail with "no space left" | 1 |
| `inode-exhaustion` | Inode table exhausted (IUse 100%) while byte space remains — the "disk is full but `df -h` looks fine" classic | 1 |
| `cpu-burn` | CPU-pinned process inside one container drives load up — graded on naming the source container, not just "CPU is high" | 1 |

### Container lifecycle — 5.0/5

| scenario | injected fault | score |
|---|---|:---:|
| `crashloop-badcmd` | Entrypoint binary missing; the container is created but never runs | 1 |
| `crashloop-dep` | A required dependency (`db:5432`) is unreachable; the container restart-loops | 1 |
| `port-conflict` | Host port already held by another container; the new container cannot start | 1 |
| `image-missing` | Registry hostname unresolvable; the image pull fails and the service never comes up | 1 |
| `docker-daemon-stop` | The Docker daemon itself is stopped — every container down at once; graded on blaming the daemon, not individual containers | 1 |

### Network — 3.5/4

| scenario | injected fault | score |
|---|---|:---:|
| `port-not-listening` | Application logs claim "serving on :9000" but nothing actually listens inside the container | 1 |
| `egress-blocked` | Outbound connectivity blocked; the connectivity probe fails with exit 7 | 0.5 |
| `dns-failure` | DNS resolution broken inside the container | 1 |
| `dep-unreachable` | A redis dependency has exited; the consumer's connections are refused | 1 |

### Application — 4.0/4

| scenario | injected fault | score |
|---|---|:---:|
| `app-exception` | Deterministic application bug — a division by zero at a specific file and line | 1 |
| `app-badconfig` | Misspelled config value fails validation; the container exits with code 78 in a loop | 1 |
| `db-pool-exhausted` | Connection pool at 100/100; new requests time out while the database itself is fine | 1 |
| `cert-expired` | TLS certificate expired; handshakes fail continuously | 1 |

### System — 2.0/3

| scenario | injected fault | score |
|---|---|:---:|
| `high-load` | Stress workers pin CPU near 100% — graded on naming the source | 1 |
| `service-stopped` | A critical system service (cron) is stopped; nothing *looks* broken | 0 |
| `clock-drift` | Host clock ~487 s fast; auth tokens minted "in the future" are rejected downstream | 1 |

### Compound — 3.0/3

| scenario | injected fault | score |
|---|---|:---:|
| `disk-cascade` | Disk fills → database flips to read-only → application write errors; graded on tracing the chain back to the disk | 1 |
| `oom-and-crashloop` | Two unrelated faults at once — an OOM kill and a dependency crash loop; graded on keeping them separate | 1 |
| `multi-abnormal` | Five containers restart-looping on a shared failed dependency; graded on recognising the batch pattern | 1 |

### Whitelist-expansion set — 3.5/5

Added when the collection whitelist grew from 17 to its current 38 commands, specifically to exercise the new commands.

| scenario | injected fault | score |
|---|---|:---:|
| `deleted-file-disk` | A large file is deleted but still held open by a process — `df` says full, the space is invisible to `du` | 0.5 |
| `timewait-flood` | Thousands of TIME_WAIT connections from high-churn short-lived connections | 1 |
| `fd-exhaustion` | A process exhausts its file-descriptor limit (EMFILE in logs) | 1 |
| `io-saturation` | Disk I/O saturated (iowait ~65%, `%util` ~100) *without* the disk being full | 1 |
| `docker-cache-bloat` | Docker build cache and unused images silently consuming tens of GB — with no space crisis yet | 0 |

### Healthy controls — 4/4 clean

| scenario | environment | result |
|---|---|---|
| `healthy-baseline` | Nothing wrong; old logs contain 502s that recovered days ago | Severity *info*, history correctly labelled as recovered — ×2 runs |
| `healthy-with-noise` | One container with a single old restart, stable since | Severity *info*, restart correctly labelled benign — ×2 runs |

## Where the points were lost

We publish the misses because they say more than the hits:

- **`egress-blocked` (0.5)** — the evidence *was* collected (probe exit 7); the default model rationalised it as "a restriction on the target side, not a local fault". In a side-by-side run, a Claude-family model scored 1 on identical evidence.
- **`service-stopped` (0)** — `cron: inactive` was sitting in the collected evidence; the default model still declared the host healthy.
- **`deleted-file-disk` (0.5)** — found the full disk, missed the deleted-but-open mechanism; never proactively called the follow-up command that reveals it.
- **`docker-cache-bloat` (0)** — with 28 GB still free the model (defensibly) declared no fault and never checked Docker's own disk usage. A weak-signal hygiene scenario.

The pattern across all four: the *collector* produced the evidence; the economical default model failed to chase or credit **silent evidence** — probes that failed quietly, services that are absent rather than erroring. This is a model-capability trade-off, not a collection gap, which is exactly why RootPilot is BYOK: point it at a stronger model and this class of scenario improves, or keep the cheap default for the 25 scenarios where it's already right.

## Honest footnotes

- **The headline number went *down* when we made the benchmark harder.** The original 24-scenario set scored 93.75% after collection and prompt iteration. Adding five harder scenarios brought the overall figure to 89.7% (26.0/29). We quote the lower number.
- **What changed between calibration rounds:** one collection-probe bug fix (the egress probe reported the wrong exit code), two whitelist additions (container-internal socket listing; system service status — both listed in [security.md](security.md)), and one prompt-level rule requiring silent evidence to be treated as reportable rather than rationalised away. Scenario definitions and grading were not weakened at any point.
- **`clock-drift` is a soft injection**: the drift is presented through application logs and token-validation failures rather than by re-clocking the host — genuinely skewing the clock of a shared test host would break TLS and NTP for everything else on it. The graded evidence path is unchanged.
- **Model and rounds:** every diagnosis ran with at most one follow-up collection round — the same limit the product ships with.

## Reproduce the spirit of it

The collection layer — the same read-only whitelist approach — is open source as an MCP server: [rootpilot-mcp](https://github.com/Easton-OU/rootpilot-mcp). Point it at a disposable VM, inject any fault from the list above, and see what the raw evidence looks like in your own LLM client.

*中文版: [docs/zh/calibration.md](zh/calibration.md)*
