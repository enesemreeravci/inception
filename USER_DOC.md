# Inception User Documentation

## Overview

This project provides a WordPress website running through four Docker services:

* **NGINX**: secure HTTPS web server
* **WordPress**: website and administration panel
* **MariaDB**: database server
* **Adminer**: browser-based database administration interface

The services communicate through a private Docker network. Website files and database files are stored persistently on the host.

## Configuration and Credentials

Private configuration is stored in:

```text
srcs/.env
```

The file contains the domain, database credentials, and WordPress credentials.

A safe template is:

```text
srcs/.env.example
```

Create the private file if necessary:

```bash
cp srcs/.env.example srcs/.env
```

Never commit or share `.env`.

## Starting the Services

From the project root:

```bash
make up
```

Equivalent command:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

## Website Access

Open:

```text
https://eeravci.42.fr
```

The certificate is self-signed, so the browser may display a warning during development.

## WordPress Administration

Open:

```text
https://eeravci.42.fr/wp-admin
```

Use the administrator credentials from `srcs/.env`.

## Adminer Database Interface

Open:

```text
http://127.0.0.1:8080
```

Use:

```text
System:   MariaDB
Server:   mariadb
Database: wordpress
Username: root or MYSQL_USER
Password: matching value from srcs/.env
```

Use `http://`, not `https://`.

Adminer can display tables such as:

```text
wp_users
wp_posts
wp_options
wp_usermeta
```

## Service Status

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

All four services should show `Up`:

```text
nginx
wordpress
mariadb
adminer
```

## Logs

View all logs:

```bash
make logs
```

View one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs adminer
```

## Testing

Test HTTPS:

```bash
curl -k -I --resolve eeravci.42.fr:443:127.0.0.1 \
https://eeravci.42.fr
```

Test Adminer:

```bash
curl -I http://127.0.0.1:8080/
```

Test NGINX:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec nginx nginx -t
```

Test PHP-FPM:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress php-fpm8.2 -t
```

Test MariaDB:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb-admin ping -uroot -p
```

Expected result:

```text
mysqld is alive
```

## Stopping the Services

Stop containers:

```bash
make stop
```

Remove containers and the network while preserving data:

```bash
make down
```

Do not use `docker compose down -v` unless you intend to delete all volumes.

## Persistent Data

MariaDB:

```text
/home/eeravci/data/mariadb
```

WordPress:

```text
/home/eeravci/data/wordpress
```

Verify persistence:

```bash
make down
make up
```

Existing users and posts should remain available.

## Troubleshooting

Check service status:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

Check Adminer logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs adminer
```

If Adminer reports an SSL error, use:

```text
http://127.0.0.1:8080
```

not HTTPS.

If Adminer cannot connect to MariaDB, use `mariadb` as the server name, not `localhost`.

