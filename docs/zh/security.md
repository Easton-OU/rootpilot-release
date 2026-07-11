# 安全模型

RootPilot 的设计目标是可以放心地授予它对生产服务器的 SSH 访问权限。本文档准确说明它能做什么、不能做什么。

## 1. 固定的只读白名单

RootPilot 只能通过 SSH 运行一组**固定的只读检查命令**。它没有任何功能 —— 哪怕是一个需要确认才能"运行此命令"的输入框 —— 可以执行任意命令。下面列出的每一条命令都只*读取*状态。

唯一会被插入到命令中的值是**容器名**，且在使用前会用 `^[a-zA-Z0-9_.-]+$` 校验。包含空格、引号、`;`、`|`、`$`、反引号或换行符的名称都会被拒绝 —— 因此像 `web; rm -rf /` 这样的值永远不会进入 shell。

完整白名单共 **38 条命令**，在 [§5](#5-the-full-38-command-whitelist) 中逐字列出。

## 2. 加密凭据（AES-256-GCM）

你保存的 SSH 凭据（密钥或密码）在静态存储时使用 **AES-256-GCM** 加密。加密密钥（`ROOTPILOT_ENCRYPT_KEY`）只存在于你机器上的 `.env` 中。轮换该密钥会使此前保存的凭据无法解密 —— 这是刻意的设计。除了建立你所配置的那条 SSH 连接之外，RootPilot 绝不会把你的凭据传输到任何地方。

## 3. 自带密钥（BYOK）

RootPilot 使用**你自己**的 LLM API 密钥。从你的主机上采集到的证据只会发送给你选择的模型提供商，并使用你的密钥。整个链路中不存在由 RootPilot 托管的推理服务。

## 4. 数据不越出你的边界

- 应用运行在**你自己**的 Docker 环境中。
- 诊断数据只在你的 RootPilot 容器、你的主机（通过 SSH）和你选择的 LLM API 之间流动。
- **无遥测**、无回传、无 RootPilot 云端中间层。
- Web 控制台**仅绑定 `127.0.0.1`**，且没有独立的登录机制 —— 对于远程安装，请通过 SSH 隧道，或放在你自己的反向代理 + 认证之后访问。参见 [deployment.md](deployment.md)。

## 5. 完整的 38 条命令白名单

RootPilot 能运行的全部命令。`<container>` 是经过校验的容器名；`<probe-url>` 是你配置的连通性目标。所有命令均为只读、有时间上限，其输出会经过密文脱敏（环境变量值、令牌、密钥、PEM 块）并在进入诊断前被截断。

### 基础概览

| key | purpose | command |
|---|---|---|
| `docker_ps` | 列出所有容器及其状态和镜像 | `docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.Image}}"` |
| `docker_daemon` | Docker 守护进程状态及运行中/总容器数 | `systemctl is-active docker 2>/dev/null; docker info --format '{{.ServerVersion}} running:{{.ContainersRunning}}/{{.Containers}}' 2>/dev/null` |
| `df` | 文件系统磁盘使用情况 | `df -h` |
| `df_inode` | inode 使用情况（inode 表用满看起来像磁盘用满） | `df -i` |
| `free` | 内存和 swap 使用情况 | `free -m` |
| `uptime` | 运行时长和负载均值 | `uptime` |
| `dmesg_oom` | 内核 OOM / 进程被杀的证据 | `dmesg -T 2>/dev/null \| grep -iE 'oom\|killed process' \| tail -20` |

### 容器

| key | purpose | command |
|---|---|---|
| `docker_stats` | 每个容器的实时 CPU / 内存 / IO | `docker stats --no-stream` |
| `docker_logs` | 容器最近 500 行日志 | `docker logs --tail 500 <container> 2>&1` |
| `docker_inspect` | 容器配置（密文已脱敏） | `docker inspect <container>` |
| `container_state` | 退出码 / OOMKilled 标志 / 重启次数 / 状态 | `docker inspect <container> --format 'ExitCode:{{.State.ExitCode}} OOMKilled:{{.State.OOMKilled}} Restarts:{{.RestartCount}} Status:{{.State.Status}}' 2>/dev/null` |
| `container_netstat` | 容器实际监听的端口（核对声称值与真实值） | `docker exec <container> sh -c "(ss -tlnp 2>/dev/null \|\| netstat -tlnp 2>/dev/null \|\| cat /proc/net/tcp 2>/dev/null) \| head -20" 2>/dev/null \|\| echo "[cannot enter container or no net tools inside]"` |
| `docker_top` | 容器内进程列表（容器内的 CPU 占用大户） | `docker top <container> 2>/dev/null \|\| echo "[cannot read container processes]"` |
| `docker_events` | 最近的容器事件（kill / die / oom / restart） | `timeout 5 docker events --since 30m --until "$(date +%s)" 2>/dev/null \| tail -40 \|\| echo "[no recent events or docker unavailable]"` |

### 资源 / 磁盘

| key | purpose | command |
|---|---|---|
| `top` | 进程快照 | `top -b -n 1 \| head -30` |
| `ps_mem` | 按内存排序的进程 | `ps -eo pid,user,%mem,rss,comm --sort=-%mem 2>/dev/null \| head -16` |
| `ps_cpu` | 按 CPU 排序的进程 | `ps -eo pid,user,%cpu,etimes,comm --sort=-%cpu 2>/dev/null \| head -16` |
| `vmstat` | 3 秒内的 CPU / IO / swap 动态 | `vmstat 1 3 2>/dev/null \|\| echo "[vmstat not installed (procps)]"` |
| `iostat` | 磁盘 IO 饱和度（%util / await） | `iostat -xz 1 2 2>/dev/null \|\| echo "[iostat not installed, needs sysstat]"` |
| `meminfo` | 内存 / swap / slab 明细 | `grep -E "MemTotal\|MemFree\|MemAvailable\|Buffers\|Cached\|SwapTotal\|SwapFree\|Dirty\|Writeback\|Slab" /proc/meminfo 2>/dev/null` |
| `loadavg` | 负载均值对比核心数 | `cat /proc/loadavg 2>/dev/null; echo "cores=$(nproc 2>/dev/null)"` |
| `docker_disk` | Docker 磁盘占用（镜像 / 容器 / 卷 / 构建缓存） | `docker system df 2>/dev/null \|\| echo "[docker unavailable]"` |
| `disk_top_dirs` | 最大的目录（找出是什么占满了磁盘） | `du -xhd1 /var /home /opt /tmp /root /usr 2>/dev/null \| sort -rh \| head -15` |
| `deleted_open_files` | 已删除但仍打开的文件（df 满而 du 不满） | `lsof +L1 2>/dev/null \| { IFS= read -r h; echo "$h"; sort -k7 -rn; } \| head -20 \|\| echo "[lsof missing or no permission]"` |
| `mounts_ro` | 真实分区上的只读重挂载（磁盘故障征兆） | `grep -E " ro,\| ro " /proc/mounts 2>/dev/null \| grep -vE "tmpfs\|cgroup\|squashfs\|overlay\|iso9660\|/snap\|/run/\|/sys/\|/proc/\|..." \| head` |

### 网络

| key | purpose | command |
|---|---|---|
| `listen_ports` | 监听中的 TCP 端口 | `(ss -tlnp 2>/dev/null \|\| netstat -tlnp 2>/dev/null) \| head -40` |
| `net_egress` | 出站连通性探测 | `timeout 3 curl -sS -o /dev/null -w "HTTP:%{http_code}" <probe-url> 2>&1; echo " EXIT:$?"` |
| `conn_states` | 连接状态分布（TIME_WAIT / CLOSE_WAIT 泛滥） | `echo "== state counts =="; ss -tan 2>/dev/null \| sed 1d \| tr -s " " \| cut -d" " -f1 \| sort \| uniq -c \| sort -rn \| head; ss -s 2>/dev/null \| head -5` |
| `dns_check` | DNS 配置及一次解析探测 | `grep -vE "^#\|^$" /etc/resolv.conf 2>/dev/null \| head -5; timeout 3 getent hosts <probe-host> 2>&1 \| head -3 \|\| echo "[resolution failed, DNS issue]"` |
| `firewall` | 防火墙规则（可能是连接被拒的来源） | `(iptables -S 2>/dev/null \|\| nft list ruleset 2>/dev/null \|\| echo "[needs root or not installed]") \| head -40` |
| `route_iface` | 路由表及网卡错误 / 丢包 | `ip route 2>/dev/null \| head -15; ip -s -br link 2>/dev/null \| head \|\| netstat -i 2>/dev/null \| head` |
| `conntrack` | conntrack 表使用情况（表满会丢弃新连接） | `echo "count=$(cat /proc/sys/net/netfilter/nf_conntrack_count) max=$(cat /proc/sys/net/netfilter/nf_conntrack_max)"` |

### 系统 / 内核 / 日志

| key | purpose | command |
|---|---|---|
| `journalctl` | 最近 200 行 systemd journal 日志 | `journalctl -n 200 --no-pager` |
| `service_status` | 已安装但未运行的关键服务（沉默的证据）+ 失败的 unit | `for s in cron sshd docker containerd rsyslog systemd-timesyncd chrony ntp; do systemctl cat $s >/dev/null 2>&1 && { st=$(systemctl is-active $s); [ "$st" != active ] && echo "$s=$st"; }; done; systemctl --failed --type=service --no-pager --plain 2>/dev/null \| grep [.]service` |
| `dmesg_errors` | 内核错误（IO / 文件系统 / segfault / hung task / 网卡） | `dmesg -T 2>/dev/null \| grep -iE "error\|fail\|segfault\|call trace\|hung_task\|i/o error\|ext4-fs error\|xfs\|link is down\|panic" \| tail -30` |
| `timedatectl` | 系统时钟和 NTP 同步（时钟漂移会破坏证书 / 认证 / 定时器） | `timedatectl 2>/dev/null \|\| { echo "date: $(date)"; echo "[timedatectl unavailable]"; }` |
| `fd_usage` | 文件描述符使用情况（Too many open files） | `cat /proc/sys/fs/file-nr 2>/dev/null; for p in /proc/[0-9]*; do n=$(ls "$p/fd" 2>/dev/null \| wc -l); [ "$n" -gt 200 ] && echo "$n $(cat $p/comm 2>/dev/null)"; done \| sort -rn \| head -10` |
| `syslog_tail` | 经典 syslog 尾部（部分应用不写 journald） | `for f in /var/log/syslog /var/log/messages; do [ -r "$f" ] && { tail -60 "$f"; break; }; done 2>/dev/null` |

> 部分行为便于阅读做了轻微精简（用 `…` 裁掉了保护性判断和降噪过滤）。完整集合与产品设置页所展示的内容完全一致。

## 报告漏洞

发现了让 RootPilot 运行白名单之外命令的方法，或能窃取凭据的途径？请发邮件至 **support@rootpilotx.com**，而不是公开提 issue。我们会认真对待命令执行和凭据处理方面的报告。
