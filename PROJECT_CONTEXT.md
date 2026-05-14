# Frappe Docker Manager — Complete Project Context

> **Owner:** Brainsmine / Invento Software Limited
> **Author:** Nilesh Patil
> **Contact:** patilnilesh0278@gmail.com
> **Version:** v1.1.0 (Active Development)
> **Last Analyzed:** 2026-03-27

---

## Table of Contents

1. [Project Purpose](#1-project-purpose)
2. [Complete Directory Structure](#2-complete-directory-structure)
3. [Key Scripts — Detailed Breakdown](#3-key-scripts--detailed-breakdown)
4. [Configuration Files](#4-configuration-files)
5. [Container Architecture](#5-container-architecture)
6. [System Flow — How It Works](#6-system-flow--how-it-works)
7. [Technologies Used](#7-technologies-used)
8. [App Installation System](#8-app-installation-system)
9. [Platform Differences (Mac vs Linux vs VPS)](#9-platform-differences-mac-vs-linux-vs-vps)
10. [Volumes and Persistent Data](#10-volumes-and-persistent-data)
11. [Networking Architecture](#11-networking-architecture)
12. [Security Model](#12-security-model)
13. [Default Credentials](#13-default-credentials)
14. [Common Commands Reference](#14-common-commands-reference)
15. [Troubleshooting Guide](#15-troubleshooting-guide)
16. [Design Patterns Used](#16-design-patterns-used)
17. [Active Development State](#17-active-development-state)

---

## 1. Project Purpose

**Frappe Docker Manager** is an automated deployment toolkit that reduces ERPNext/Frappe setup from hours of manual Docker configuration to under 10 minutes of guided prompts.

### What It Solves

| Problem | Solution |
|---------|----------|
| Complex Docker Compose file creation | Scripts generate docker-compose.yml dynamically |
| Platform differences (Mac vs Linux) | Separate platform-aware Traefik setup scripts |
| PostgreSQL/MariaDB configuration differences | Auto-detects DB and adjusts all configs |
| SSL certificate management | Traefik handles Let's Encrypt automatically |
| App installation ordering | Create-site container handles dependencies |
| Day-to-day container management | Interactive menu-driven manager scripts |

### Supported Environments

- **Local Development:** Mac (with/without sudo), Linux
- **Production:** Any VPS/cloud server with Docker

---

## 2. Complete Directory Structure

```
frappe-docker-manager/
│
├── README.md                                    # Main entry-point documentation
├── PROJECT_CONTEXT.md                           # This file — full project context
├── .gitignore                                   # Ignores generated site folders
│
├── Docker-Local/                                # ── LOCAL DEVELOPMENT ──
│   ├── generate_frappe_docker_local.sh          # [35.8 KB] Main site generator
│   ├── docker-manager-local.sh                  # [32.1 KB] Interactive container manager
│   ├── setup-traefik-local-mac-no-sudo.sh       # [9.7 KB]  Mac Traefik (no sudo, port 8081)
│   ├── setup-traefik-local-mac.sh               # [14.6 KB] Mac Traefik (with sudo)
│   ├── setup-traefik-local.sh                   # [8.9 KB]  Linux Traefik (port 80)
│   ├── traefik-docker-compose.yml               # Traefik reverse proxy Docker config
│   ├── .traefik-local-config                    # Auto-generated: persists port + localhost settings
│   ├── README.md                                # [11.5 KB] Full local setup guide
│   ├── QUICK_REFERENCE.md                       # [5.4 KB]  Quick command reference
│   ├── DATABASE.md                              # [8.9 KB]  DB access & management guide
│   ├── MAC_COMPATIBILITY.md                     # [6.4 KB]  Mac-specific instructions
│   ├── CHANGELOG.md                             # [4.4 KB]  Version history
│   └── helper-screenshot/                       # Documentation screenshots folder
│
├── Docker-on-VPS/                               # ── VPS / PRODUCTION ──
│   ├── generate_frappe_docker.sh                # [24.5 KB] VPS site generator (with SSL)
│   ├── docker-manager.sh                        # [32.0 KB] VPS container manager
│   ├── traefik-docker-compose.yml               # VPS Traefik with ACME/Let's Encrypt
│   ├── README.md                                # [13.5 KB] Full VPS setup guide
│   ├── DATABASE.md                              # [7.7 KB]  VPS database access guide
│   └── DOCKER_MANAGER.md                        # [12.3 KB] VPS manager documentation
│
└── others/                                      # ── UTILITIES & SECURITY ──
    ├── docker-security-tools.sh                 # [8.1 KB]  Menu-driven security audit toolkit
    ├── secure-docker-setup.sh                   # [3.8 KB]  Hardened setup (non-root, secrets)
    ├── fix_traefik_https.sh                     # [3.2 KB]  HTTPS/SSL troubleshooter
    ├── manage-hosts.sh                          # [5.3 KB]  /etc/hosts file manager
    ├── manual_fix_traefik.sh                    # [1.7 KB]  Manual Traefik fixes
    ├── DOCKER_SECURITY.md                       # Security hardening documentation
    ├── TRAEFIK_LOCAL_FIX.md                     # Traefik troubleshooting guide
    └── helping_commands.md                      # Reference commands collection
```

---

## 3. Key Scripts — Detailed Breakdown

### 3.1 `Docker-Local/generate_frappe_docker_local.sh` ★ Most Complex

**Role:** Core script — generates an entire local ERPNext site from scratch.

**What It Does (Step by Step):**
1. Loads `.traefik-local-config` to get Traefik port + localhost mode
2. Prompts user for database choice (MariaDB or PostgreSQL)
3. Prompts for site name (e.g., `demo.localhost`)
4. Prompts for optional apps: UI Theme, HRMS, Raven, custom apps
5. Validates domain name format and Traefik port
6. Adds `/etc/hosts` entry if needed (non-localhost domains)
7. Creates `{site_name}-local/` directory
8. Generates `docker-compose.yml` using bash heredoc
9. Runs `docker compose up -d`
10. Waits for DB container to become healthy (retries every 15s)
11. `create-site` container: clones apps → installs site → builds assets → exits
12. `app` container: starts Supervisor → serves ERPNext
13. Displays login credentials and site URL

**User Prompts:**
```
1. Use PostgreSQL instead of MariaDB? [y/N]
2. Enter site name: (e.g., mysite.localhost)
3. Install UI Theme? [y/N]
4. Install HRMS? [y/N]
5. Install Raven Chat? [y/N]
6. Add a custom app? [y/N]
   → If yes: App name, Git URL, Branch
```

**Output:**
- `{site_name}-local/docker-compose.yml` — full multi-service config
- Running containers: `-app`, `-db`, `-redis`, `-create-site`
- Accessible at `http://{site_name}:{traefik_port}`

---

### 3.2 `Docker-Local/docker-manager-local.sh`

**Role:** Interactive day-to-day container management tool.

**How It Works:**
- Auto-discovers all Frappe sites by parsing running Docker container names
- Presents an 11-item numbered menu

**Menu Options:**
```
 1. Show all containers         → docker ps with Frappe filter
 2. Shell into app (frappe)     → docker exec -it -u frappe ... bash
 3. Shell into app (root)       → docker exec -it -u root ... bash
 4. Supervisor process control  → start/stop/restart web, worker, schedule
 5. View / tail logs            → app, db, redis container logs
 6. Container lifecycle         → start, stop, restart, remove
 7. Site information            → site config, installed apps, DB info
 8. Root shell                  → elevated access
 9. File transfer               → copy files in/out of containers
10. Install packages            → apt-get inside containers
11. Exit
```

---

### 3.3 `Docker-Local/setup-traefik-local-mac-no-sudo.sh`

**Role:** One-time setup — deploys the shared Traefik reverse proxy on macOS without sudo.

**Flow:**
1. Detects macOS (exits if not macOS)
2. Checks Docker daemon is running
3. Tests port availability: tries 80 → 8080 → 8081 (using `lsof`)
4. Creates external Docker network `traefik_proxy` (if not exists)
5. Generates `traefik-docker-compose.yml` with selected port
6. Starts Traefik container
7. Saves config to `.traefik-local-config`:
   ```
   TRAEFIK_HTTP_PORT=8081
   USE_LOCALHOST=true
   ```

**Why no sudo?** macOS native `.localhost` domain support — port 8081 works without `/etc/hosts` or privileged port binding.

---

### 3.4 `Docker-Local/setup-traefik-local-mac.sh`

**Role:** Same as above but WITH sudo — allows binding to port 80.

**Differences from no-sudo version:**
- Uses `sudo` for port 80 binding
- More flexible port configuration options
- Includes additional security checks for privileged ports

---

### 3.5 `Docker-Local/setup-traefik-local.sh`

**Role:** Traefik setup for Linux systems.

**Key Differences:**
- Uses `ss` instead of `lsof` for port detection (Linux-native)
- Default port: 80 (standard for Linux servers)
- Manages `/etc/hosts` for `.local` domains (Linux doesn't auto-resolve them)
- Requires sudo for port 80 binding

---

### 3.6 `Docker-on-VPS/generate_frappe_docker.sh`

**Role:** Production-grade site deployment — same as local generator but with HTTPS.

**Additional VPS Features:**
- SSL/HTTPS with Let's Encrypt ACME certificates
- Cloudflare DNS challenge support (optional, for proxied domains)
- HTTP → HTTPS redirect middleware in Traefik labels
- Domain validation (must be real domain, not `.localhost`)
- Notification email for Let's Encrypt expiry alerts

**Extra Prompts:**
```
- Enable SSL/HTTPS? [y/N]
- Domain name: (e.g., mycompany.com)
- Cloudflare API token: (leave blank to skip)
- Let's Encrypt email: (e.g., admin@mycompany.com)
```

---

### 3.7 `Docker-on-VPS/docker-manager.sh`

**Role:** VPS container management — same functionality as local manager, optimized for production.

---

### 3.8 `others/docker-security-tools.sh`

**Role:** Menu-driven security audit toolkit.

**Tools It Installs & Manages:**
| Tool | Purpose |
|------|---------|
| Trivy | CVE vulnerability scanner for container images |
| Docker Bench Security | Audits Docker daemon against CIS benchmarks |
| Falco | Runtime security monitoring (syscall-level) |

**Menu Actions:**
- Install security tools
- Run full security audit
- Schedule automated scans via cron
- View security logs

---

### 3.9 `others/secure-docker-setup.sh`

**Role:** Security-hardened alternative to the standard generator.

**Hardening Features:**
- Non-root container execution
- Resource limits (CPU + memory caps)
- Read-only filesystems where possible
- Docker secrets for password management (not plaintext env vars)
- Dropped Linux capabilities

---

### 3.10 `others/fix_traefik_https.sh`

**Role:** Diagnose and fix HTTPS/SSL certificate issues.

**Checks:**
- Domain DNS A record → points to server?
- Port 80/443 accessibility from internet
- Traefik ACME resolver status
- Certificate file existence

---

## 4. Configuration Files

### 4.1 `.traefik-local-config` (Auto-generated)

```bash
TRAEFIK_HTTP_PORT=8081
USE_LOCALHOST=true
```

- Written by `setup-traefik-local-*.sh` scripts
- Read by `generate_frappe_docker_local.sh` before generating sites
- Persists Traefik port across multiple site generations
- Prevents asking user for port info repeatedly

---

### 4.2 `Docker-Local/traefik-docker-compose.yml`

```yaml
version: "3"
services:
  traefik:
    image: traefik:v3.6.9
    ports:
      - "8081:8081"      # HTTP (port varies based on setup)
      - "8080:8080"      # API dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Docker provider
    command:
      - --api.insecure=true          # Dashboard accessible (local only)
      - --providers.docker=true      # Auto-discover containers
      - --entrypoints.web.address=:8081
networks:
  traefik_proxy:
    external: true
```

---

### 4.3 `Docker-on-VPS/traefik-docker-compose.yml`

```yaml
version: "3"
services:
  traefik:
    image: traefik:v3.6.9
    ports:
      - "80:80"           # HTTP
      - "443:443"         # HTTPS
      - "8080:8080"       # API dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt    # Certificate storage
    command:
      - --certificatesresolvers.letsencrypt.acme.httpchallenge=true
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
```

---

### 4.4 Generated `docker-compose.yml` Per Site

Each site gets its own `docker-compose.yml` generated dynamically. Key sections:

```yaml
version: "3.8"

services:
  # ─── Database ───────────────────────────────────────────
  db:
    image: mariadb:10.6          # OR postgres:14
    environment:
      MYSQL_ROOT_PASSWORD: admin
      MYSQL_DATABASE: _frappe    # MariaDB
      # OR
      POSTGRES_PASSWORD: admin   # PostgreSQL
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - frappe_network

  # ─── Redis ──────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    networks:
      - frappe_network

  # ─── App (ERPNext) ──────────────────────────────────────
  app:
    image: frappe/erpnext:v15.70.0
    depends_on:
      - db
      - redis
    environment:
      DB_HOST: db
      DB_PORT: "3306"            # OR 5432
      REDIS_CACHE: redis:6379
      REDIS_QUEUE: redis:6379
      SOCKETIO_PORT: "9000"
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
      - apps:/home/frappe/frappe-bench/apps
    labels:
      # Traefik routing labels
      - "traefik.enable=true"
      - "traefik.http.routers.sitename-web.rule=Host(`sitename.localhost`)"
      - "traefik.http.routers.sitename-web.entrypoints=web"
      - "traefik.http.services.sitename-web.loadbalancer.server.port=8000"
    networks:
      - frappe_network
      - traefik_proxy

  # ─── Create-Site (one-shot setup) ───────────────────────
  create-site:
    image: frappe/erpnext:v15.70.0
    depends_on:
      - db
      - redis
    environment:
      # Same as app
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - apps:/home/frappe/frappe-bench/apps
    restart: "no"                # Never restart — exits after setup
    networks:
      - frappe_network

volumes:
  sites:
  logs:
  apps:
  db-data:

networks:
  frappe_network:
    driver: bridge
  traefik_proxy:
    external: true
```

---

### 4.5 `.gitignore`

```gitignore
web-docker-manager-env/*
test*/
demo*/
*-local/        # Generated site folders
```

Prevents committing generated site configs (contain passwords) and local environment folders.

---

## 5. Container Architecture

### Per-Site Container Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TRAEFIK (Global / Shared)                        │
│                                                                     │
│  Reverse Proxy — Routes HTTP requests to correct site containers    │
│  Local: Port 8081  |  VPS: Port 80 (HTTP) + 443 (HTTPS)            │
│  Dashboard: Port 8080                                               │
│  Network: traefik_proxy (external)                                  │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ HTTP routing by Host header (domain)
           ┌───────────────┴────────────────────────────┐
           │              frappe_network (internal)      │
           │                                            │
    ┌──────▼───────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐
    │  {site}-app  │  │  {site}-db   │  │{site}-redis│  │{site}-create │
    │              │  │              │  │            │  │    -site     │
    │ frappe/      │  │ mariadb:10.6 │  │ redis:7    │  │              │
    │ erpnext:v15  │  │ OR           │  │            │  │ frappe/      │
    │              │  │ postgres:14  │  │ Port: 6379 │  │ erpnext:v15  │
    │ Supervisor:  │  │              │  │            │  │              │
    │  - web:8000  │  │ Port: 3306   │  │ Cache      │  │ Runs ONCE:   │
    │  - worker    │  │   (MariaDB)  │  │ Queue      │  │ - get-app    │
    │  - schedule  │  │ Port: 5432   │  │ Live push  │  │ - new-site   │
    │              │  │   (PG)       │  │            │  │ - migrate    │
    │ socket.io:   │  │              │  │            │  │ - build      │
    │  Port 9000   │  │ Volumes:     │  │            │  │              │
    │              │  │  db-data     │  │            │  │ Then exits   │
    │ Volumes:     │  │              │  │            │  │ (restart:no) │
    │  sites       │  │              │  │            │  │              │
    │  logs        │  │              │  │            │  │              │
    │  apps        │  │              │  │            │  │              │
    └──────────────┘  └──────────────┘  └────────────┘  └──────────────┘
```

### Supervisor Process Management (Inside App Container)

```
supervisord
  ├── web      → bench serve --port 8000
  │              Serves ERPNext web UI
  │              Logs: /home/frappe/supervisor/logs/web.log
  │
  ├── worker   → bench worker --queue default,short,long
  │              Processes background jobs from Redis queue
  │              Logs: /home/frappe/supervisor/logs/worker.log
  │
  └── schedule → bench schedule
                 Runs periodic/scheduled Frappe tasks
                 Logs: /home/frappe/supervisor/logs/schedule.log
```

---

## 6. System Flow — How It Works

### 6.1 Local Development — Full Setup Flow

```
PHASE 1: TRAEFIK SETUP (one-time)
══════════════════════════════════
./setup-traefik-local-mac-no-sudo.sh
  │
  ├─ Check: Docker daemon running?
  ├─ Check: Port 80 available? → try 8080 → try 8081
  ├─ Create: Docker network "traefik_proxy" (external)
  ├─ Write: traefik-docker-compose.yml
  ├─ Run:   docker compose up -d  (starts Traefik)
  └─ Save:  .traefik-local-config
             └── TRAEFIK_HTTP_PORT=8081
                 USE_LOCALHOST=true


PHASE 2: SITE GENERATION
══════════════════════════
./generate_frappe_docker_local.sh
  │
  ├─ Load: .traefik-local-config
  ├─ Prompt: Database? (MariaDB / PostgreSQL)
  ├─ Prompt: Site name? (e.g., demo.localhost)
  ├─ Prompt: Install UI Theme? HRMS? Raven? Custom app?
  ├─ Validate: domain format, port availability
  ├─ Optionally: add entry to /etc/hosts
  ├─ Create: demo.localhost-local/ folder
  ├─ Generate: docker-compose.yml (via bash heredoc)
  │
  ├─ docker compose up -d
  │    ├─ {site}-db      → starts MariaDB/PostgreSQL
  │    ├─ {site}-redis   → starts Redis
  │    ├─ {site}-app     → starts (waits for DB)
  │    └─ {site}-create-site → starts setup
  │
  ├─ Wait: DB ready? (retry every 15s, up to 5 min)
  │
  ├─ create-site container executes:
  │    ├─ bench get-app erpnext
  │    ├─ bench get-app frappe_pg  (PostgreSQL only)
  │    ├─ bench get-app hrms       (if selected)
  │    ├─ bench get-app raven      (if selected)
  │    ├─ bench get-app custom_app (if selected)
  │    ├─ pip install -e apps/frappe_pg  (PG: before new-site!)
  │    ├─ bench new-site {sitename} --install-app erpnext
  │    ├─ bench --site {sitename} install-app hrms
  │    ├─ bench --site {sitename} install-app raven
  │    ├─ bench build
  │    └─ exit 0  (container stops, never restarts)
  │
  ├─ app container: supervisord starts web/worker/schedule
  │
  └─ Display: URL + credentials


PHASE 3: DAILY MANAGEMENT
══════════════════════════
./docker-manager-local.sh
  ├─ Auto-discover Frappe containers
  ├─ Show menu (11 options)
  └─ Execute selected action
```

### 6.2 VPS Production — Additional Flow

```
./generate_frappe_docker.sh (VPS)
  │
  ├─ All local steps PLUS:
  │
  ├─ Prompt: Enable SSL? → y
  ├─ Prompt: Domain name → mycompany.com
  ├─ Prompt: Cloudflare API token → (optional)
  ├─ Prompt: Let's Encrypt email → admin@mycompany.com
  │
  ├─ Configure Traefik labels in docker-compose.yml:
  │    ├─ HTTP → HTTPS redirect middleware
  │    ├─ HTTPS entrypoint
  │    ├─ TLS certificate resolver (letsencrypt)
  │    └─ Socket.io HTTPS routing
  │
  ├─ On first start, Traefik:
  │    ├─ Detects new container with ACME labels
  │    ├─ Requests certificate from Let's Encrypt
  │    ├─ Stores cert in /letsencrypt/acme.json
  │    └─ Auto-renews before expiry
  │
  └─ Site live at https://mycompany.com
```

---

## 7. Technologies Used

### Core Stack

| Technology | Version | Role |
|-----------|---------|------|
| Frappe Framework | v15.x | Python web framework |
| ERPNext | v15.70.0 | Business ERP application |
| Docker | v20+ | Container platform |
| Docker Compose | v2.x | Multi-container orchestration |
| Traefik | v3.6.9 | Reverse proxy + SSL |

### Databases (User Selectable)

| Database | Version | When to Use |
|---------|---------|-------------|
| MariaDB | 10.6 | Default — stable, battle-tested with Frappe |
| PostgreSQL | 14 | When PostgreSQL is specifically required |

### Supporting Services

| Service | Version | Role |
|---------|---------|------|
| Redis | 7-alpine | Cache + job queue + live updates |
| Supervisor | Latest in image | Process manager for Frappe processes |
| Bench CLI | Bundled in image | Frappe development & management tool |

### Scripting

| Language | Usage |
|---------|-------|
| Bash | 100% of automation scripts |
| YAML | Docker Compose configs |
| Python | Frappe/ERPNext application (inside containers) |

### Optional Apps

| App | Repository | Purpose |
|-----|-----------|---------|
| ERPNext | frappe/erpnext | Core ERP — always installed |
| frappe_pg | NileshPBrainmine fork | PostgreSQL compatibility layer |
| UI Theme | (configurable) | Custom branding |
| HRMS | frappe/hrms | HR & Payroll management |
| Raven | The-Commit-Company/raven | Team chat messaging |
| Custom | Any git URL | User-specified app |

### Security Tools (Optional, `others/`)

| Tool | Purpose |
|------|---------|
| Trivy | Container image vulnerability scanner |
| Docker Bench Security | CIS Docker benchmark auditor |
| Falco | Runtime syscall-level security monitor |

---

## 8. App Installation System

### App Token Encoding

Apps are internally encoded as tokens that drive the installation logic:

```
ui_theme                  → Install UI theme app
hrms                      → Install HRMS from frappe/hrms
raven                     → Install Raven from The-Commit-Company/raven
custom|NAME|URL|BRANCH    → Install custom app from git URL on specified branch
custom|NAME|URL           → Install custom app (default branch)
```

> **Note**: The separator for custom app tokens is `|` (pipe), not `:`. This avoids ambiguity with the colon inside HTTPS (`https://`) and SSH (`git@github.com:org/repo`) URLs.

### Multiple Custom Apps

The script loops — users can add as many custom apps as needed. Each token is space-separated in the `selected_apps` string and iterated with `for token in $selected_apps`.

### Private Repository Support

When a custom app is marked private:
1. HTTPS URL is automatically converted to SSH: `https://github.com/org/app.git` → `git@github.com:org/app.git`
2. The host SSH key directory (`dirname $ssh_key_file`) is mounted as `/tmp/host_ssh:ro` in the `create-site` container
3. The container copies the key to `/home/frappe/.ssh/id_ed25519`, sets permissions, and runs `ssh-keyscan github.com` before any `bench get-app`

### Installation Sequence (Critical Ordering)

```
PostgreSQL setup (ORDER MATTERS):
  1. bench get-app frappe_pg        ← Clone repo
  2. pip install -e apps/frappe_pg  ← Install Python package
  3. bench new-site                 ← Create site (PG role created here)
  4. bench install-app frappe_pg    ← Activate app (SQL patches run)

MariaDB setup (standard):
  1. bench get-app erpnext
  2. bench new-site --install-app erpnext
  3. bench install-app {optional_apps}
```

**Why PostgreSQL ordering matters:** The `frappe_pg` Python package must be importable before `bench new-site` runs, because the PostgreSQL role/user creation happens during site initialization. The SQL patches (escaped `%` and `save_point` support) only activate at `install-app` time.

---

## 9. Platform Differences (Mac vs Linux vs VPS)

| Feature | Mac (no-sudo) | Mac (sudo) | Linux | VPS |
|---------|--------------|-----------|-------|-----|
| Port detection | `lsof` | `lsof` | `ss` | `ss` |
| Default HTTP port | 8081 | 80 | 80 | 80 |
| HTTPS port | — | — | — | 443 |
| `/etc/hosts` edits | Not needed | Optional | Required for `.local` | Not needed |
| Domain resolution | `.localhost` (native) | `.localhost` | Manual via hosts | DNS A record |
| SSL/HTTPS | No | No | No | Yes (Let's Encrypt) |
| Sudo required | No | Yes | Yes | Yes |
| Recommended for | Mac dev | Mac dev | Linux dev | Production |

---

## 10. Volumes and Persistent Data

Each site creates 4 named Docker volumes:

| Volume | Mount Path (in container) | Contents |
|--------|--------------------------|---------|
| `{site}_sites` | `/home/frappe/frappe-bench/sites` | Site configs, database backups, uploaded files |
| `{site}_logs` | `/home/frappe/frappe-bench/logs` | Frappe application logs |
| `{site}_apps` | `/home/frappe/frappe-bench/apps` | Installed application code |
| `{site}_db-data` | `/var/lib/mysql` or `/var/lib/postgresql` | Raw database files |

### Data Backup Commands

```bash
# Backup MariaDB database
docker exec {site}-db mysqldump -u root -padmin --all-databases > backup.sql

# Backup PostgreSQL database
docker exec {site}-db pg_dumpall -U postgres > backup.sql

# Backup sites volume (all site data)
docker run --rm \
  -v {site}_sites:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sites-backup.tar.gz /data

# Restore MariaDB
docker exec -i {site}-db mysql -u root -padmin < backup.sql
```

---

## 11. Networking Architecture

### Docker Networks

```
traefik_proxy (external, bridge)
  ├── traefik container
  ├── {site1}-app
  ├── {site2}-app
  └── ... (all app containers share this network)

{site}-frappe_network (internal, bridge)
  ├── {site}-app
  ├── {site}-db
  ├── {site}-redis
  └── {site}-create-site

Note: DB and Redis are NOT on traefik_proxy — only app containers are exposed.
```

### Port Exposure Summary

| Container | Internal Port | Exposed to Host | Accessible Via |
|-----------|--------------|----------------|---------------|
| Traefik | 80/443/8080/8081 | Yes (host) | Browser direct |
| App (web) | 8000 | Via Traefik only | http://domain |
| App (socket.io) | 9000 | Via Traefik only | ws://domain |
| DB (MariaDB) | 3306 | No (internal only) | docker exec |
| DB (PostgreSQL) | 5432 | No (internal only) | docker exec |
| Redis | 6379 | No (internal only) | docker exec |

---

## 12. Security Model

### Local Development (Acceptable Tradeoffs)

- HTTP only (no TLS) — acceptable for local dev
- DB not exposed to host — internal Docker network
- Traefik dashboard accessible without auth (port 8080)
- Default passwords — change after setup

### VPS Production

- HTTPS enforced with Let's Encrypt certificates
- Auto-renewal via Traefik ACME
- HTTP → HTTPS redirect via Traefik middleware
- DB still internal-only (not exposed)
- Traefik dashboard should be secured (not exposed to public)

### Hardened Setup (`secure-docker-setup.sh`)

- Non-root container user
- CPU + memory resource limits
- Read-only filesystems (where possible)
- Docker secrets instead of env var passwords
- Dropped Linux capabilities (principle of least privilege)

### Security Audit (`docker-security-tools.sh`)

```bash
# Run from others/
./docker-security-tools.sh
# Menu: Install tools → Run audit → View report
```

---

## 13. Default Credentials

| Service | Username | Password | Change Required? |
|---------|---------|---------|-----------------|
| ERPNext web | Administrator | admin | **YES — immediately** |
| MariaDB root | root | admin | Recommended |
| MariaDB frappe user | frappe | admin | Recommended |
| PostgreSQL | postgres | admin | Recommended |
| Redis | — | none | N/A (internal only) |
| Traefik Dashboard | — | none | For production: yes |

---

## 14. Common Commands Reference

### Setup

```bash
# ── Local: Mac (no sudo) ───────────────────────────────────
./Docker-Local/setup-traefik-local-mac-no-sudo.sh    # One-time Traefik setup
./Docker-Local/generate_frappe_docker_local.sh        # Create site
./Docker-Local/docker-manager-local.sh                # Manage containers

# ── Local: Linux ──────────────────────────────────────────
./Docker-Local/setup-traefik-local.sh                 # One-time Traefik setup
./Docker-Local/generate_frappe_docker_local.sh        # Create site

# ── VPS ───────────────────────────────────────────────────
./Docker-on-VPS/generate_frappe_docker.sh             # Create site + SSL
./Docker-on-VPS/docker-manager.sh                     # Manage containers
```

### Container Management

```bash
# List all running Frappe containers
docker ps --filter name={site}

# Start / stop / restart site
cd {site}-local/ && docker compose start
cd {site}-local/ && docker compose stop
cd {site}-local/ && docker compose restart

# Remove site (keeps volumes)
cd {site}-local/ && docker compose down

# Remove site + all data (DESTRUCTIVE)
cd {site}-local/ && docker compose down -v
```

### Shell Access

```bash
# App container as frappe user
docker exec -it {site}-app bash

# App container as root
docker exec -it -u root {site}-app bash

# Database shell (MariaDB)
docker exec -it {site}-db mysql -u root -padmin

# Database shell (PostgreSQL)
docker exec -it {site}-db psql -U postgres
```

### Supervisor Process Control

```bash
# Shortcut — replace {site} with actual site name
SUPERVISORCTL="docker exec {site}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf"

$SUPERVISORCTL status          # Show all process status
$SUPERVISORCTL restart web     # Restart web server
$SUPERVISORCTL restart worker  # Restart background worker
$SUPERVISORCTL restart all     # Restart everything
$SUPERVISORCTL stop all        # Stop all processes
$SUPERVISORCTL start all       # Start all processes
```

### Logs

```bash
# Container logs
docker logs {site}-app --tail 100 --follow
docker logs {site}-db --tail 50
docker logs traefik --tail 50

# Frappe application logs (inside container)
docker exec {site}-app tail -f /home/frappe/supervisor/logs/web.log
docker exec {site}-app tail -f /home/frappe/supervisor/logs/worker.log
docker exec {site}-app tail -f /home/frappe/supervisor/logs/schedule.log
```

### Bench Commands (Inside Container)

```bash
# Enter container first
docker exec -it {site}-app bash

# Then run bench commands
bench --site {sitename} migrate          # Run DB migrations
bench --site {sitename} clear-cache      # Clear application cache
bench --site {sitename} install-app {app}  # Install additional app
bench --site {sitename} backup           # Create backup
bench get-app {git_url}                  # Download new app
bench build                              # Rebuild JS/CSS assets
```

---

## 15. Troubleshooting Guide

### Site Not Loading / Blank Page

```bash
# 1. Check containers are running
docker ps | grep {site}

# 2. Check Traefik received the request
docker logs traefik --tail 30

# 3. Check app container errors
docker logs {site}-app --tail 50

# 4. Restart Frappe processes
docker exec {site}-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

### Port Already in Use (Local)

```bash
# Find what's using port 80 (Linux)
sudo ss -ltnp | grep :80

# Find what's using port 8081 (Mac)
lsof -i :8081

# Solution: Re-run Traefik setup — it auto-selects free port
./Docker-Local/setup-traefik-local-mac-no-sudo.sh
```

### Create-Site Container Keeps Restarting

```bash
# Check logs for error
docker logs {site}-create-site --tail 50

# Common causes:
# - DB not ready yet: wait 3-5 minutes
# - Wrong DB credentials in compose
# - Network issue reaching GitHub for app download
```

### PostgreSQL Site Issues

```bash
# Check frappe_pg is installed
docker exec {site}-app pip show frappe_pg

# Check PostgreSQL connection
docker exec {site}-db psql -U postgres -c "\l"

# Common fix: frappe_pg must be pip-installed BEFORE bench new-site
# If site was created without it, recreate the site
```

### SSL Certificate Not Generating (VPS)

```bash
# Check Traefik ACME logs
docker logs traefik --tail 100 | grep -i acme

# Verify DNS points to server
nslookup yourdomain.com

# Verify port 80/443 are open
curl -v http://yourdomain.com

# Check acme.json exists and has content
cat /path/to/letsencrypt/acme.json
```

### Traefik Not Routing to Site

```bash
# Check container has traefik labels
docker inspect {site}-app | grep -A5 Labels

# Check traefik_proxy network
docker network inspect traefik_proxy | grep {site}

# Site app container must be on traefik_proxy network
# Check docker-compose.yml networks section
```

---

## 16. Design Patterns Used

### 1. Dynamic Template Generation (Heredoc Pattern)

All docker-compose.yml files are generated at runtime using bash heredocs:
```bash
cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  db:
    image: ${DB_IMAGE}
    ...
EOF
```
This avoids maintaining static template files and allows full customization per user input.

### 2. Configuration Persistence Pattern

`.traefik-local-config` carries settings across script runs:
```bash
# Written once by Traefik setup
echo "TRAEFIK_HTTP_PORT=8081" > .traefik-local-config

# Read by every subsequent site generation
source .traefik-local-config
```

### 3. App Token Pattern

App selections encoded as simple tokens for flexible list building:
```bash
APPS_TO_INSTALL="ui_theme hrms custom:my_app:https://github.com/org/app.git:main"
for token in $APPS_TO_INSTALL; do
    # parse and handle each token
done
```

### 4. Container Auto-Discovery Pattern

Manager scripts find sites without a config database:
```bash
# Discover all Frappe app containers
docker ps --format '{{.Names}}' | grep '\-app$'
```

### 5. One-Shot Setup Container Pattern

`create-site` container runs setup once then self-removes:
```yaml
create-site:
  restart: "no"         # Never restart
  # After setup completes, container exits with code 0
  # Docker does not restart it (restart: "no")
```

### 6. Color-Coded Output Pattern

All scripts use consistent color codes:
```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

echo -e "${GREEN}✓ Setup complete${NC}"
echo -e "${RED}✗ Error: Docker not running${NC}"
```

---

## 17. Active Development State

### Current Git Status (as of 2026-05-14)

```
Branch: main

Recent Commits:
  6ecaf3e  fix: patch query_transformers.py to implement robust DDL protection
  88fcd41  feat: update frappe_pg cloning logic and add robust patching for db_functions.py
  d52b35d  build: Update frappe_pg git clone URL from excel-azmin to NileshPBrainmine
  5470c39  fix: Skip query transformations for dictionary values to prevent mangling PyPika named parameters
  856d506  indent NEW_CODE in heredoc to prevent YAML block scalar break
```

### Active Work Area

Both `generate_frappe_docker_local.sh` and `generate_frappe_docker.sh` (VPS) are up to date.

### Known Considerations

- `frappe_pg` is cloned from NileshPBrainmine fork (not official frappe org)
- PostgreSQL setup requires specific ordering: pip install → new-site → install-app
- Frappe v15 requires `%` escaping in raw SQL queries (PostgreSQL driver behavior)
- Virtual environment pip (`./env/bin/pip`) must be used explicitly, not system pip
- Custom app token separator is `|` (pipe) — colons are reserved for SSH/HTTPS URLs
- SSH private key is mounted read-only at `/tmp/host_ssh` inside the create-site container; never embedded in the compose file

---

## Appendix: ERPNext Version Info

```
frappe/erpnext Docker image: v15.70.0
Frappe Framework:  v15.x (Python 3.11+)
ERPNext:           v15.x
MariaDB:           10.6
PostgreSQL:        14
Redis:             7
Traefik:           v3.6.9
```

---

*Generated by complete codebase analysis — 2026-03-27*
*Project: Frappe Docker Manager | Owner: Brainsmine / Invento Software Limited*
*Author: Nilesh Patil | Contact: patilnilesh0278@gmail.com*
