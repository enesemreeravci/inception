#!/bin/sh

set -eu

: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set}"
: "${MYSQL_USER:?MYSQL_USER must be set}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD must be set}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD must be set}"

mkdir -p /var/lib/mysql /run/mysqld
chown mysql:mysql /var/lib/mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
	echo "First startup: database initialization required"

	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--auth-root-authentication-method=socket \
		--skip-test-db

	mariadbd \
		--user=mysql \
		--bootstrap \
		--skip-networking <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL
fi

exec mariadbd --user=mysql
