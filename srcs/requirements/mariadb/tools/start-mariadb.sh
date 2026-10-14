#!/bin/sh

set -eu

DATADIR="/var/lib/mysql"
INIT_FILE="/run/mysqld/inception-init.sql"

# Check required environment variables
: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set}"
: "${MYSQL_USER:?MYSQL_USER must be set}"

# Validate database name and username
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

# Check passwords
[ -n "$MYSQL_PASSWORD" ] || {
    echo "Error: Database password is empty" >&2
    exit 1
}

[ -n "$MYSQL_ROOT_PASSWORD" ] || {
    echo "Error: Root password is empty" >&2
    exit 1
}

# Generated passwords must be hexadecimal
case "$MYSQL_PASSWORD:$MYSQL_ROOT_PASSWORD" in
    *[!a-fA-F0-9:]*)
        echo "Error: Database passwords must be hexadecimal" >&2
        exit 1
        ;;
esac

# Prepare directories
mkdir -p "$DATADIR" /run/mysqld
chown mysql:mysql "$DATADIR" /run/mysqld

# Initialize MariaDB system tables if missing
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[MariaDB] Initializing system tables..."

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --auth-root-authentication-method=socket \
        --skip-test-db
fi

# Create initialization SQL file
# SQL commands execute during MariaDB startup
umask 077

cat > "$INIT_FILE" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

chown mysql:mysql "$INIT_FILE"
chmod 600 "$INIT_FILE"

# Start MariaDB in the foreground as PID 1
echo "[MariaDB] Starting MariaDB..."

exec mariadbd \
    --user=mysql \
    --datadir="$DATADIR" \
    --init-file="$INIT_FILE"