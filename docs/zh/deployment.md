# 部署与访问指南

## 在哪里运行 RootPilot

请在一台能够通过 SSH 访问待诊断服务器的机器上运行 RootPilot：

- **你的笔记本 / 工作站** —— 最简单。通过你日常的 SSH 访问连接目标主机。
- **一台小型运维 / 堡垒机 VM** —— 如果你的服务器只能在内网访问，这种方式更合适。把 RootPilot 部署在那里，再从外部隧道接入。

RootPilot 需要 Docker；而被它诊断的服务器**不需要** —— 目标主机上无需安装任何 agent，它们只要接受你的 SSH 连接即可。

## 安装

环境要求：**Docker 20.10+**、**Docker Compose v2**（`docker compose`）、约 2 GB 空闲内存。

### 一条命令

```bash
# Linux / macOS
curl -fsSL https://rootpilotx.com/install.sh | sh
```

```powershell
# Windows PowerShell
irm https://rootpilotx.com/install.ps1 | iex
```

安装脚本会下载 compose 文件，首次运行时生成 `DB_PASSWORD` 和 `ROOTPILOT_ENCRYPT_KEY` 并写入 `.env`（之后复用），随后启动整个服务栈。

### 手动方式（compose）

```bash
curl -fsSLO https://raw.githubusercontent.com/Easton-OU/rootpilot-release/main/docker-compose.yml
curl -fsSLO https://raw.githubusercontent.com/Easton-OU/rootpilot-release/main/.env.example
cp .env.example .env
# set DB_PASSWORD and ROOTPILOT_ENCRYPT_KEY (see comments in .env)
docker compose up -d
```

## 访问控制台

控制台**仅绑定 `127.0.0.1`**，且没有独立的登录机制，因此默认情况下绝不会暴露到公网。

- **本地安装：** 打开 `http://localhost:18081`。
- **远程安装：** 从你的笔记本通过 SSH 建立隧道：

  ```bash
  ssh -L 18081:localhost:18081 user@your-rootpilot-host
  # then open http://localhost:18081 locally
  ```

- **想要一个固定的 URL？** 把 RootPilot 放到你自己的反向代理（nginx/Caddy/Traefik）之后，并**启用认证**和 TLS。不要直接对外发布 18081 端口。

## 接入目标主机（凭据）

在控制台中，添加每一台你想诊断的服务器：

- **优先使用专用的、最小权限的 SSH 用户**来做诊断，而不是 root。白名单是只读的，但账号本身也应体现这一意图。建议使用基于密钥的登录，而非密码。
- 凭据在静态存储时使用 AES-256-GCM（`ROOTPILOT_ENCRYPT_KEY`）加密。请保持该密钥稳定 —— 参见 [security.md](security.md)。
- 有些命令在拥有更高权限时能读到更多信息（`dmesg`、`iptables`、完整的 `journalctl`）。当某条命令不被允许时，RootPilot 会优雅降级；只有当你希望获得这些额外证据时，才为它们授予免密码的只读 sudo 权限。

## 多主机

按你的版本允许的数量添加主机（免费版：1 台；专业版：2–10 台）。每台主机保留各自的历史记录。当告警触发（或你主动询问）时，RootPilot 只诊断涉及的那台具体主机。

## 跳板机 / 堡垒机

如果某个目标只能通过堡垒机访问，请先通过你的 SSH 配置让 RootPilot 机器能透明地访问它，然后用目标的内网地址添加该主机：

```
# ~/.ssh/config on the RootPilot host
Host internal-db
  HostName 10.0.0.5
  User ops
  ProxyJump bastion.example.com
```

RootPilot 会像使用任何其他连接一样使用这条连接。（应用内原生的跳板机配置已在规划中。）

## 升级与维护

```bash
cd ~/rootpilot            # wherever your compose + .env live
docker compose pull
docker compose up -d
```

停止：

```bash
docker compose down       # add -v only if you also want to drop the MySQL volume
```

备份：你的 `.env`（尤其是 `ROOTPILOT_ENCRYPT_KEY`）以及 `mysql-data` 卷。丢失加密密钥意味着需要重新添加主机凭据。

## 可选：Prometheus 上下文

在 `.env` 中设置 `ROOTPILOT_PROMETHEUS_URL`（例如 `http://prometheus:9090`），可让诊断在故障时间窗内纳入指标趋势。留空则完全跳过指标采集。
