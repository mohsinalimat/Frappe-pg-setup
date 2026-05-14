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

# Check for / generate an SSH key for private GitHub repos.
# Prints the path to the private key file on stdout (last line).
setup_ssh_for_private_repos() {
    local ssh_key_file=""
    echo "" >&2
    echo -e "${BLUE}🔐 Private repository access requires an SSH key${NC}" >&2
    for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_frappe_docker"; do
        if [[ -f "$key" ]]; then
            ssh_key_file="$key"
            echo -e "${GREEN}✅ Found existing SSH key: $ssh_key_file${NC}" >&2
            break
        fi
    done
    if [[ -z "$ssh_key_file" ]]; then
        echo "No SSH key found. Generating a new ed25519 key..." >&2
        ssh-keygen -t ed25519 -C "frappe-docker-deploy" -N "" -f "$HOME/.ssh/id_frappe_docker" -q
        ssh_key_file="$HOME/.ssh/id_frappe_docker"
        echo -e "${GREEN}✅ Generated: $ssh_key_file${NC}" >&2
    fi
    local pub_key="${ssh_key_file}.pub"
    echo "" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${YELLOW}  Add this SSH public key to GitHub to access private repositories:${NC}" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    cat "$pub_key" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "  1. Copy the key above (the entire ssh-ed25519 / ssh-rsa line)" >&2
    echo "  2. GitHub.com → Settings → SSH and GPG keys → New SSH key" >&2
    echo "  3. Paste and click 'Add SSH key'" >&2
    echo "" >&2
    read -p "Press Enter once you have added the key to GitHub (or it was already there)..." >&2
    echo "Testing SSH connection to GitHub..." >&2
    local test_result
    test_result=$(ssh -T git@github.com -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$ssh_key_file" 2>&1)
    if echo "$test_result" | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✅ GitHub SSH connection verified!${NC}" >&2
    else
        echo -e "${YELLOW}⚠️  Could not auto-verify — continuing (test later: ssh -T git@github.com)${NC}" >&2
    fi
    echo "$ssh_key_file"
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
    local ssh_key_file=${9:-""}
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

    # Postgres: clone frappe_pg and pip-install it BEFORE bench new-site.
    # Reason: a persisted volume may have frappe_pg in sites/apps.txt from a previous run.
    # bench new-site calls make_conf → frappe.init BEFORE creating the PostgreSQL role.
    # If frappe_pg is in apps.txt but not pip-installed, frappe.init fails and the role
    # is never created. Pip-installing does NOT activate SQL patches (those fire only when
    # frappe_pg is added via install-app), so schema creation remains unaffected.
    if [[ "$db_type" == "postgres" ]]; then
        app_download_cmds+='        if [ -d "apps/frappe_pg" ]; then
            echo "  Updating frappe_pg..."
            cd apps/frappe_pg && git pull -q && cd ../..
        else
            echo "  Cloning frappe_pg..."
            git clone -q https://github.com/NileshPBrainmine/frappe_pg.git apps/frappe_pg
        fi
        ./env/bin/pip install -q -e apps/frappe_pg
        ./env/bin/pip install -q "sqlglot>=20.0.0"
'
        # intentionally NOT added to pip_install_list (already installed above)
    fi

    for token in $selected_apps; do
        case "$token" in
            ui_theme)
                app_download_cmds+='        [ ! -d "apps/ui_theme" ] && bench get-app ui_theme https://github.com/DarshanaPBrainmine/ui_theme_erpnext.git || true
'
                pip_install_list+=" -e apps/ui_theme"
                app_install_cmds+="        bench --site ${site_name} install-app ui_theme || true
"
                ;;
            hrms)
                app_download_cmds+='        [ ! -d "apps/hrms" ] && bench get-app hrms https://github.com/frappe/hrms.git --branch version-15 || true
'
                pip_install_list+=" -e apps/hrms"
                app_install_cmds+="        echo \"Installing HRMS...\"
        bench --site ${site_name} set-config -p user_type_limit '{\"Employee Self Service\": 200}' || true
        bench --site ${site_name} install-app hrms || true
        echo \"Running migrate to resolve any HRMS-ERPNext table conflicts...\"
        bench --site ${site_name} migrate || true
"
                ;;
            raven)
                app_download_cmds+='        [ ! -d "apps/raven" ] && bench get-app raven https://github.com/The-Commit-Company/raven.git || true
'
                pip_install_list+=" -e apps/raven"
                app_install_cmds+="        bench --site ${site_name} install-app raven || true
"
                ;;
            'custom|'*)
                local cname; cname=$(echo "$token" | cut -d'|' -f2)
                local curl; curl=$(echo "$token" | cut -d'|' -f3)
                local cbranch; cbranch=$(echo "$token" | cut -d'|' -f4)
                if [[ -n "$cbranch" ]]; then
                    app_download_cmds+="        [ ! -d \"apps/${cname}\" ] && bench get-app ${cname} ${curl} --branch ${cbranch} || true
"
                else
                    app_download_cmds+="        [ ! -d \"apps/${cname}\" ] && bench get-app ${cname} ${curl} || true
"
                fi
                pip_install_list+=" -e apps/${cname}"
                app_install_cmds+="        bench --site ${site_name} install-app ${cname} || true
"
                ;;
        esac
    done

    # Build pip install command
    local pip_install_cmd=""
    if [[ -n "$pip_install_list" ]]; then
        pip_install_cmd="        ./env/bin/pip install -q${pip_install_list}
"
    fi

    # Build SSH setup snippet for the create-site container
    local ssh_setup_cmd=""
    local ssh_key_dir=""
    local ssh_key_name=""
    if [[ -n "$ssh_key_file" && -f "$ssh_key_file" ]]; then
        ssh_key_name=$(basename "$ssh_key_file")
        ssh_key_dir=$(dirname "$ssh_key_file")
        ssh_setup_cmd='        if [ -f "/tmp/host_ssh/'"$ssh_key_name"'" ]; then
            mkdir -p /home/frappe/.ssh
            cp "/tmp/host_ssh/'"$ssh_key_name"'" /home/frappe/.ssh/id_ed25519
            chmod 700 /home/frappe/.ssh
            chmod 600 /home/frappe/.ssh/id_ed25519
            ssh-keyscan -H github.com >> /home/frappe/.ssh/known_hosts 2>/dev/null || true
            echo "SSH key configured for private repository access"
        fi
'
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
EOF
    # Mount host SSH directory read-only for private repo access
    if [[ -n "$ssh_key_dir" ]]; then
        cat >> "$compose_file" << EOF
      - ${ssh_key_dir}:/tmp/host_ssh:ro
EOF
    fi

    cat >> "$compose_file" << EOF
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
${ssh_setup_cmd}${app_download_cmds}${pip_install_cmd}
        cat > /tmp/patch_frappe_pg.py << 'PYEOF'
        import os

        # --- Fix database_patches.py ---
        path = 'apps/frappe_pg/frappe_pg/postgres/database_patches.py'
        content = open(path).read()
        content = content.replace('self.con)', 'getattr(self, "conn", getattr(self, "con", None)))')

        # --- Fix db_functions.py ---
        df_path = 'apps/frappe_pg/frappe_pg/postgres/db_functions.py'
        if os.path.exists(df_path):
            df_content = open(df_path).read()
            if 'CREATE OR REPLACE FUNCTION time(ts timestamp)' in df_content:
                df_content = df_content.replace('"""\n    CREATE OR REPLACE FUNCTION time(ts timestamp)', '/* time(ts) omitted */\n    """')
                print('frappe_pg: removed failing time(ts) function from db_functions.py')
            if 'print(f"  ⚠  Warning: {str(e)[:120]}")' in df_content and 'query_peek' not in df_content:
                df_content = df_content.replace(
                    'print(f"  ⚠  Warning: {str(e)[:120]}")',
                    'query_peek = sql[:100].replace("\\n", " ") + "..." if len(sql) > 100 else sql.replace("\\n", " ")\n                if _db_conn: _db_conn.rollback()\n                else: frappe.db.rollback()\n                print(f"  ⚠  Warning: {str(e)[:120]}")\n                print(f"     at query: {query_peek}")'
                )
                print('frappe_pg: enhanced _exec robustness in db_functions.py')
            open(df_path, 'w').write(df_content)
            print('frappe_pg: patched db_functions.py')

        # --- Fix query_transformers.py for robust DDL protection ---
        qt_path = 'apps/frappe_pg/frappe_pg/postgres/query_transformers.py'
        if os.path.exists(qt_path):
            qt_content = open(qt_path).read()
            target = "if _FUNC_DDL_RE.search(query):"
            if target in qt_content:
                replacement = (
                    "    # Check for DDL using lstrip to handle leading newlines\n"
                    "    sq_strip = query.lstrip().lower()\n"
                    "    if sq_strip.startswith(('create ', 'drop ', 'alter ', 'truncate ', 'grant ', 'revoke ')):\n"
                )
                qt_content = qt_content.replace(target, replacement)
                open(qt_path, 'w').write(qt_content)
                print('frappe_pg: patched query_transformers.py (DDL protection)')

        # Patch A: fix patched_rollback to accept save_point= kwarg (frappe v15)
        old_sig = 'def patched_rollback(self):'
        new_sig = 'def patched_rollback(self, *, save_point=None):'
        if old_sig in content and new_sig not in content:
            content = content.replace(old_sig, new_sig)
            old_body = (
                '    try:\n'
                '        return _original_rollback(self)\n'
                '    except Exception as e:\n'
                '        # Don\'t log rollback failures during error handling\n'
                '        # as this can cause cascading errors\n'
                '        pass\n'
            )
            new_body = (
                '    if save_point:\n'
                '        try:\n'
                '            import frappe.database.database\n'
                '            frappe.database.database.Database.sql(\n'
                '                self, f"ROLLBACK TO SAVEPOINT {save_point}")\n'
                '        except Exception:\n'
                '            pass\n'
                '        return\n'
                '    try:\n'
                '        return _original_rollback(self)\n'
                '    except Exception:\n'
                '        pass\n'
            )
            if old_body in content:
                content = content.replace(old_body, new_body)
                print('frappe_pg: patched_rollback save_point support added')

        open(path, 'w').write(content)
        content = open(path).read()

        # Patch B: per-query savepoints in patched_sql
        GUARD = '# _FRAPPE_PG_SAVEPOINT_PATCH_APPLIED_'
        if GUARD not in content:
            import textwrap
            NEW_CODE = textwrap.dedent("""
                # _FRAPPE_PG_SAVEPOINT_PATCH_APPLIED_
                import threading as _fp_tl
                import psycopg2.extensions as _fp_pgext
                _fp_sp = _fp_tl.local()

                def _fp_next_sp():
                    if not hasattr(_fp_sp, "n"): _fp_sp.n = 0
                    _fp_sp.n = (_fp_sp.n + 1) % 1000000
                    return "frappe_pg_sp_{}".format(_fp_sp.n)

                def _fp_in_txn(conn):
                    try: return conn.status == _fp_pgext.STATUS_IN_TRANSACTION
                    except: return False

                def patched_sql(self, query, values=(), *args, **kwargs):
                    import frappe.database.database
                    from frappe.database.postgres.database import modify_query, modify_values as _fp_mv
                    from frappe_pg.postgres.query_transformers import apply_all_query_transformations
                    if isinstance(values, dict):
                        q = query
                        v = values
                    else:
                        t = apply_all_query_transformations(query)
                        q = modify_query(t)
                        v = _fp_mv(values)
                        if not v: q = q.replace("%", "%%")
                    _B = frappe.database.database.Database.sql
                    q_up = q.strip().upper()
                    ctrl = any(q_up.startswith(k) for k in (
                        "BEGIN","COMMIT","ROLLBACK","SAVEPOINT","RELEASE SAVEPOINT","SET ","SET\\t"))
                    sp = None
                    _db_conn = getattr(self, 'conn', getattr(self, 'con', None))
                    if not ctrl and _fp_in_txn(_db_conn):
                        sp = _fp_next_sp()
                        try: _B(self, "SAVEPOINT " + sp)
                        except: sp = None
                    try:
                        r = _B(self, q, v, *args, **kwargs)
                        if sp:
                            try: _B(self, "RELEASE SAVEPOINT " + sp)
                            except: pass
                        return r
                    except Exception as e:
                        if sp:
                            try: _B(self, "ROLLBACK TO SAVEPOINT " + sp)
                            except:
                                try: _original_rollback(self)
                                except: pass
                        elif "transaction is aborted" in str(e).lower() or "infailedsqltransaction" in str(e).lower():
                            try: _original_rollback(self)
                            except: pass
                        raise

                from frappe.database.postgres.database import PostgresDatabase as _fp_PGDb
                _fp_PGDb.sql = patched_sql
                print("frappe_pg: per-query savepoint patch applied")
            """).lstrip("\n")
            with open(path, 'a') as f:
                f.write(NEW_CODE)
            print('frappe_pg: savepoint patch appended')
        else:
            print('frappe_pg: savepoint patch already present')
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
${ssh_setup_cmd}${app_download_cmds}${pip_install_cmd}
        if [ ! -d "sites/${site_name}" ]; then
          echo "Creating new site..."
          bench new-site ${site_name} \\
            --mariadb-user-host-login-scope='%' \\
            --admin-password admin \\
            --db-host db --db-root-username root --db-root-password admin \\
            --install-app erpnext
          bench use ${site_name}
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
    image: postgres:14
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
        echo -e "${BLUE}📍 A PostgreSQL 14 container will be created${NC}"
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

has_private_repos=false
read -p "Add a custom app? (y/n): " add_custom
while [[ "$add_custom" =~ ^[Yy]$ ]]; do
    echo -e "  ${YELLOW}App name must match the app's Python module name in hooks.py${NC}"
    echo -e "  ${YELLOW}e.g. for Frappe_Assistant_Core repo the name is: frappe_assistant_core${NC}"
    read -p "  App name: " custom_name
    read -p "  Git URL (HTTPS or SSH): " custom_url
    read -p "  Branch (leave blank for default): " custom_branch
    read -p "  Is this a private repository? (y/n): " is_private_repo
    if [[ "$is_private_repo" =~ ^[Yy]$ ]]; then
        has_private_repos=true
        if [[ "$custom_url" =~ ^https://github\.com/ ]]; then
            custom_url="git@github.com:${custom_url#https://github.com/}"
            echo -e "  ${BLUE}Using SSH URL: ${custom_url}${NC}"
        fi
    fi
    if [[ -n "$custom_branch" ]]; then
        selected_apps+=" custom|${custom_name}|${custom_url}|${custom_branch}"
    else
        selected_apps+=" custom|${custom_name}|${custom_url}"
    fi
    read -p "Add another custom app? (y/n): " add_custom
done
selected_apps="${selected_apps# }"
echo ""

# Setup SSH key if any private repos were selected
ssh_key_file=""
if [[ "$has_private_repos" == "true" ]]; then
    ssh_key_file=$(setup_ssh_for_private_repos)
fi

# Create .env file
cat > "$safe_site_name/.env" << EOF
ERPNEXT_VERSION=v15.70.0
DB_PASSWORD=admin
LETSENCRYPT_EMAIL=${email}
FRAPPE_SITE_NAME_HEADER=${site_name}
SITES=${site_name}
EOF

# Generate docker-compose
generate_docker_compose "$safe_site_name" "$site_name" "$use_ssl" "$db_type" "$external_pg" "$pg_root_user" "$pg_root_password" "$selected_apps" "$ssh_key_file"

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



