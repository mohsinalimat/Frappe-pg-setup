# Docker-Local: Frappe / ERPNext Local Development Setup

Run a full ERPNext site on your own computer for development, testing, or learning — no internet domain required.

---

## Before You Start — Prerequisites

| Requirement | How to check |
|-------------|-------------|
| Docker Desktop | `docker --version` |
| Docker Compose | `docker compose version` |
| Bash shell | Built-in on Mac / Linux |

> **Mac users**: Make sure Docker Desktop is open and running before you begin.

---

## Quick Start

### Mac Users (Recommended — no sudo needed)

```bash
# Step 1: Start the local reverse proxy (Traefik)
./setup-traefik-local-mac-no-sudo.sh

# Step 2: Create your ERPNext site (follow the prompts)
./generate_frappe_docker_local.sh

# Step 3: Manage your site anytime
./docker-manager-local.sh
```

### Mac Users (with sudo)

```bash
sudo ./setup-traefik-local-mac.sh
sudo ./generate_frappe_docker_local.sh
sudo ./docker-manager-local.sh
```

### Linux Users

```bash
sudo ./setup-traefik-local.sh
sudo ./generate_frappe_docker_local.sh
sudo ./docker-manager-local.sh
```

---

## Step-by-Step: What Happens During Setup

When you run `generate_frappe_docker_local.sh`, the script will ask you a series of questions. Here is what each one means:

---

### Question 1 — Database Type

```
Use PostgreSQL instead of MariaDB? (y/n, default: n):
```

| Choice | What it means |
|--------|--------------|
| `n` (default) | Use **MariaDB 10.6** — the standard Frappe database. Recommended for all users. |
| `y` | Use **PostgreSQL 14** — only if you specifically need it. |

> **Beginners: press Enter** to use MariaDB (the default).

If you choose PostgreSQL, you will also be asked:
- External host or containerized? — choose `n` (containerized) unless you already have a PostgreSQL server running
- PostgreSQL superuser username (default: `frappe_root`)
- PostgreSQL superuser password

---

### Question 2 — Site Name

```
Enter site name (e.g. demo.local, mysite.localhost):
```

This is the address you will use in your browser to access ERPNext.

| Recommended format | Example URL |
|--------------------|-------------|
| `yourname.localhost` | `http://yourname.localhost:8081` |
| `yourname.local` | `http://yourname.local:8081` |

> **Mac tip**: Use `.localhost` — it works automatically with no extra setup.
> **Linux tip**: Use `.local` — the script will add it to `/etc/hosts` for you.

---

### Question 3 — Install UI Theme?

```
Install UI Theme? (y/n):
```

A custom color/branding theme for ERPNext. Choose `y` to install it, `n` to skip.

---

### Question 4 — Install HRMS?

```
Install HRMS (HR & Payroll)? (y/n):
```

The **HR & Payroll** module for managing employees, attendance, payroll, and leave.

> Note: Installing HRMS takes extra time as it runs additional database migrations.

---

### Question 5 — Install Raven?

```
Install Raven (Chat)? (y/n):
```

A team **chat / messaging** app built for ERPNext.

---

### Question 6 — Custom Apps (one or more)

```
Add a custom app? (y/n):
```

Install your own Frappe apps from git repositories. You can add **as many as you need** — the script keeps asking until you say no.

For each app you will be asked:

| Prompt | Example |
|--------|---------|
| App name | `grand_renovations_app` |
| Git URL (HTTPS or SSH) | `https://github.com/yourname/my_app.git` |
| Branch (blank = default) | `main` or `version-15` |
| Private repository? (y/n) | `y` for private, `n` for public |

**Public repos** (`n`): cloned with HTTPS — no extra setup needed.

**Private repos** (`y`):
- The script automatically converts `https://github.com/…` to `git@github.com:…`
- It checks for an existing SSH key (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)
- If no key exists, it generates one automatically
- It displays your **public key** — copy it and add it to GitHub under **Settings → SSH and GPG keys → New SSH key**
- Press Enter once added; the script tests the connection and continues
- The key is securely mounted read-only into the setup container

```
Add another custom app? (y/n):   ← keeps asking until you say n
```

---

### What Happens Next (Automatic)

After you answer the questions, the script:

1. Creates a `docker-compose.yml` file for your site
2. Starts the containers
3. Downloads the selected apps (only if not already downloaded)
4. Creates the ERPNext site with your database
5. Installs ERPNext and any apps you selected
6. Builds the JavaScript/CSS assets
7. Runs database migrations
8. Shows you the access URL

> **This takes 5–15 minutes** depending on your internet speed and machine. You will see log output in the terminal — this is normal.

---

## After Setup — Access Your Site

| Field | Value |
|-------|-------|
| URL | `http://yoursite.localhost:8081` (Mac) or `http://yoursite.local:8081` (Linux) |
| Username | `Administrator` |
| Password | `admin` |

> **Change your password** immediately after first login!

---

## What Gets Created (4 Containers)

| Container | What it does |
|-----------|-------------|
| `yoursite-app` | Runs ERPNext — the web server, background workers, and scheduler |
| `yoursite-db` | Stores all your data (MariaDB or PostgreSQL) |
| `yoursite-redis` | Handles caching, job queues, and live page updates |
| `yoursite-create-site` | Temporary — sets up the site, then removes itself |

---

## Apps Installed

| App | Always installed? | Notes |
|-----|-------------------|-------|
| ERPNext | Yes | Full business ERP |
| frappe_pg | Yes (PostgreSQL only) | Makes Frappe work with PostgreSQL |
| UI Theme | Optional | Custom branding |
| HRMS | Optional | HR & Payroll |
| Raven | Optional | Team chat |
| Custom (×N) | Optional | One or more of your own apps (public or private) |

---

## Managing Your Site

Use the interactive manager script for all container operations:

```bash
./docker-manager-local.sh        # Mac (no sudo)
sudo ./docker-manager-local.sh   # Linux
```

**Menu options:**
1. Show running containers
2. Open terminal in container (as frappe user)
3. Open terminal in container (as root)
4. Manage Frappe processes (start / stop / restart via Supervisor)
5. View logs
6. Start / stop / restart / remove containers
7. Show site information
8. Root access to a specific container
9. Transfer files between host and container
10. Install software packages inside container
11. Exit

---

## Process Management

ERPNext runs 3 processes inside the app container, managed by **Supervisor**:

| Process | What it does |
|---------|-------------|
| `web` | The web server — serves ERPNext pages |
| `worker` | Runs background jobs (emails, exports, etc.) |
| `schedule` | Runs scheduled tasks (like cron) |

**Check process status:**
```bash
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf status
```

**Restart a specific process:**
```bash
# Restart web server
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart web

# Restart background worker
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart worker

# Restart scheduler
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart schedule

# Restart everything
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

**View live logs:**
```bash
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/web.log
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/worker.log
docker exec SITE_NAME-app tail -f /home/frappe/supervisor/logs/schedule.log
```

---

## Traefik — What Is It and Why Do You Need It?

**Traefik** is a reverse proxy that sits in front of your ERPNext container and routes web traffic to it. Think of it as a traffic controller.

- It lets you use a domain name like `mysite.localhost` instead of `localhost:8000`
- It handles routing automatically based on Docker container labels
- On Mac it runs without sudo; on Linux it needs sudo

You only need to run the Traefik setup script **once**. After that, you can create as many sites as you want — Traefik stays running in the background.

---

## Traefik Dashboard

You can view Traefik's routing information at:
```
http://localhost:8080
```

This shows all routes Traefik is handling — useful for debugging.

---

## Common Troubleshooting

### Site is not loading
```bash
# 1. Check if containers are running
docker ps

# 2. Check app container logs
docker logs SITE_NAME-app --tail 50

# 3. Restart all processes
docker exec SITE_NAME-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

### "Port already in use" error
This means something else is using port 80 or 8081.
```bash
# Check what is using port 80
sudo ss -ltnp | grep :80

# Re-run Traefik setup — it handles port conflicts automatically
./setup-traefik-local-mac-no-sudo.sh   # Mac
sudo ./setup-traefik-local.sh          # Linux
```

### Container keeps restarting
- Wait 2–3 minutes after first run — the `create-site` container takes time
- Check logs: `docker logs SITE_NAME-app --tail 30`

### Site domain not found in browser
On Linux, the script adds your site to `/etc/hosts`. Check it:
```bash
cat /etc/hosts | grep yoursite
```

If missing, add it manually:
```bash
echo "127.0.0.1 yoursite.local" | sudo tee -a /etc/hosts
```

On Mac with `.localhost` domains, no hosts file editing is needed.

### App installation failed mid-way
If create-site failed, you can delete the site folder and re-run:
```bash
# Remove the generated folder
rm -rf yoursite-local/

# Re-run the generator
./generate_frappe_docker_local.sh
```

---

## Multiple Sites

You can create multiple independent ERPNext sites on the same machine. Just run the generator script again with a different site name.

```bash
./generate_frappe_docker_local.sh   # demo.localhost
./generate_frappe_docker_local.sh   # test.localhost
```

Each site gets its own set of 4 containers. They all share the same Traefik instance.

---

## Folder Structure

```
Docker-Local/
├── generate_frappe_docker_local.sh     # Main script — creates a new site
├── docker-manager-local.sh             # Interactive site manager
├── setup-traefik-local-mac-no-sudo.sh  # Mac Traefik setup (no sudo) — recommended
├── setup-traefik-local-mac.sh          # Mac Traefik setup (with sudo)
├── setup-traefik-local.sh              # Linux Traefik setup
├── traefik-docker-compose.yml          # Traefik Docker Compose config
├── .traefik-local-config               # Stores your chosen Traefik port
├── helper-screenshot/                  # Documentation screenshots
└── MAC_COMPATIBILITY.md                # Mac-specific guide
```

---

## Configuration File: `.traefik-local-config`

After running the Traefik setup, this file is created automatically. It stores your port settings:

```bash
TRAEFIK_HTTP_PORT=8081    # The port your sites are accessible on
USE_LOCALHOST=true         # Whether to use .localhost domains
```

The `generate_frappe_docker_local.sh` script reads this file and shows you the correct URL.

---

## Security Notes

- **Local only** — these containers are not accessible from the internet
- **Default password is `admin`** — change it after first login
- **HTTP only** — no SSL certificate (not needed for local development)

---

## Mac-Specific Tips

- Use `.localhost` domains — they work natively on macOS without editing `/etc/hosts`
- Use `setup-traefik-local-mac-no-sudo.sh` — no sudo needed
- Default port is `8081` — avoids conflicts with macOS built-in services on port 80
- Docker Desktop must be running before you start

---

## Main Documentation

- **Full project guide**: [../README.md](../README.md)
- **Database access guide (MariaDB & PostgreSQL)**: [DATABASE.md](DATABASE.md)
- **Mac compatibility details**: [MAC_COMPATIBILITY.md](MAC_COMPATIBILITY.md)
- **VPS / Production setup**: [../Docker-on-VPS/README.md](../Docker-on-VPS/README.md)

---

**Tip**: Use `docker-manager-local.sh` for day-to-day operations — it handles everything through a simple numbered menu.
