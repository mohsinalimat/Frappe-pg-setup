# Database Access Guide — MariaDB & PostgreSQL

This guide explains how to connect to, view, and manage the database inside your ERPNext Docker containers.

---

## Which Database Is Running?

When you created your site, you chose either **MariaDB** (default) or **PostgreSQL**.

- **MariaDB** — container name: `SITE_NAME-db`, port `3306`
- **PostgreSQL** — container name: `SITE_NAME-db`, port `5432`

Replace `SITE_NAME` throughout this guide with your actual site folder name (e.g. `test_pg` or `demo_local`).

---

## How to Check Which Database Is Running

```bash
docker inspect SITE_NAME-db | grep -i "image\|Image"
```

- If you see `mariadb` → you are using **MariaDB**
- If you see `postgres` → you are using **PostgreSQL**

Or simply:
```bash
docker ps --format "table {{.Names}}\t{{.Image}}" | grep "\-db"
```

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
-- (the database name is usually the site name with underscores, e.g. test_local)
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

The ERPNext database name is usually your site name with dots replaced by underscores, e.g.:
- Site `demo.local` → database `demo_local`
- Site `mysite.localhost` → database `mysite_localhost`

---

## Connect to MariaDB — From Your Host Machine (Optional)

First expose the port temporarily:
```bash
docker exec -it SITE_NAME-db mysql -u root -padmin -h 127.0.0.1 -P 3306
```

Or use a GUI tool like **TablePlus**, **DBeaver**, or **HeidiSQL** with:

| Field | Value |
|-------|-------|
| Host | `127.0.0.1` |
| Port | `3306` |
| Username | `root` |
| Password | `admin` |

> **Note**: You need to expose port 3306 in the docker-compose.yml for GUI tools. By default it is internal only.

---

## Expose MariaDB Port for GUI Access

Add `ports` to the `db` service in your `SITE_NAME-docker-compose.yml`:

```yaml
  db:
    image: mariadb:10.6
    ports:
      - "3306:3306"    # Add this line
```

Then restart:
```bash
cd SITE_NAME/
docker compose -f SITE_NAME-docker-compose.yml restart db
```

Now connect with any MySQL GUI tool on `127.0.0.1:3306`.

---

## Common MariaDB Queries for ERPNext

```sql
-- Use the ERPNext database
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
# Restore from backup
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
-- (the database name is the site name with dots replaced by underscores)
\c your_site_name

-- List all tables
\dt

-- See the structure of a table
\d "tabDocType"

-- Count records in a table
SELECT COUNT(*) FROM "tabCustomer";

-- View recent records
SELECT name, creation FROM "tabCustomer" ORDER BY creation DESC LIMIT 10;

-- Exit psql
\q
```

---

## Find Your ERPNext Database Name

```bash
docker exec -it SITE_NAME-db psql -U frappe_root -c "\l"
```

The ERPNext database name follows the same pattern as MariaDB:
- Site `test.pg` → database `test_pg`
- Site `mysite.localhost` → database `mysite_localhost`

---

## Connect to PostgreSQL — From Your Host Machine (Optional)

```bash
# Connect directly
docker exec -it SITE_NAME-db psql -U frappe_root -h 127.0.0.1
```

Or use a GUI tool like **TablePlus**, **DBeaver**, or **pgAdmin** with:

| Field | Value |
|-------|-------|
| Host | `127.0.0.1` |
| Port | `5432` |
| Username | `frappe_root` |
| Password | `admin` |
| Database | your site name (with underscores) |

> **Note**: You need to expose port 5432 in the docker-compose.yml for GUI tools.

---

## Expose PostgreSQL Port for GUI Access

Add `ports` to the `db` service in your `SITE_NAME-docker-compose.yml`:

```yaml
  db:
    image: postgres:14
    ports:
      - "5432:5432"    # Add this line
```

Then restart:
```bash
cd SITE_NAME/
docker compose -f SITE_NAME-docker-compose.yml restart db
```

Now connect with pgAdmin or any PostgreSQL GUI tool on `127.0.0.1:5432`.

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

-- View all items
SELECT name, item_name, item_group FROM "tabItem" LIMIT 20;

-- List all tables in the database
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
```

---

## Backup PostgreSQL

```bash
# Full backup (all databases)
docker exec SITE_NAME-db pg_dumpall -U frappe_root > postgres_backup.sql

# Backup only your ERPNext site database
docker exec SITE_NAME-db pg_dump -U frappe_root your_site_name > site_backup.sql
```

## Restore PostgreSQL

```bash
# Restore from backup
docker exec -i SITE_NAME-db psql -U frappe_root < postgres_backup.sql
```

---

---

# Quick Reference — Both Databases

| Action | MariaDB command | PostgreSQL command |
|--------|----------------|-------------------|
| Connect | `docker exec -it SITE_NAME-db mysql -u root -padmin` | `docker exec -it SITE_NAME-db psql -U frappe_root` |
| List databases | `SHOW DATABASES;` | `\l` |
| Use a database | `USE database_name;` | `\c database_name` |
| List tables | `SHOW TABLES;` | `\dt` |
| Describe table | `DESCRIBE "tabCustomer";` | `\d "tabCustomer"` |
| Exit | `EXIT;` | `\q` |
| Backup | `mysqldump -u root -padmin db > file.sql` | `pg_dump -U frappe_root db > file.sql` |

---

# View Database from inside ERPNext (bench commands)

You can also use `bench` commands inside the app container to run queries:

```bash
# Open a shell in the app container
docker exec -it SITE_NAME-app bash

# Then inside the container:
cd /home/frappe/frappe-bench

# Open a Python shell connected to the site database
bench --site your.site console
```

Inside the console:
```python
# Count customers
frappe.db.count("Customer")

# Get a list of users
frappe.get_all("User", fields=["name", "email"])

# Get a specific record
frappe.get_doc("Customer", "CUST-00001")

# Run raw SQL (MariaDB)
frappe.db.sql("SELECT name FROM `tabCustomer` LIMIT 5", as_dict=True)

# Run raw SQL (PostgreSQL)
frappe.db.sql('SELECT name FROM "tabCustomer" LIMIT 5', as_dict=True)

# Exit console
exit()
```

---

# Troubleshooting

## Cannot connect to database

```bash
# Check the db container is running
docker ps | grep SITE_NAME-db

# Check db container logs
docker logs SITE_NAME-db --tail 30
```

## Forgot database password

Default credentials (set by the setup script):

| Database | Username | Password |
|----------|----------|---------|
| MariaDB | `root` | `admin` |
| PostgreSQL | `frappe_root` | `admin` (or what you entered during setup) |

## Database port conflict (when exposing port)

If port 3306 (MariaDB) or 5432 (PostgreSQL) is already in use on your machine:
```bash
# Check what is using the port
sudo ss -ltnp | grep 3306   # MariaDB
sudo ss -ltnp | grep 5432   # PostgreSQL
```

Change the host port in docker-compose.yml:
```yaml
ports:
  - "3307:3306"    # Use 3307 on host instead
```

---

## Related Guides

- **Main Setup Guide**: [README.md](README.md)
- **Full Project Guide**: [../README.md](../README.md)
- **VPS Database Access**: [../Docker-on-VPS/README.md](../Docker-on-VPS/README.md)
