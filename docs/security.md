# Security model

RootPilot is built to be trusted with SSH access to production servers. This document explains exactly what it can and cannot do.

## 1. Fixed read-only whitelist

RootPilot can only run a **fixed set of read-only inspection commands** over SSH. There is no feature — not even a "run this command" box behind a confirmation — that executes an arbitrary command. Every command below only *reads* state.

The single value ever interpolated into a command is a **container name**, and it is validated against `^[a-zA-Z0-9_.-]+$` before use. A name containing a space, quote, `;`, `|`, `$`, backtick, or newline is rejected — so a value like `web; rm -rf /` never reaches a shell.

The complete whitelist is **38 commands**, listed verbatim in [§5](#5-the-full-38-command-whitelist).

## 2. Encrypted credentials (AES-256-GCM)

SSH credentials you save (keys or passwords) are encrypted at rest with **AES-256-GCM**. The encryption key (`ROOTPILOT_ENCRYPT_KEY`) lives only in your `.env` on your machine. Rotating it makes previously saved credentials undecryptable — by design. RootPilot never transmits your credentials anywhere except when establishing the SSH connection you configured.

## 3. Bring your own key (BYOK)

RootPilot uses **your** LLM API key. The evidence collected from your hosts is sent only to the model provider you choose, using your key. There is no RootPilot-hosted inference in the path.

## 4. Data never leaves your boundary

- The application runs in **your** Docker environment.
- Diagnoses flow between your RootPilot container, your hosts (over SSH), and your chosen LLM API.
- **No telemetry**, no phone-home, no RootPilot cloud intermediary.
- The web console **binds to `127.0.0.1` only** and has no separate login — reach a remote install over an SSH tunnel or behind your own reverse proxy + auth. See [deployment.md](deployment.md).

## 5. The full 38-command whitelist

Every command RootPilot can run. `<container>` is a validated container name; `<probe-url>` is a connectivity target you configure. All are read-only, time-boxed, and their output is secret-redacted (env values, tokens, keys, PEM blocks) and truncated before it enters a diagnosis.

### Base overview

| key | purpose | command |
|---|---|---|
| `docker_ps` | List all containers with status and image | `docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}"` |
| `docker_daemon` | Docker daemon status and running/total container count | `systemctl is-active docker 2>/dev/null; docker info --format '{{.ServerVersion}} running:{{.ContainersRunning}}/{{.Containers}}' 2>/dev/null` |
| `df` | Filesystem disk usage | `df -h` |
| `df_inode` | Inode usage (a full inode table looks like a full disk) | `df -i` |
| `free` | Memory and swap usage | `free -m` |
| `uptime` | Uptime and load average | `uptime` |
| `dmesg_oom` | Kernel OOM / killed-process evidence | `dmesg -T 2>/dev/null \| grep -iE 'oom\|killed process' \| tail -20` |

### Containers

| key | purpose | command |
|---|---|---|
| `docker_stats` | Live CPU / memory / IO per container | `docker stats --no-stream` |
| `docker_logs` | Last 500 log lines of a container | `docker logs --tail 500 <container> 2>&1` |
| `docker_inspect` | Container configuration (secrets redacted) | `docker inspect <container>` |
| `container_state` | Exit code / OOMKilled flag / restart count / status | `docker inspect <container> --format 'ExitCode:{{.State.ExitCode}} OOMKilled:{{.State.OOMKilled}} Restarts:{{.RestartCount}} Status:{{.State.Status}}' 2>/dev/null` |
| `container_netstat` | Ports a container is actually listening on (verify claimed vs real) | `docker exec <container> sh -c "(ss -tlnp 2>/dev/null \|\| netstat -tlnp 2>/dev/null \|\| cat /proc/net/tcp 2>/dev/null) \| head -20" 2>/dev/null \|\| echo "[cannot enter container or no net tools inside]"` |
| `docker_top` | Process list inside a container (in-container CPU hog) | `docker top <container> 2>/dev/null \|\| echo "[cannot read container processes]"` |
| `docker_events` | Recent container events (kill / die / oom / restart) | `timeout 5 docker events --since 30m --until "$(date +%s)" 2>/dev/null \| tail -40 \|\| echo "[no recent events or docker unavailable]"` |

### Resource / disk

| key | purpose | command |
|---|---|---|
| `top` | Process snapshot | `top -b -n 1 \| head -30` |
| `ps_mem` | Top processes by memory | `ps -eo pid,user,%mem,rss,comm --sort=-%mem 2>/dev/null \| head -16` |
| `ps_cpu` | Top processes by CPU | `ps -eo pid,user,%cpu,etimes,comm --sort=-%cpu 2>/dev/null \| head -16` |
| `vmstat` | CPU / IO / swap dynamics over 3 seconds | `vmstat 1 3 2>/dev/null \|\| echo "[vmstat not installed (procps)]"` |
| `iostat` | Disk IO saturation (%util / await) | `iostat -xz 1 2 2>/dev/null \|\| echo "[iostat not installed, needs sysstat]"` |
| `meminfo` | Memory / swap / slab breakdown | `grep -E "MemTotal\|MemFree\|MemAvailable\|Buffers\|Cached\|SwapTotal\|SwapFree\|Dirty\|Writeback\|Slab" /proc/meminfo 2>/dev/null` |
| `loadavg` | Load average vs core count | `cat /proc/loadavg 2>/dev/null; echo "cores=$(nproc 2>/dev/null)"` |
| `docker_disk` | Docker disk usage (images / containers / volumes / build cache) | `docker system df 2>/dev/null \|\| echo "[docker unavailable]"` |
| `disk_top_dirs` | Largest directories (find what filled the disk) | `du -xhd1 /var /home /opt /tmp /root /usr 2>/dev/null \| sort -rh \| head -15` |
| `deleted_open_files` | Deleted-but-open files (df full while du is not) | `lsof +L1 2>/dev/null \| { IFS= read -r h; echo "$h"; sort -k7 -rn; } \| head -20 \|\| echo "[lsof missing or no permission]"` |
| `mounts_ro` | Read-only remounts on real partitions (disk-failure symptom) | `grep -E " ro,\| ro " /proc/mounts 2>/dev/null \| grep -vE "tmpfs\|cgroup\|squashfs\|overlay\|iso9660\|/snap\|/run/\|/sys/\|/proc/\|..." \| head` |

### Network

| key | purpose | command |
|---|---|---|
| `listen_ports` | Listening TCP ports | `(ss -tlnp 2>/dev/null \|\| netstat -tlnp 2>/dev/null) \| head -40` |
| `net_egress` | Outbound connectivity probe | `timeout 3 curl -sS -o /dev/null -w "HTTP:%{http_code}" <probe-url> 2>&1; echo " EXIT:$?"` |
| `conn_states` | Connection-state distribution (TIME_WAIT / CLOSE_WAIT floods) | `echo "== state counts =="; ss -tan 2>/dev/null \| sed 1d \| tr -s " " \| cut -d" " -f1 \| sort \| uniq -c \| sort -rn \| head; ss -s 2>/dev/null \| head -5` |
| `dns_check` | DNS config and a resolution probe | `grep -vE "^#\|^$" /etc/resolv.conf 2>/dev/null \| head -5; timeout 3 getent hosts <probe-host> 2>&1 \| head -3 \|\| echo "[resolution failed, DNS issue]"` |
| `firewall` | Firewall rules (possible source of refused connections) | `(iptables -S 2>/dev/null \|\| nft list ruleset 2>/dev/null \|\| echo "[needs root or not installed]") \| head -40` |
| `route_iface` | Routing table and NIC errors / drops | `ip route 2>/dev/null \| head -15; ip -s -br link 2>/dev/null \| head \|\| netstat -i 2>/dev/null \| head` |
| `conntrack` | Conntrack table usage (a full table drops new connections) | `echo "count=$(cat /proc/sys/net/netfilter/nf_conntrack_count) max=$(cat /proc/sys/net/netfilter/nf_conntrack_max)"` |

### System / kernel / logs

| key | purpose | command |
|---|---|---|
| `journalctl` | Last 200 systemd journal lines | `journalctl -n 200 --no-pager` |
| `service_status` | Key services installed-but-not-running (silent evidence) + failed units | `for s in cron sshd docker containerd rsyslog systemd-timesyncd chrony ntp; do systemctl cat $s >/dev/null 2>&1 && { st=$(systemctl is-active $s); [ "$st" != active ] && echo "$s=$st"; }; done; systemctl --failed --type=service --no-pager --plain 2>/dev/null \| grep [.]service` |
| `dmesg_errors` | Kernel errors (IO / filesystem / segfault / hung task / NIC) | `dmesg -T 2>/dev/null \| grep -iE "error\|fail\|segfault\|call trace\|hung_task\|i/o error\|ext4-fs error\|xfs\|link is down\|panic" \| tail -30` |
| `timedatectl` | System clock and NTP sync (drift breaks certs / auth / timers) | `timedatectl 2>/dev/null \|\| { echo "date: $(date)"; echo "[timedatectl unavailable]"; }` |
| `fd_usage` | File-descriptor usage (Too many open files) | `cat /proc/sys/fs/file-nr 2>/dev/null; for p in /proc/[0-9]*; do n=$(ls "$p/fd" 2>/dev/null \| wc -l); [ "$n" -gt 200 ] && echo "$n $(cat $p/comm 2>/dev/null)"; done \| sort -rn \| head -10` |
| `syslog_tail` | Classic syslog tail (some apps do not write to journald) | `for f in /var/log/syslog /var/log/messages; do [ -r "$f" ] && { tail -60 "$f"; break; }; done 2>/dev/null` |

> Some rows are lightly abbreviated for readability (guard clauses and noise filters trimmed with `…`). The full set is identical to what the product's settings page displays.

## Reporting a vulnerability

Found a way to make RootPilot run something outside this whitelist, or to exfiltrate a credential? Please email **support@rootpilotx.com** rather than opening a public issue. We take command-execution and credential-handling reports seriously.
