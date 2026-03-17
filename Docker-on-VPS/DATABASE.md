# Database Access Guide — MariaDB & PostgreSQL (VPS)

This guide explains how to connect to, view, and manage the database inside your ERPNext Docker containers on a VPS or cloud server.

---

## Which Database Is Running?

When you created your site, you chose either **MariaDB** (default) or **PostgreSQL**.

```bash
docker ps --format "table {{.Names}}\t{{.Image}}" | grep "\-db"
```

- If you see `mariadb` → you are using **MariaDB**
- If you see `postgres` → you are using **PostgreSQL**

Replace `SITE_NAME` throughout this guide with your actual site folder name (e.g. `yourdomain-com`).

---

---

# MariaDB

---

## Connect to MariaDB — Inside the Container

```bash
docker exec -it SITE_NAME-db mysql -u root -padmin
```

You are now in the MySQL/MariaDB shell.

---

## Useful MariaDB Commands

```sql
-- List all databases
SHOW DATABASES;

-- Switch to your ERPNext database
USE `your_site_name`;

-- List all tables
SHOW TABLES;

-- See the structure of a table
DESCRIBE `tabDocType`;

-- Count records in a table
SELECT COUNT(*) FROM `tabCustomer`;

-- View recent records
SELECT name, creation FROM `tabCustomer` ORDER BY creation DESC LIMIT 10;

-- Exit
EXIT;
```

---

## Find Your ERPNext Database Name

```bash
docker exec -it SITE_NAME-db mysql -u root -padmin -e "SHOW DATABASES;"
```

The database name is your site name with dots replaced by underscores:
- `example.com` → `example_com`
- `erp.mycompany.com` → `erp_mycompany_com`

---

## Expose MariaDB Port for GUI Access

> **Security warning**: Only do this in a controlled environment. Never expose port 3306 publicly on a production server.

Add `ports` to the `db` service in your `SITE_NAME-docker-compose.yml`:

```yaml
  db:
    image: mariadb:10.6
    ports:
      - "127.0.0.1:3306:3306"    # Bind to localhost only — never 0.0.0.0 on VPS
```

Restart the db:
```bash
cd SITE_NAME/
docker compose -f SITE_NAME-docker-compose.yml restart db
```

Then connect via SSH tunnel from your local machine:
```bash
ssh -L 3306:127.0.0.1:3306 user@your-server-ip
```

Now connect your GUI tool to `127.0.0.1:3306`.

---

## Common MariaDB Queries for ERPNext

```sql
USE `your_site_name`;

-- List all ERPNext apps installed
SELECT * FROM `tabInstalled Applications`;

-- View all users
SELECT name, email, enabled FROM `tabUser`;

-- View all customers
SELECT name, customer_name, creation FROM `tabCustomer` LIMIT 20;

-- View all sales invoices
SELECT name, customer, grand_total, status FROM `tabSales Invoice` LIMIT 20;

-- View all items
SELECT name, item_name, item_group FROM `tabItem` LIMIT 20;

-- Check system settings
SELECT * FROM `tabSystem Settings` LIMIT 1;
```

---

## Backup MariaDB

```bash
# Full database backup
docker exec SITE_NAME-db mysqldump -u root -padmin --all-databases > mariadb_backup.sql

# Backup only ERPNext site database
docker exec SITE_NAME-db mysqldump -u root -padmin your_site_name > site_backup.sql
```

## Restore MariaDB

```bash
docker exec -i SITE_NAME-db mysql -u root -padmin < mariadb_backup.sql
```

---

---

# PostgreSQL

---

## Connect to PostgreSQL — Inside the Container

```bash
docker exec -it SITE_NAME-db psql -U frappe_root -d postgres
```

You are now in the `psql` shell.

---

## Useful PostgreSQL Commands

```sql
-- List all databases
\l

-- Connect to your ERPNext database
\c your_site_name

-- List all tables
\dt

-- See the structure of a table
\d "tabDocType"

-- Count records in a table
SELECT COUNT(*) FROM "tabCustomer";

-- View recent records
SELECT name, creation FROM "tabCustomer" ORDER BY creation DESC LIMIT 10;

-- Exit
\q
```

---

## Find Your ERPNext Database Name

```bash
docker exec -it SITE_NAME-db psql -U frappe_root -c "\l"
```

Database name pattern:
- Site `example.com` → database `example_com`
- Site `erp.mycompany.com` → database `erp_mycompany_com`

---

## Expose PostgreSQL Port for GUI Access (Secure — SSH Tunnel)

> **Security warning**: Bind to localhost only. Never expose 5432 to the public internet.

Add `ports` to the `db` service in your `SITE_NAME-docker-compose.yml`:

```yaml
  db:
    image: postgres:14
    ports:
      - "127.0.0.1:5432:5432"    # localhost only
```

Restart:
```bash
cd SITE_NAME/
docker compose -f SITE_NAME-docker-compose.yml restart db
```

Then create an SSH tunnel from your local machine:
```bash
ssh -L 5432:127.0.0.1:5432 user@your-server-ip
```

Now connect pgAdmin or DBeaver to `127.0.0.1:5432`.

---

## Common PostgreSQL Queries for ERPNext

```sql
-- Connect to ERPNext database first
\c your_site_name

-- List all ERPNext apps installed
SELECT * FROM "tabInstalled Applications";

-- View all users
SELECT name, email, enabled FROM "tabUser";

-- View all customers
SELECT name, customer_name, creation FROM "tabCustomer" LIMIT 20;

-- View all sales invoices
SELECT name, customer, grand_total, status FROM "tabSales Invoice" LIMIT 20;

-- List all tables
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
```

---

## Backup PostgreSQL

```bash
# Full backup
docker exec SITE_NAME-db pg_dumpall -U frappe_root > postgres_backup.sql

# Backup only ERPNext site database
docker exec SITE_NAME-db pg_dump -U frappe_root your_site_name > site_backup.sql
```

## Restore PostgreSQL

```bash
docker exec -i SITE_NAME-db psql -U frappe_root < postgres_backup.sql
```

---

---

# Quick Reference — Both Databases

| Action | MariaDB | PostgreSQL |
|--------|---------|-----------|
| Connect | `docker exec -it SITE_NAME-db mysql -u root -padmin` | `docker exec -it SITE_NAME-db psql -U frappe_root` |
| List databases | `SHOW DATABASES;` | `\l` |
| Use a database | `USE database_name;` | `\c database_name` |
| List tables | `SHOW TABLES;` | `\dt` |
| Describe table | `DESCRIBE "tabCustomer";` | `\d "tabCustomer"` |
| Exit | `EXIT;` | `\q` |
| Backup | `mysqldump -u root -padmin db > file.sql` | `pg_dump -U frappe_root db > file.sql` |

---

# View Database via bench Console (Inside App Container)

```bash
# Open a shell in the app container
docker exec -it SITE_NAME-app bash

# Inside the container
cd /home/frappe/frappe-bench

# Open Python console connected to your site
bench --site your.site console
```

Inside the console:
```python
# Count customers
frappe.db.count("Customer")

# Get list of users
frappe.get_all("User", fields=["name", "email"])

# Get a specific record
frappe.get_doc("Customer", "CUST-00001")

# Run raw SQL (MariaDB)
frappe.db.sql("SELECT name FROM `tabCustomer` LIMIT 5", as_dict=True)

# Run raw SQL (PostgreSQL)
frappe.db.sql('SELECT name FROM "tabCustomer" LIMIT 5', as_dict=True)

# Exit
exit()
```

---

# Default Credentials

| Database | Username | Password |
|----------|----------|---------|
| MariaDB | `root` | `admin` |
| PostgreSQL | `frappe_root` | value entered during setup (default: `admin`) |

> **Change these passwords** in your `.env` file for production use.

---

# Troubleshooting

## Cannot connect to database
```bash
# Check if db container is running
docker ps | grep SITE_NAME-db

# View db logs
docker logs SITE_NAME-db --tail 30
```

## Database container keeps restarting
```bash
docker logs SITE_NAME-db --tail 50
```
Common causes: wrong password, data volume corruption, port conflict.

## Data lost after `docker compose down -v`
The `-v` flag removes volumes including the database. **Never use `-v` unless you want to delete all data.**

Safe stop:
```bash
docker compose -f SITE_NAME-docker-compose.yml down    # NO -v flag
```

---

## Related Guides

- **VPS Setup Guide**: [README.md](README.md)
- **Full Project Guide**: [../README.md](../README.md)
- **Local Development Database**: [../Docker-Local/DATABASE.md](../Docker-Local/DATABASE.md)
