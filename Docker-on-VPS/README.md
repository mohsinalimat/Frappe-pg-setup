# Docker-on-VPS: Frappe / ERPNext Production Deployment

Deploy a live ERPNext site on a VPS or cloud server with HTTPS, a real domain name, and automatic SSL certificates.

---

## Before You Start — Prerequisites

| Requirement | Details |
|-------------|---------|
| A VPS or cloud server | Any provider: DigitalOcean, AWS, Hetzner, Linode, etc. |
| Ubuntu / Debian Linux | Recommended OS for the server |
| Root or sudo access | Required to run Docker and manage ports |
| Docker installed | `docker --version` |
| Docker Compose installed | `docker compose version` |
| A domain name | e.g., `mycompany.com` — must point to your server's IP |
| Ports 80 and 443 open | Required for HTTP/HTTPS and SSL certificates |

> **New to VPS?** Start with Ubuntu 22.04. Install Docker with:
> ```bash
> curl -fsSL https://get.docker.com | sh
> ```

---

## Quick Start

```bash
# Step 1: Make the script executable
chmod +x generate_frappe_docker.sh

# Step 2: Run the setup (follow the prompts)
./generate_frappe_docker.sh

# Step 3: Manage your site anytime
./docker-manager.sh
```

---

## Step-by-Step: What Happens During Setup

When you run `generate_frappe_docker.sh`, it asks you questions. Here is exactly what each one means:

---

### Question 1 — SSL / HTTPS

```
Do you want to enable SSL/HTTPS? (y/n):
```

| Choice | What it does |
|--------|-------------|
| `y` | Sets up HTTPS with a free Let's Encrypt SSL certificate. Visitors see the padlock icon. |
| `n` | HTTP only — useful for testing or internal use. No certificate needed. |

> **For a live business site: always choose `y`.**

---

### Question 2 — Database Type

```
Use PostgreSQL instead of MariaDB? (y/n, default: n):
```

| Choice | What it means |
|--------|--------------|
| `n` (default) | Use **MariaDB 10.6** — the standard Frappe database. Stable and well-tested. |
| `y` | Use **PostgreSQL 14** — for users who specifically need it. |

> **Beginners: press Enter** to use MariaDB.

If you choose PostgreSQL, you will also be asked:
- **External or containerized?** — choose `n` (containerized) unless you have a separate PostgreSQL server
- **PostgreSQL superuser username** — default is `frappe_root`, press Enter to accept
- **PostgreSQL superuser password** — enter a secure password

---

### Question 3 — Domain Name

```
Enter site name (e.g. example.com):
```

Enter your domain name exactly as it is (e.g. `mycompany.com` or `erp.mycompany.com`).

> **Important**: Before running this script, make sure your domain's DNS **A record** points to your server's IP address. If it doesn't, SSL certificate generation will fail.

How to check:
```bash
nslookup mycompany.com
# Should show your server's IP address
```

---

### Question 4 — Install UI Theme?

```
Install UI Theme? (y/n):
```

A custom color and branding theme for ERPNext. Choose `y` to install, `n` to skip.

---

### Question 5 — Install HRMS?

```
Install HRMS (HR & Payroll)? (y/n):
```

The **HR & Payroll** module — manage employees, attendance, leave, and payroll.

> Note: Installing HRMS runs extra database migrations. This is handled automatically.

---

### Question 6 — Install Raven?

```
Install Raven (Chat)? (y/n):
```

A team **messaging / chat** app built for ERPNext.

---

### Question 7 — Custom App?

```
Add a custom app? (y/n):
```

Install your own Frappe app from a git repository. You will be asked for:
- App name (e.g. `my_app`)
- Git URL (e.g. `https://github.com/yourname/my_app`)
- Branch name (e.g. `main` or `version-15`)

---

### Question 8 — SSL Email and Cloudflare (HTTPS only)

If you chose HTTPS, you will be asked:

```
Enter your Cloudflare API token (leave blank for HTTP challenge):
Enter email for Let's Encrypt notifications:
```

| Option | When to use |
|--------|------------|
| **Leave Cloudflare token blank** | Standard setup — Let's Encrypt contacts your server directly |
| **Enter Cloudflare token** | If your domain is behind Cloudflare proxy (orange cloud enabled) |

Your email is required so Let's Encrypt can notify you before certificates expire.

---

### What Happens Next (Automatic)

After answering the questions, the script:

1. Creates a project folder named after your domain
2. Generates a `docker-compose.yml` file
3. Starts the 4 containers
4. Downloads selected apps (only if not already downloaded)
5. Creates the ERPNext site with your database
6. Installs ERPNext and any apps you chose
7. Builds JavaScript/CSS assets
8. Runs database migrations
9. Configures Traefik with your domain (and SSL if chosen)

> **This takes 5–15 minutes.** You will see log output in the terminal — this is normal. Wait until you see the final "Access Information" section.

---

## After Setup — Access Your Site

| Field | Value |
|-------|-------|
| URL (HTTP) | `http://yourdomain.com` |
| URL (HTTPS) | `https://yourdomain.com` |
| Username | `Administrator` |
| Password | `admin` |

> **Change your password immediately after first login!**

---

## What Gets Created (4 Containers)

| Container | What it does |
|-----------|-------------|
| `yoursite-app` | Runs ERPNext — web server, background workers, and scheduler |
| `yoursite-db` | Stores all your data (MariaDB or PostgreSQL) |
| `yoursite-redis` | Handles caching, job queues, and live page updates |
| `yoursite-create-site` | Temporary — sets up the site, then removes itself |

---

## Apps Installed

| App | Always installed? | Notes |
|-----|-------------------|-------|
| ERPNext | Yes | Full business ERP |
| frappe_pg | Yes (PostgreSQL only) | PostgreSQL compatibility layer |
| UI Theme | Optional | Custom branding |
| HRMS | Optional | HR & Payroll |
| Raven | Optional | Team chat |
| Custom | Optional | Your own app |

---

## Files Created on Your Server

After setup, you will find a new folder named after your domain:

```
yourdomain-com/
├── .env                                    # Environment variables
├── yourdomain-com-docker-compose.yml       # Docker Compose configuration
└── traefik-letsencrypt/                    # SSL certificate files (if HTTPS)
    └── acme.json
```

---

## Managing Your Site

Use the interactive manager for all container operations:

```bash
./docker-manager.sh
```

**Menu options:**
1. Show running containers
2. Open terminal in container (as frappe user)
3. Open terminal in container (as root)
4. Manage Frappe processes (start / stop / restart)
5. View logs
6. Start / stop / restart / remove containers
7. Show site information
8. Root access to a specific container
9. Transfer files between host and container
10. Install software packages inside container
11. Exit

---

## Manual Container Commands

```bash
# Go to your site folder
cd yourdomain-com/

# Stop the site
docker compose -f yourdomain-com-docker-compose.yml down

# Start the site
docker compose -f yourdomain-com-docker-compose.yml up -d

# Check container status
docker compose -f yourdomain-com-docker-compose.yml ps

# View logs
docker compose -f yourdomain-com-docker-compose.yml logs
```

---

## Process Management

ERPNext runs 3 processes inside the app container via **Supervisor**:

| Process | What it does |
|---------|-------------|
| `web` | The web server — serves ERPNext pages |
| `worker` | Runs background jobs (emails, exports, etc.) |
| `schedule` | Runs scheduled tasks (like cron) |

**Check process status:**
```bash
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf status
```

**Restart a process:**
```bash
# Restart web server
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart web

# Restart background worker
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart worker

# Restart scheduler
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart schedule

# Restart everything
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

**View live logs:**
```bash
docker exec yourdomain-com-app tail -f /home/frappe/supervisor/logs/web.log
docker exec yourdomain-com-app tail -f /home/frappe/supervisor/logs/worker.log
docker exec yourdomain-com-app tail -f /home/frappe/supervisor/logs/schedule.log
docker exec yourdomain-com-app tail -f /home/frappe/supervisor/logs/supervisord.log
```

---

## What Is Traefik?

**Traefik** is a reverse proxy that runs in front of your ERPNext container. It:
- Routes requests from `yourdomain.com` to your ERPNext container
- Obtains and renews SSL certificates automatically (via Let's Encrypt)
- Handles HTTP → HTTPS redirects
- Supports multiple sites on the same server

The script sets up Traefik automatically. You can view its dashboard at:
```
http://your-server-ip:8080
```

---

## Common Troubleshooting

### Site not loading
```bash
# Check if containers are running
docker ps

# Check app container logs
docker logs yourdomain-com-app --tail 50

# Restart all Frappe processes
docker exec yourdomain-com-app /home/frappe/.local/bin/supervisorctl \
  -c /home/frappe/supervisor/supervisord.conf restart all
```

### SSL certificate not generating
1. Check your domain's DNS A record points to your server IP
2. Make sure ports 80 and 443 are open in your firewall:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw status
   ```
3. Check Traefik logs:
   ```bash
   docker logs traefik --tail 50
   ```

### Port already in use
```bash
# Check what is using port 80 or 443
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

### Container keeps restarting
```bash
# Read the error
docker logs yourdomain-com-app --tail 30

# Common cause: domain DNS not yet propagated — wait and retry
```

### Mixed HTTP/HTTPS issues (multiple sites)
```bash
# Run the test script to diagnose
chmod +x test_mixed_setup.sh
./test_mixed_setup.sh

# Fix Traefik for HTTPS (comprehensive)
chmod +x fix_traefik_https.sh
./fix_traefik_https.sh
```

### Reset Everything (start over)
```bash
cd yourdomain-com/
docker compose -f yourdomain-com-docker-compose.yml down -v
```
This removes all containers and data. Then re-run `generate_frappe_docker.sh`.

---

## Multiple Sites

Run the script multiple times with different domain names. All sites share the same Traefik instance.

```bash
./generate_frappe_docker.sh   # site1.com
./generate_frappe_docker.sh   # site2.com
./generate_frappe_docker.sh   # site3.com
```

---

## Cloudflare Integration

If your domain uses Cloudflare, you need a Cloudflare API token for DNS challenge SSL certificates.

**How to get a Cloudflare API token:**
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click your profile → **API Tokens**
3. Click **Create Token**
4. Use the **Edit zone DNS** template
5. Set **Zone Resources** → your domain
6. Copy the token and paste it when the script asks

**Cloudflare proxy settings:**
- Set SSL/TLS mode to **Full** or **Full (strict)**
- Enable **Always Use HTTPS**

---

## Backup Your Data

```bash
# Backup database (MariaDB)
docker exec yourdomain-com-db mysqldump -u root -padmin --all-databases > backup.sql

# Backup site files
docker run --rm \
  -v yourdomain-com_sites:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sites-backup.tar.gz /data
```

**Restore:**
```bash
# Restore database
docker exec -i yourdomain-com-db mysql -u root -padmin < backup.sql

# Restore site files
docker run --rm \
  -v yourdomain-com_sites:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/sites-backup.tar.gz -C /
```

---

## Firewall Setup (Ubuntu/Debian)

```bash
sudo ufw allow 22/tcp     # SSH — do this FIRST or you will lock yourself out
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw enable
sudo ufw status
```

---

## Environment Variables

The script creates a `.env` file in your site folder:

```bash
ERPNEXT_VERSION=v15.70.0               # ERPNext image version
DB_PASSWORD=admin                       # Database password — change this!
LETSENCRYPT_EMAIL=you@example.com       # Email for SSL certificate alerts
FRAPPE_SITE_NAME_HEADER=yourdomain.com  # Your domain name
SITES=yourdomain.com                    # Site name
```

---

## Security Checklist

- [ ] Change the default ERPNext password (`admin` → something strong)
- [ ] Change the database password in `.env`
- [ ] Enable HTTPS / SSL
- [ ] Open only necessary firewall ports (22, 80, 443)
- [ ] Use Cloudflare "Full (strict)" SSL if using Cloudflare proxy
- [ ] Keep Docker and your OS updated

---

## Available Scripts

| Script | Purpose |
|--------|---------|
| `generate_frappe_docker.sh` | Create a new ERPNext site |
| `docker-manager.sh` | Interactive site manager |
| `fix_traefik_https.sh` | Upgrade HTTP Traefik to support HTTPS |
| `manual_fix_traefik.sh` | Quick manual Traefik HTTPS fix |
| `test_mixed_setup.sh` | Test HTTP/HTTPS mixed configuration |

---

## Main Documentation

- **Full project guide**: [../README.md](../README.md)
- **Database access guide (MariaDB & PostgreSQL)**: [DATABASE.md](DATABASE.md)
- **Local development setup**: [../Docker-Local/README.md](../Docker-Local/README.md)

---

**Tip**: Use `./docker-manager.sh` for day-to-day operations — it handles everything through a simple numbered menu.
