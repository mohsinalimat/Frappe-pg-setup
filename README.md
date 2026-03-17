# Frappe / ERPNext Docker Manager

Automated Docker scripts to deploy **Frappe** and **ERPNext** on any machine — from a laptop to a cloud server — with just a few prompts.

---

## What Is This?

**Frappe** is an open-source web framework. **ERPNext** is a full-featured business management system (ERP) built on Frappe.

This project gives you ready-made shell scripts that:
- Download and configure everything automatically
- Ask you simple Yes/No questions during setup
- Create a working ERPNext site in under 10 minutes

No manual Docker file editing required.

---

## Before You Start — Prerequisites

Make sure the following are installed on your machine:

| Requirement | How to check |
|-------------|-------------|
| Docker | `docker --version` |
| Docker Compose | `docker compose version` |
| Git | `git --version` |
| Bash shell | Built-in on Mac/Linux |

> **No Docker?** Download Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop/)

---

## Choose Your Setup Type

### Option A — Local Development (on your laptop or desktop)
Use this if you want to:
- Try ERPNext for the first time
- Develop or test customizations
- Work offline

**Go to:** [Docker-Local/README.md](Docker-Local/README.md)

---

### Option B — VPS / Cloud Server (production website)
Use this if you want to:
- Deploy ERPNext for real business use
- Make it accessible from the internet
- Use a real domain name (e.g., `mycompany.com`)
- Enable HTTPS / SSL

**Go to:** [Docker-on-VPS/README.md](Docker-on-VPS/README.md)

---

## Quick Overview — What Each Script Does

### Local Setup (`Docker-Local/`)
```
Step 1: setup-traefik-local-mac-no-sudo.sh   ← Start the local reverse proxy (Mac)
           OR setup-traefik-local.sh          ← (Linux)

Step 2: generate_frappe_docker_local.sh       ← Answer questions, site is created

Step 3: docker-manager-local.sh              ← Manage your running site
```

### VPS Setup (`Docker-on-VPS/`)
```
Step 1: generate_frappe_docker.sh            ← Answer questions, site is created

Step 2: docker-manager.sh                    ← Manage your running site
```

---

## What Gets Created (4 Containers)

When you run the setup script, it creates exactly **4 Docker containers**:

| Container | What it does |
|-----------|-------------|
| `yoursite-app` | Runs the ERPNext web server, background workers, and scheduler |
| `yoursite-db` | Stores all your ERPNext data (MariaDB or PostgreSQL) |
| `yoursite-redis` | Handles caching, background job queue, and live updates |
| `yoursite-create-site` | Temporary — downloads apps, sets up the site, then exits |

> The `create-site` container removes itself automatically after setup is complete.

---

## What Apps Can You Install?

During setup, the script asks you which apps to install:

| App | Description | Installed? |
|-----|-------------|------------|
| **ERPNext** | Full business ERP (accounting, inventory, HR, etc.) | Always |
| **frappe_pg** | PostgreSQL compatibility layer | Auto (PostgreSQL only) |
| **UI Theme** | Custom branding / color theme | Optional (y/n) |
| **HRMS** | HR & Payroll management | Optional (y/n) |
| **Raven** | Team chat messaging | Optional (y/n) |
| **Custom App** | Any app from a git URL | Optional (y/n) |

---

## Database Options

| Database | Best For |
|----------|----------|
| **MariaDB 10.6** (default) | Most users — stable, well-tested with Frappe |
| **PostgreSQL 14** | Users who specifically need PostgreSQL |

> For beginners, just press Enter to use MariaDB (the default).

---

## After Setup — Login to ERPNext

| Field | Value |
|-------|-------|
| URL (Local) | `http://yoursite.localhost:8081` |
| URL (VPS) | `http://yourdomain.com` or `https://yourdomain.com` |
| Username | `Administrator` |
| Password | `admin` |

> **Change the password** after your first login!

---

## Environment Comparison

| Feature | Local Development | VPS / Cloud |
|---------|-------------------|-------------|
| Purpose | Testing & development | Live production |
| Image | `frappe/erpnext:v15.70.0` | `frappe/erpnext:v15.70.0` |
| Containers | 4 (optimized) | 4 (minimal) |
| Database | MariaDB or PostgreSQL | MariaDB or PostgreSQL |
| SSL / HTTPS | No (HTTP only) | Yes (Let's Encrypt) |
| Domain | `yoursite.localhost` | `yourdomain.com` |
| Internet access | No (local only) | Yes |
| Sudo required | Optional (Mac) / Yes (Linux) | Yes |

---

## Managing Your Site

After setup, use the interactive manager script:

```bash
# Local
./Docker-Local/docker-manager-local.sh

# VPS
./docker-manager.sh
```

**The manager menu lets you:**
1. See all running containers
2. Open a terminal inside a container
3. Start / stop / restart containers
4. View real-time logs
5. Manage Frappe processes (web server, workers, scheduler)
6. Transfer files in and out of containers
7. Install extra packages inside containers

---

## Managing Frappe Processes

All Frappe processes run inside the app container using **Supervisor**. There are 3 processes:

| Process | What it does |
|---------|-------------|
| `web` | Serves the ERPNext website (`bench serve`) |
| `worker` | Runs background jobs (emails, reports, etc.) |
| `schedule` | Runs scheduled tasks (like cron jobs) |

**Useful commands** (replace `SITE_NAME` with your actual site folder name):

```bash
# Check if all processes are running
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf status

# Restart the web server (if site is slow or not loading)
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart web

# Restart background workers
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart worker

# Restart scheduler
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart schedule

# Restart everything at once
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

**View logs:**
```bash
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/web.log
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/worker.log
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/schedule.log
```

---

## Common Troubleshooting

### Site not loading / blank page
```bash
# Check if containers are running
docker ps

# Check the app container logs
docker logs SITE_NAME-app --tail 50

# Restart all Frappe processes
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

### Port already in use (local setup)
```bash
# See what is using port 80
sudo ss -ltnp | grep :80

# Run local Traefik setup script — it handles port conflicts automatically
./Docker-Local/setup-traefik-local.sh
```

### Container keeps restarting
```bash
# Read the error from logs
docker logs SITE_NAME-app --tail 30

# Common fix: wait 2-3 minutes after first run — create-site takes time
```

### SSL certificate not working (VPS)
```bash
# Check Traefik logs
docker logs traefik --tail 50

# Verify your domain points to your server
nslookup yourdomain.com
```

---

## Multiple Sites

You can run multiple ERPNext sites on the same machine — just run the script again with a different site name. Each site gets its own set of 4 containers.

```bash
# Create first site
./generate_frappe_docker_local.sh   # e.g., site1.localhost

# Create second site (run again)
./generate_frappe_docker_local.sh   # e.g., site2.localhost
```

---

## Backup Your Data

```bash
# Backup database (MariaDB)
docker exec SITE_NAME-db mysqldump -u root -padmin --all-databases > backup.sql

# Backup site files (volumes)
docker run --rm \
  -v SITE_NAME_sites:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sites-backup.tar.gz /data
```

---

## Folder Structure

```
frappe-docker-manager/
├── Docker-Local/                          # Local development tools
│   ├── generate_frappe_docker_local.sh    # Create a local site
│   ├── docker-manager-local.sh            # Manage local containers
│   ├── setup-traefik-local.sh             # Traefik for Linux
│   ├── setup-traefik-local-mac.sh         # Traefik for Mac (sudo)
│   ├── setup-traefik-local-mac-no-sudo.sh # Traefik for Mac (no sudo)
│   └── README.md                          # Full local setup guide
│
├── Docker-on-VPS/                         # VPS / production tools
│   ├── generate_frappe_docker.sh          # Create a VPS site
│   ├── docker-manager.sh                  # Manage VPS containers
│   └── README.md                          # Full VPS setup guide
│
└── README.md                              # This file
```

---

## Full Guides

- **Local Development**: [Docker-Local/README.md](Docker-Local/README.md)
- **VPS / Cloud Server**: [Docker-on-VPS/README.md](Docker-on-VPS/README.md)

---

## License

This project is open source and available under the MIT License.
