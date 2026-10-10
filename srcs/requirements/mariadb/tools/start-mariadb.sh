#!/bin/sh

set -eu

# Validate environment variables
: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set}"
: "${MYSQL_USER:?MYSQL_USER must be set}"

# Validate SQL identifiers
case "$MYSQL_DATABASE" in
    ""|*[!a-zA-Z0-9_]*)
        echo "Error: Invalid database name" >&2
        exit 1
        ;;
esac

case "$MYSQL_USER" in
    ""|*[!a-zA-Z0-9_]*)
        echo "Error: Invalid database username" >&2
        exit 1
        ;;
esac

# Read passwords from Docker secrets
MYSQL_PASSWORD="$(cat /run/secrets/db_password)"
MYSQL_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

[ -n "$MYSQL_PASSWORD" ] || {
    echo "Error: Database password is empty" >&2
    exit 1
}

[ -n "$MYSQL_ROOT_PASSWORD" ] || {
    echo "Error: Root password is empty" >&2
    exit 1
}

# Generated secrets must be hexadecimal
case "$MYSQL_PASSWORD:$MYSQL_ROOT_PASSWORD" in
    *[!a-fA-F0-9:]*)
        echo "Error: Database secrets must be hexadecimal" >&2
        exit 1
        ;;
esac

# Prepare MariaDB directories
mkdir -p /var/lib/mysql /run/mysqld

chown mysql:mysql /var/lib/mysql /run/mysqld

# Initialize MariaDB system tables if missing
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "First startup: initializing MariaDB"

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=socket \
        --skip-test-db
fi

# Configure database only once
if [ ! -f /var/lib/mysql/.inception_initialized ]; then
    echo "Configuring MariaDB users and database"

    # Start temporary MariaDB with networking disabled
    mariadbd \
        --user=mysql \
        --skip-networking \
        --socket=/run/mysqld/mysqld.sock &

    temp_pid=$!

    # Wait for temporary MariaDB to become ready
    count=0

    until mariadb \
        --protocol=socket \
        --socket=/run/mysqld/mysqld.sock \
        -u root \
        -e "SELECT 1" >/dev/null 2>&1
    do
        count=$((count + 1))

        if [ "$count" -ge 30 ]; then
            echo "Error: Temporary MariaDB failed to start" >&2
            exit 1
        fi

        if ! kill -0 "$temp_pid" 2>/dev/null; then
            echo "Error: Temporary MariaDB exited" >&2
            exit 1
        fi

        sleep 1
    done

    # Create WordPress database and account
    mariadb \
        --protocol=socket \
        --socket=/run/mysqld/mysqld.sock \
        -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

    # Stop temporary server using root credentials
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
    mariadb-admin \
        --protocol=socket \
        --socket=/run/mysqld/mysqld.sock \
        -u root \
        shutdown

    wait "$temp_pid"

    # Mark successful initialization
    touch /var/lib/mysql/.inception_initialized
    chown mysql:mysql /var/lib/mysql/.inception_initialized

    echo "MariaDB initialization completed"
fi

# Start MariaDB in foreground
exec mariadbd --user=mysql

