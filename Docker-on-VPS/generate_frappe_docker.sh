#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if a port is in use
is_port_in_use() {
    ss -ltn "sport = :$1" | grep -q LISTEN
}

# Get the process using a port
get_process_on_port() {
    ss -ltnp "sport = :$1" | grep LISTEN | awk '{print $7}'
}

# Check if Traefik is running
is_traefik_running() {
    docker ps --filter "name=traefik" --format "{{.Names}}" | grep -q "traefik"
}

# Validate a domain name
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)*\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Error: Invalid domain name format. Please use a format like 'example.com' or 'subdomain.example.com'.${NC}"
        return 1
    fi
    return 0
}

# Generate the docker-compose.yml file
generate_docker_compose() {
    local safe_site_name=$1
    local site_name=$2
    local use_ssl=$3
    local db_type=${4:-mariadb}
    local external_pg=${5:-false}
    local pg_root_user=${6:-frappe_root}
    local pg_root_password=${7:-admin}
    local selected_apps=${8:-""}
    local compose_file="$safe_site_name/${safe_site_name}-docker-compose.yml"

    # DB connection details
    local db_host="db"
    local db_port="3306"
    if [[ "$db_type" == "postgres" ]]; then
        db_port="5432"
        if [[ "$external_pg" == "true" ]]; then
            db_host="host.docker.internal"
        fi
    fi

    # Build app command strings from selected_apps tokens
    local app_download_cmds=""
    local pip_install_list=""
    local app_install_cmds=""

    # Postgres: clone and immediately pip-install frappe_pg BEFORE bench new-site.
    # frappe_pg must be pip-installed early because:
    # 1. A persisted volume may have frappe_pg in sites/apps.txt from a previous run.
    # 2. bench new-site calls make_conf → frappe.init (which imports all apps in apps.txt)
    #    BEFORE creating the PostgreSQL role. If frappe_pg is in apps.txt but not
    #    pip-installed, frappe.init fails, the role is never created, and site setup breaks.
    # Pip-installing alone does NOT activate the SQL patches (those only activate when
    # frappe_pg is installed-app and its hooks run), so schema creation is unaffected.
    if [[ "$db_type" == "postgres" ]]; then
        app_download_cmds+='        [ ! -d "apps/frappe_pg" ] && git clone https://github.com/excel-azmin/frappe_pg.git apps/frappe_pg || true
        ./env/bin/pip install -q -e apps/frappe_pg
'
        # intentionally NOT added to pip_install_list (already installed above)
    fi

    for token in $selected_apps; do
        case "$token" in
            ui_theme)
                app_download_cmds+='        [ ! -d "apps/ui_theme" ] && bench get-app ui_theme https://github.com/DarshanaPBrainmine/ui_theme_erpnext.git || true
'
                pip_install_list+=" apps/ui_theme"
                app_install_cmds+="        bench --site ${site_name} install-app ui_theme || true
"
                ;;
            hrms)
                app_download_cmds+='        [ ! -d "apps/hrms" ] && bench get-app hrms https://github.com/frappe/hrms.git --branch version-15 || true
'
                pip_install_list+=" apps/hrms"
                app_install_cmds+="        echo \"Installing HRMS...\"
        bench --site ${site_name} install-app hrms || true
        echo \"Running migrate to resolve any HRMS-ERPNext table conflicts...\"
        bench --site ${site_name} migrate || true
"
                ;;
            raven)
                app_download_cmds+='        [ ! -d "apps/raven" ] && bench get-app raven https://github.com/The-Commit-Company/raven.git || true
'
                pip_install_list+=" apps/raven"
                app_install_cmds+="        bench --site ${site_name} install-app raven || true
"
                ;;
            custom:*)
                local cname; cname=$(echo "$token" | cut -d: -f2)
                local curl; curl=$(echo "$token" | cut -d: -f3)
                local cbranch; cbranch=$(echo "$token" | cut -d: -f4)
                if [[ -n "$cbranch" ]]; then
                    app_download_cmds+="        [ ! -d \"apps/${cname}\" ] && bench get-app ${cname} ${curl} --branch ${cbranch} || true
"
                else
                    app_download_cmds+="        [ ! -d \"apps/${cname}\" ] && bench get-app ${cname} ${curl} || true
"
                fi
                pip_install_list+=" apps/${cname}"
                app_install_cmds+="        bench --site ${site_name} install-app ${cname} || true
"
                ;;
        esac
    done

    # Build pip install command
    local pip_install_cmd=""
    if [[ -n "$pip_install_list" ]]; then
        pip_install_cmd="        pip install -q -e${pip_install_list}
"
    fi

    # Traefik labels for the main app container
    local app_labels=""
    if [[ "$use_ssl" == true ]]; then
        app_labels=$(cat <<EOF
      - "traefik.enable=true"
      - "traefik.docker.network=traefik_proxy"
      - "traefik.http.services.${safe_site_name}-app.loadbalancer.server.port=8000"
      - "traefik.http.services.${safe_site_name}-app.loadbalancer.passHostHeader=true"
      - "traefik.http.routers.${safe_site_name}-app-http.rule=Host(\`${site_name}\`)"
      - "traefik.http.routers.${safe_site_name}-app-http.entrypoints=web"
      - "traefik.http.routers.${safe_site_name}-app-http.middlewares=${safe_site_name}-redirect-to-https"
      - "traefik.http.middlewares.${safe_site_name}-redirect-to-https.redirectscheme.scheme=https"
      - "traefik.http.middlewares.${safe_site_name}-redirect-to-https.redirectscheme.permanent=true"
      - "traefik.http.routers.${safe_site_name}-app-https.rule=Host(\`${site_name}\`)"
      - "traefik.http.routers.${safe_site_name}-app-https.entrypoints=websecure"
      - "traefik.http.routers.${safe_site_name}-app-https.tls=true"
      - "traefik.http.routers.${safe_site_name}-app-https.tls.certresolver=myresolver"
      - "traefik.http.routers.${safe_site_name}-app-https.service=${safe_site_name}-app"
      - "traefik.http.services.${safe_site_name}-websocket.loadbalancer.server.port=9000"
      - "traefik.http.routers.${safe_site_name}-websocket.rule=PathPrefix(\`/socket.io\`)"
      - "traefik.http.routers.${safe_site_name}-websocket.entrypoints=websecure"
      - "traefik.http.routers.${safe_site_name}-websocket.tls=true"
      - "traefik.http.routers.${safe_site_name}-websocket.tls.certresolver=myresolver"
      - "traefik.http.routers.${safe_site_name}-websocket.service=${safe_site_name}-websocket"
EOF
)
    else
        app_labels=$(cat <<EOF
      - "traefik.enable=true"
      - "traefik.docker.network=traefik_proxy"
      - "traefik.http.services.${safe_site_name}-app.loadbalancer.server.port=8000"
      - "traefik.http.services.${safe_site_name}-app.loadbalancer.passHostHeader=true"
      - "traefik.http.routers.${safe_site_name}-app-http.rule=Host(\`${site_name}\`)"
      - "traefik.http.routers.${safe_site_name}-app-http.entrypoints=web"
      - "traefik.http.routers.${safe_site_name}-app-http.service=${safe_site_name}-app"
      - "traefik.http.services.${safe_site_name}-websocket.loadbalancer.server.port=9000"
      - "traefik.http.routers.${safe_site_name}-websocket.rule=PathPrefix(\`/socket.io\`)"
      - "traefik.http.routers.${safe_site_name}-websocket.entrypoints=web"
      - "traefik.http.routers.${safe_site_name}-websocket.service=${safe_site_name}-websocket"
EOF
)
    fi

    # Write compose file header and app service
    cat > "$compose_file" << EOF
version: "3.8"

services:
  app:
    image: frappe/erpnext:v15.70.0
    container_name: ${safe_site_name}-app
    networks:
      - frappe_network
      - traefik_proxy
EOF

    # Add depends_on and optional extra_hosts for app service
    if [[ "$external_pg" == "true" ]]; then
        cat >> "$compose_file" << EOF
    depends_on:
      - redis
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
    else
        cat >> "$compose_file" << EOF
    depends_on:
      - db
      - redis
EOF
    fi

    # App service — labels, volumes, environment, simplified supervisor entrypoint
    cat >> "$compose_file" << EOF
    labels:
${app_labels}
    deploy:
      restart_policy:
        condition: on-failure
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
      - apps:/home/frappe/frappe-bench/apps
    environment:
      DB_HOST: ${db_host}
      DB_PORT: "${db_port}"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      SOCKETIO_PORT: "9000"
    entrypoint:
      - bash
      - -c
      - |
        ./env/bin/python -m pip install -q "pydantic~=2.10.2" "PyJWT~=2.8.0"
        pip3 install -q supervisor
        mkdir -p /home/frappe/supervisor/logs
        echo "Waiting for site ${site_name} to be ready..."
        until [ -f "sites/${site_name}/site_config.json" ]; do
          echo "  Site not ready yet, retrying in 15s..."
          sleep 15
        done
        echo "Site is ready. Installing app packages into env..."
        for app_dir in apps/*/; do
          app_name=\$\$(basename "\$\$app_dir")
          if [ "\$\$app_name" != "frappe" ] && [ "\$\$app_name" != "erpnext" ]; then
            if [ -f "\$\${app_dir}setup.py" ] || [ -f "\$\${app_dir}pyproject.toml" ]; then
              echo "  pip install -e \$\$app_name"
              ./env/bin/pip install -q -e "\$\${app_dir}" || true
            fi
          fi
        done
        echo "All app packages installed. Starting supervisor..."
        cat > /home/frappe/supervisor/supervisord.conf << 'SUPERVISOR_EOF'
        [supervisord]
        nodaemon=true
        logfile=/home/frappe/supervisor/logs/supervisord.log

        [program:web]
        command=bench serve --port 8000
        directory=/home/frappe/frappe-bench
        stdout_logfile=/home/frappe/supervisor/logs/web.log
        stderr_logfile=/home/frappe/supervisor/logs/web-error.log

        [program:worker]
        command=bench worker --queue short,default,long
        directory=/home/frappe/frappe-bench
        stdout_logfile=/home/frappe/supervisor/logs/worker.log
        stderr_logfile=/home/frappe/supervisor/logs/worker-error.log

        [program:schedule]
        command=bench schedule
        directory=/home/frappe/frappe-bench
        stdout_logfile=/home/frappe/supervisor/logs/schedule.log
        stderr_logfile=/home/frappe/supervisor/logs/schedule-error.log
        SUPERVISOR_EOF
        /home/frappe/.local/bin/supervisord -c /home/frappe/supervisor/supervisord.conf

  create-site:
    image: frappe/erpnext:v15.70.0
    container_name: ${safe_site_name}-create-site
    networks:
      - frappe_network
EOF

    # Add extra_hosts for create-site if using external postgres
    if [[ "$external_pg" == "true" ]]; then
        cat >> "$compose_file" << EOF
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
    fi

    cat >> "$compose_file" << EOF
    deploy:
      restart_policy:
        condition: none
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
      - apps:/home/frappe/frappe-bench/apps
    entrypoint:
      - bash
      - -c
      - |
EOF

    # Create-site entrypoint — different for postgres vs mariadb
    if [[ "$db_type" == "postgres" ]]; then
        cat >> "$compose_file" << EOF
        wait-for-it -t 120 ${db_host}:${db_port}
        wait-for-it -t 120 redis:6379
        cd /home/frappe/frappe-bench
        bench set-config -g db_host ${db_host}
        bench set-config -gp db_port ${db_port}
        bench set-config -g db_type postgres
        bench set-config -g redis_cache "redis://redis:6379"
        bench set-config -g redis_queue "redis://redis:6379"
        bench set-config -g redis_socketio "redis://redis:6379"
        bench set-config -gp socketio_port 9000
${app_download_cmds}${pip_install_cmd}
        cat > /tmp/patch_frappe_pg.py << 'PYEOF'
        path = 'apps/frappe_pg/frappe_pg/postgres/database_patches.py'
        lines = open(path).readlines()
        result = []
        for line in lines:
            s = line.lstrip()
            if s.startswith('return frappe.database.database.Database.sql(self, pg_query, pg_values'):
                indent = line[:len(line) - len(s)]
                result.append(indent + 'pg_query = pg_query.replace("%", "%%") if not pg_values else pg_query\n')
            result.append(line)
        open(path, 'w').writelines(result)
        print('frappe_pg patched')
        PYEOF
        python3 /tmp/patch_frappe_pg.py 2>/dev/null || true
        if [ ! -d "sites/${site_name}" ]; then
          echo "Creating new site with PostgreSQL (frappe_pg not active yet)..."
          bench new-site ${site_name} \\
            --db-type postgres --db-host ${db_host} --db-port ${db_port} \\
            --db-root-username ${pg_root_user} --db-root-password ${pg_root_password} \\
            --admin-password admin
          echo "${site_name}" > sites/currentsite.txt
          echo "Site created cleanly. Now activating frappe_pg..."
          grep -qxF "frappe_pg" sites/apps.txt 2>/dev/null || printf "\nfrappe_pg\n" >> sites/apps.txt
          ./env/bin/pip install -q -e apps/frappe_pg
          bench --site ${site_name} install-app frappe_pg || true
          bench --site ${site_name} execute frappe_pg.install_db_functions.install || true
          echo "Installing erpnext with frappe_pg active..."
          bench --site ${site_name} install-app erpnext
${app_install_cmds}          bench build
          bench --site ${site_name} migrate
        else
          echo "Site ${site_name} already exists. Ensuring frappe_pg is installed in env..."
          grep -qxF "frappe_pg" sites/apps.txt 2>/dev/null || printf "\nfrappe_pg\n" >> sites/apps.txt
          ./env/bin/pip install -q -e apps/frappe_pg
        fi
EOF
    else
        cat >> "$compose_file" << EOF
        wait-for-it -t 120 db:3306
        wait-for-it -t 120 redis:6379
        cd /home/frappe/frappe-bench
        bench set-config -g db_host db
        bench set-config -gp db_port 3306
        bench set-config -g redis_cache "redis://redis:6379"
        bench set-config -g redis_queue "redis://redis:6379"
        bench set-config -g redis_socketio "redis://redis:6379"
        bench set-config -gp socketio_port 9000
${app_download_cmds}${pip_install_cmd}
        if [ ! -d "sites/${site_name}" ]; then
          echo "Creating new site..."
          bench new-site ${site_name} \\
            --mariadb-user-host-login-scope='%' \\
            --admin-password admin \\
            --db-host db --db-root-username root --db-root-password admin \\
            --install-app erpnext
          echo "${site_name}" > sites/currentsite.txt
${app_install_cmds}          bench build
          bench --site ${site_name} migrate
        else
          echo "Site ${site_name} already exists, skipping creation"
        fi
EOF
    fi

    # DB service — conditional on db_type
    if [[ "$db_type" == "mariadb" ]]; then
        cat >> "$compose_file" << EOF

  db:
    image: mariadb:10.6
    container_name: ${safe_site_name}-db
    networks:
      - frappe_network
    healthcheck:
      test: mysqladmin ping -h localhost --password=admin
      interval: 1s
      retries: 20
    deploy:
      restart_policy:
        condition: on-failure
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
      - --skip-innodb-read-only-compressed
    environment:
      MYSQL_ROOT_PASSWORD: admin
      MARIADB_ROOT_PASSWORD: admin
    volumes:
      - db-data:/var/lib/mysql
EOF
    elif [[ "$db_type" == "postgres" && "$external_pg" != "true" ]]; then
        cat >> "$compose_file" << EOF

  db:
    image: postgres:16
    container_name: ${safe_site_name}-db
    networks:
      - frappe_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${pg_root_user}"]
      interval: 1s
      retries: 20
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      POSTGRES_USER: ${pg_root_user}
      POSTGRES_PASSWORD: ${pg_root_password}
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - db-data:/var/lib/postgresql/data
EOF
    fi

    # Redis service, networks, and volumes
    cat >> "$compose_file" << EOF

  redis:
    image: redis:6.2-alpine
    container_name: ${safe_site_name}-redis
    networks:
      - frappe_network
    deploy:
      restart_policy:
        condition: on-failure
    volumes:
      - redis-data:/data

networks:
  frappe_network:
    driver: bridge
  traefik_proxy:
    external: true

volumes:
  sites:
  logs:
  apps:
EOF

    # db-data volume only when we have a db container
    if [[ "$db_type" != "postgres" || "$external_pg" != "true" ]]; then
        cat >> "$compose_file" << EOF
  db-data:
EOF
    fi

    cat >> "$compose_file" << EOF
  redis-data:
EOF
}

# --- Main Script ---

# Check for Docker
if ! command_exists docker; then
    echo -e "${RED}Docker is not installed. Please install Docker and try again.${NC}"
    exit 1
fi

# Welcome message
echo -e "${GREEN}Welcome to Frappe/ERPNext Docker Setup (Minimal Edition)!${NC}"
echo "=============================================================="
echo ""
echo -e "${BLUE}🚀 Optimized for VPS cloud servers with minimal containers:${NC}"
echo "  • 1 app container (runs all Frappe processes via Supervisor)"
echo "  • 1 Redis container (handles cache, queue, and socketio)"
echo "  • 1 MariaDB or PostgreSQL container"
echo "  • 1 temporary create-site container"
echo ""

# Prompt for SSL
read -p "Do you want to enable SSL/HTTPS? (y/n): " enable_ssl
if [[ "$enable_ssl" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}SSL/HTTPS will be enabled with Let's Encrypt certificates.${NC}"
    use_ssl=true
else
    echo -e "${YELLOW}SSL/HTTPS will be disabled. Site will run on HTTP only.${NC}"
    use_ssl=false
fi
echo ""

# Prompt for database type
echo ""
read -p "Use PostgreSQL instead of MariaDB? (y/n, default: n): " use_postgres
if [[ "$use_postgres" =~ ^[Yy]$ ]]; then
    db_type="postgres"
    echo -e "${YELLOW}⚠️  PostgreSQL support requires the frappe_pg compatibility app.${NC}"
    echo -e "${YELLOW}   This is community-maintained. Test thoroughly before production use.${NC}"
    echo ""
    read -p "Use external PostgreSQL running on host machine? (y/n): " use_external_pg
    if [[ "$use_external_pg" =~ ^[Yy]$ ]]; then
        external_pg="true"
        echo -e "${BLUE}📍 Will connect to PostgreSQL on host via host.docker.internal${NC}"
    else
        external_pg="false"
        echo -e "${BLUE}📍 A PostgreSQL 16 container will be created${NC}"
    fi
    read -p "PostgreSQL superuser username (default: frappe_root): " pg_root_user
    pg_root_user=${pg_root_user:-frappe_root}
    read -sp "PostgreSQL superuser password (default: admin): " pg_root_password
    echo ""
    pg_root_password=${pg_root_password:-admin}
else
    db_type="mariadb"
    external_pg="false"
    pg_root_user=""
    pg_root_password=""
fi
echo ""

# Check for port conflicts
if ! is_traefik_running; then
    blocked_ports=""
    if is_port_in_use 80; then blocked_ports="80"; fi
    if is_port_in_use 443; then blocked_ports="$blocked_ports 443"; fi

    if [[ -n "$blocked_ports" ]]; then
        echo -e "${YELLOW}Warning: Ports $blocked_ports are in use by other processes.${NC}"
        echo "Traefik needs both ports 80 and 443 to work properly."
        for port in $blocked_ports; do
            echo "Port $port is being used by: $(get_process_on_port $port)"
        done
        read -p "Do you want to stop these services and continue? (y/n): " stop_service
        if [[ "$stop_service" =~ ^[Yy]$ ]]; then
            echo "Attempting to stop conflicting services..."
            # Add logic to stop services here
        else
            echo -e "${RED}Setup cancelled. Please free up ports 80 and 443 manually and try again.${NC}"
            exit 1
        fi
    fi
fi

# Check and create traefik_proxy network
if ! docker network ls | grep -q traefik_proxy; then
    echo "Creating traefik_proxy network..."
    docker network create traefik_proxy
fi

# Check and configure Traefik
if ! is_traefik_running; then
    echo "Traefik is not running. Creating traefik-docker-compose.yml..."
    
    if [[ "$use_ssl" == true ]]; then
        read -p "Enter your Cloudflare API token (leave blank for HTTP challenge): " cf_api_token
        read -p "Enter email for Let's Encrypt notifications: " email
    fi

    # Generate Traefik config
    # ... (omitted for brevity, but would be here)

    echo "Starting Traefik..."
    docker compose -f traefik-docker-compose.yml up -d
    sleep 3
fi

# Get site name
while true; do
    read -p "Enter site name (e.g. example.com): " site_name
    if validate_domain "$site_name"; then
        break
    fi
done

# Sanitize site name
safe_site_name=$(echo "$site_name" | sed 's/[^a-zA-Z0-9]/_/g')

# Create site directory
mkdir -p "$safe_site_name"

# App selection
echo ""
echo -e "${BLUE}📦 Select additional apps to install (ERPNext is always included):${NC}"
echo ""
selected_apps=""

read -p "Install UI Theme? (y/n): " install_ui_theme
[[ "$install_ui_theme" =~ ^[Yy]$ ]] && selected_apps+=" ui_theme"

read -p "Install HRMS (HR & Payroll)? (y/n): " install_hrms
[[ "$install_hrms" =~ ^[Yy]$ ]] && selected_apps+=" hrms"

read -p "Install Raven (Chat)? (y/n): " install_raven
[[ "$install_raven" =~ ^[Yy]$ ]] && selected_apps+=" raven"

read -p "Add a custom app? (y/n): " add_custom
if [[ "$add_custom" =~ ^[Yy]$ ]]; then
    read -p "  App name: " custom_name
    read -p "  Git URL: " custom_url
    read -p "  Branch (leave blank for default): " custom_branch
    if [[ -n "$custom_branch" ]]; then
        selected_apps+=" custom:${custom_name}:${custom_url}:${custom_branch}"
    else
        selected_apps+=" custom:${custom_name}:${custom_url}"
    fi
fi
selected_apps="${selected_apps# }"
echo ""

# Create .env file
cat > "$safe_site_name/.env" << EOF
ERPNEXT_VERSION=v15.70.0
DB_PASSWORD=admin
LETSENCRYPT_EMAIL=${email}
FRAPPE_SITE_NAME_HEADER=${site_name}
SITES=${site_name}
EOF

# Generate docker-compose
generate_docker_compose "$safe_site_name" "$site_name" "$use_ssl" "$db_type" "$external_pg" "$pg_root_user" "$pg_root_password" "$selected_apps"

# Start containers
echo -e "${GREEN}Starting your minimal Frappe/ERPNext site...${NC}"
docker compose -f "$safe_site_name/${safe_site_name}-docker-compose.yml" up -d

# Final messages
echo ""
echo -e "${GREEN}🚀 Your minimal site is being prepared and will be live in approximately 5 minutes...${NC}"
if [[ "$use_ssl" == true ]]; then
    echo -e "🔒 Your site will be accessible at: https://${site_name}"
else
    echo -e "🌐 Your site will be accessible at: http://${site_name}"
fi
echo ""
echo "📋 Frappe Version: v15.70.0"
echo "👤 Default Username: Administrator"
echo "🔑 Default Password: admin"
echo ""
echo "💡 You can change the password after first login."
echo ""
echo "🚀 Benefits of this minimal setup:"
echo "   • Fewer containers to manage (4 vs 9)"
echo "   • Lower resource usage"
echo "   • Simpler networking"
echo "   • All Frappe processes in one container via Supervisor"
echo "   • Single Redis instance for all needs"
echo "   • Full process management and restart capabilities"
echo ""
echo "To add another domain or site, simply run this script again with a different site name."
echo ""
echo "🔧 Process Management Commands:"
echo "   • Check status: docker exec ${safe_site_name}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf status"
echo "   • Restart web: docker exec ${safe_site_name}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf restart web"
echo "   • Restart worker: docker exec ${safe_site_name}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf restart worker"
echo "   • Restart scheduler: docker exec ${safe_site_name}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf restart schedule"
echo "   • Restart all: docker exec ${safe_site_name}-app /home/frappe/.local/bin/supervisorctl -c /home/frappe/supervisor/supervisord.conf restart all"
echo "   • View logs: docker exec ${safe_site_name}-app tail -f /home/frappe/supervisor/logs/web.log"
echo ""

# Site availability check
# ... (omitted for brevity)

# Docker Manager prompt
# ... (omitted for brevity)
echo ""
# sudo docker-manager
read -p "Do you want to access the docker-manager? (y/n): " ACCESS_MANAGER

if [[ "$ACCESS_MANAGER" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Launching Docker Manager..."
    echo ""
    # Check if docker-manager is available in PATH
    if command -v docker-manager &> /dev/null; then
        sudo docker-manager
    else
        echo "❌ docker-manager not found in PATH."
    fi
else
    echo ""
    echo "💡 You can access the docker-manager anytime by running:"
    echo " sudo docker-manager"
fi



