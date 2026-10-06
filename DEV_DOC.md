# Developer Documentation

## Overview

This document describes the internal structure, development workflow, service architecture, configuration, and debugging process for the Inception project.

The infrastructure is built with Docker Compose and contains the following services:

- NGINX
- WordPress with PHP-FPM
- MariaDB
- Redis
- FTP
- Adminer
- Static portfolio website
- Custom monitoring service

Each service runs inside its own Docker container and communicates through a custom Docker bridge network.

---

## Architecture

```text
                           Browser
                              |
                              |
                        HTTPS :443
                              |
                              v
                           NGINX
                         /    |    \
                        /     |     \
                       /      |      \
                      v       v       v
              WordPress   Portfolio   Monitor
               PHP-FPM    Static Site  Service
                :9000        :80       :9090
                   |
                   |
                   v
                MariaDB
                 :3306

                   |
                   v
                 Redis
                 :6379
```

Additional local-only services:

```text
Adminer  -> 127.0.0.1:8080
FTP      -> 127.0.0.1:21
```

All containers are attached to the same custom Docker network.

---

## Project Structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs
    ├── .env.example
    ├── docker-compose.yml
    └── requirements
        ├── adminer
        │   └── Dockerfile
        ├── ftp
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── vsftpd.conf
        │   └── tools
        │       └── start-ftp.sh
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── 50-server.cnf
        │   └── tools
        │       └── start-mariadb.sh
        ├── monitor
        │   ├── Dockerfile
        │   └── tools
        │       └── monitor.py
        ├── nginx
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── nginx.conf
        │   └── tools
        │       └── start-nginx.sh
        ├── redis
        │   └── Dockerfile
        ├── static-site
        │   ├── Dockerfile
        │   └── index.html
        └── wordpress
            ├── Dockerfile
            ├── conf
            └── tools
                └── start-wordpress.sh
```

---

## Environment Configuration

The real environment file is:

```text
srcs/.env
```

This file contains runtime configuration such as:

- domain name
- MariaDB database name
- MariaDB user
- MariaDB passwords
- WordPress admin credentials
- WordPress user credentials
- FTP credentials
- data paths

The real `.env` file should not be committed.

A template is provided as:

```text
srcs/.env.example
```

Create the runtime file with:

```bash
cp srcs/.env.example srcs/.env
```

Then update the values.

Example:

```env
DOMAIN_NAME=yourlogin.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=change_me
MYSQL_ROOT_PASSWORD=change_me

WP_TITLE=Inception

WP_ADMIN_USER=siteowner
WP_ADMIN_PASSWORD=change_me
WP_ADMIN_EMAIL=example@example.com

WP_USER=author
WP_USER_PASSWORD=change_me
WP_USER_EMAIL=author@example.com

FTP_USER=ftpuser
FTP_PASSWORD=change_me
FTP_PASV_ADDRESS=127.0.0.1

DATA_ROOT=/home/yourlogin/data
```

---

## Docker Compose

The main Compose file is:

```text
srcs/docker-compose.yml
```

Docker Compose is responsible for:

- building service images
- starting containers
- creating the project network
- creating persistent volumes
- passing environment variables
- publishing selected ports
- defining service dependencies

All services use the custom network:

```text
inception
```

The actual Docker network name created by Compose is typically:

```text
srcs_inception
```

---

## Network Design

All services communicate over a Docker bridge network.

Docker provides internal DNS resolution, so containers can use service names instead of hardcoded IP addresses.

Examples:

```text
mariadb:3306
redis:6379
wordpress:9000
static-site:80
monitor:9090
```

This is preferable to using container IP addresses because container IPs may change after recreation.

Host networking is not used.

Docker `links` are not used.

---

## Persistent Storage

Two mandatory persistent storage locations are used.

### WordPress

Host:

```text
/home/eeravci/data/wordpress
```

Container:

```text
/var/www/html
```

### MariaDB

Host:

```text
/home/eeravci/data/mariadb
```

Container:

```text
/var/lib/mysql
```

These are configured as Docker volumes backed by bind-mounted host directories.

This allows data to survive:

- container restart
- container recreation
- Docker restart
- VM reboot

---

# Service Details

## NGINX

### Purpose

NGINX is the public entry point of the infrastructure.

It handles:

- HTTPS connections
- TLS certificates
- WordPress traffic
- FastCGI forwarding
- static portfolio proxying
- monitoring endpoint proxying

### Port

```text
443
```

Port `80` is not exposed on the host.

### Startup Script

File:

```text
srcs/requirements/nginx/tools/start-nginx.sh
```

The script:

1. checks that `DOMAIN_NAME` exists
2. creates the SSL directory
3. generates a self-signed certificate if missing
4. substitutes the domain name into the NGINX configuration
5. validates the NGINX configuration
6. starts NGINX in foreground mode

Important final command:

```bash
exec nginx -g "daemon off;"
```

`exec` replaces the shell with NGINX.

`daemon off` keeps NGINX in the foreground.

---

## WordPress

### Purpose

WordPress provides the main website.

It runs with PHP-FPM and communicates with MariaDB and Redis.

### Internal Port

```text
9000
```

### Startup Script

File:

```text
srcs/requirements/wordpress/tools/start-wordpress.sh
```

The script:

1. validates required environment variables
2. creates PHP runtime directories
3. downloads WordPress if missing
4. waits until MariaDB is available
5. creates `wp-config.php` if missing
6. installs WordPress if not already installed
7. creates the additional WordPress user
8. configures Redis object caching
9. starts PHP-FPM in foreground mode

Final command:

```bash
exec php-fpm8.2 -F
```

The `-F` option keeps PHP-FPM in the foreground.

---

## MariaDB

### Purpose

MariaDB stores WordPress database data.

Examples include:

- users
- posts
- pages
- comments
- WordPress options
- metadata

### Internal Port

```text
3306
```

### Startup Script

File:

```text
srcs/requirements/mariadb/tools/start-mariadb.sh
```

The script:

1. validates database environment variables
2. creates MariaDB runtime directories
3. sets correct ownership
4. detects whether the database is already initialized
5. initializes the MariaDB data directory on first startup
6. runs initial SQL in bootstrap mode
7. creates the WordPress database
8. creates the database user
9. grants permissions
10. starts MariaDB in the foreground

Final command:

```bash
exec mariadbd --user=mysql
```

MariaDB is not started with background processes.

The initialization is performed synchronously.

---

## Redis

### Purpose

Redis is used as a WordPress object cache.

It stores frequently accessed data in memory and reduces repeated MariaDB queries.

### Internal Port

```text
6379
```

WordPress connects to:

```text
redis:6379
```

### Test

```bash
docker exec srcs-redis-1 redis-cli ping
```

Expected:

```text
PONG
```

Check WordPress integration:

```bash
docker exec srcs-wordpress-1 \
    wp redis status \
    --allow-root \
    --path=/var/www/html
```

---

## FTP

### Purpose

The FTP service allows authenticated access to WordPress files.

It uses:

```text
vsftpd
```

The FTP container shares the WordPress volume.

This means FTP and WordPress access the same `/var/www/html` files.

### Local Port

```text
127.0.0.1:21
```

### Configuration

File:

```text
srcs/requirements/ftp/conf/vsftpd.conf
```

Important configuration:

```text
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/var/www/html
pasv_enable=YES
```

### Startup Script

File:

```text
srcs/requirements/ftp/tools/start-ftp.sh
```

The script:

1. validates FTP environment variables
2. creates required vsftpd runtime directories
3. creates or updates the FTP user
4. sets the FTP user password
5. configures access to `/var/www/html`
6. generates the final vsftpd configuration
7. starts vsftpd

Final command:

```bash
exec /usr/sbin/vsftpd /etc/vsftpd.conf
```

---

## Adminer

### Purpose

Adminer provides a browser interface for MariaDB.

It allows inspection of:

- databases
- tables
- rows
- users
- WordPress data

### Local Access

```text
http://127.0.0.1:8080
```

Adminer connects to MariaDB through the Docker network.

Database server:

```text
mariadb
```

---

## Static Portfolio

### Purpose

The static-site service provides a separate static website.

It runs inside its own NGINX container.

### Internal Port

```text
80
```

The port is not published directly to the host.

Instead, the main NGINX service proxies:

```text
https://eeravci.42.fr/portfolio/
```

to:

```text
static-site:80
```

The static content is stored in:

```text
srcs/requirements/static-site/index.html
```

---

## Monitor Service

### Purpose

The monitor service is a custom Python HTTP application.

It checks TCP reachability of the other services.

### Internal Port

```text
9090
```

### Monitored Services

```text
MariaDB      3306
Redis        6379
WordPress    9000
Adminer      8080
FTP          21
Static Site  80
NGINX        443
```

### Endpoints

Dashboard:

```text
/
```

Health endpoint:

```text
/health
```

Public route:

```text
https://eeravci.42.fr/health
```

Example response:

```json
{
  "status": "healthy",
  "services": {
    "mariadb": "up",
    "redis": "up",
    "wordpress": "up",
    "adminer": "up",
    "ftp": "up",
    "static-site": "up",
    "nginx": "up"
  }
}
```

A healthy system returns HTTP `200`.

A degraded system returns HTTP `503`.

The monitor performs TCP reachability checks.

It does not perform deep application-level checks such as SQL queries.

---

# Development Workflow

## Build and Start

From the repository root:

```bash
make
```

or:

```bash
make up
```

Equivalent command:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up -d --build
```

---

## Stop Containers

```bash
make stop
```

---

## Remove Containers and Network

```bash
make down
```

---

## Check Service Status

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

---

## Rebuild a Single Service

Example:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    build nginx
```

Then recreate it:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up -d nginx
```

---

## Rebuild Everything

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    build --no-cache
```

Then:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up -d
```

---

# Debugging

## Show Running Containers

```bash
docker ps
```

Show all containers:

```bash
docker ps -a
```

---

## Show Logs

Example:

```bash
docker logs srcs-nginx-1
```

Follow logs:

```bash
docker logs -f srcs-nginx-1
```

Other examples:

```bash
docker logs srcs-wordpress-1
docker logs srcs-mariadb-1
docker logs srcs-redis-1
docker logs srcs-ftp-1
docker logs srcs-adminer-1
docker logs srcs-static-site-1
docker logs srcs-monitor-1
```

---

## Enter a Container

Example:

```bash
docker exec -it srcs-nginx-1 sh
```

WordPress:

```bash
docker exec -it srcs-wordpress-1 sh
```

MariaDB:

```bash
docker exec -it srcs-mariadb-1 sh
```

---

## Inspect Network

```bash
docker network ls
```

```bash
docker network inspect srcs_inception
```

This shows:

- connected containers
- container IP addresses
- subnet
- gateway

Container IPs are useful for debugging only.

Service names should be used for normal communication.

---

## Inspect Volumes

```bash
docker volume ls
```

WordPress:

```bash
docker volume inspect srcs_wordpress_data
```

MariaDB:

```bash
docker volume inspect srcs_mariadb_data
```

---

# Testing

## NGINX HTTPS

```bash
curl -kI https://eeravci.42.fr
```

Expected:

```text
HTTP/1.1 200 OK
```

---

## HTTP Port 80

```bash
curl -I http://eeravci.42.fr
```

Expected:

```text
connection failure
```

Port 80 must not be available on the host.

---

## TLS 1.2

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_2
```

---

## TLS 1.3

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_3
```

---

## WordPress Users

```bash
docker exec srcs-wordpress-1 \
    wp user list \
    --allow-root \
    --path=/var/www/html
```

---

## WordPress Pages

```bash
docker exec srcs-wordpress-1 \
    wp post list \
    --post_type=page \
    --allow-root \
    --path=/var/www/html
```

---

## MariaDB Root Authentication

A root login without a password should fail:

```bash
docker exec -it srcs-mariadb-1 mariadb -u root
```

Expected:

```text
Access denied
```

---

## MariaDB User Login

```bash
docker exec -it srcs-mariadb-1 mariadb -u <MYSQL_USER> -p
```

Then:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
```

---

## Redis

```bash
docker exec srcs-redis-1 redis-cli ping
```

Expected:

```text
PONG
```

---

## FTP

Connect:

```bash
ftp 127.0.0.1
```

After login:

```text
pwd
ls
```

The WordPress files should be visible.

---

## Adminer

Open:

```text
http://127.0.0.1:8080
```

Connection:

```text
System:   MySQL
Server:   mariadb
Username: MYSQL_USER
Password: MYSQL_PASSWORD
Database: MYSQL_DATABASE
```

---

## Static Portfolio

Open:

```text
https://eeravci.42.fr/portfolio/
```

Internal test:

```bash
docker inspect \
    -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    srcs-static-site-1
```

---

## Monitor

Public test:

```bash
curl -k https://eeravci.42.fr/health
```

Internal test:

```bash
docker exec srcs-monitor-1 \
    python3 -c \
    "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:9090/health').read().decode())"
```

---

# Persistence Testing

Persistent storage should survive container recreation and VM reboot.

## WordPress Persistence

Create or edit content in WordPress.

Example check:

```bash
docker exec srcs-wordpress-1 \
    wp post list \
    --post_type=page \
    --allow-root \
    --path=/var/www/html
```

Reboot the VM:

```bash
sudo reboot
```

After startup:

```bash
cd ~/inception
make
```

Check the same WordPress content again.

It should still exist.

---

## MariaDB Persistence

MariaDB files are stored under:

```text
/home/eeravci/data/mariadb
```

The database should still contain the WordPress tables and data after restart or reboot.

---

# Docker Process Management

The containers do not use artificial keep-alive commands such as:

```text
tail -f /dev/null
sleep infinity
```

Each service runs its actual server process in the foreground.

Examples:

```bash
exec nginx -g "daemon off;"
```

```bash
exec php-fpm8.2 -F
```

```bash
exec mariadbd --user=mysql
```

```bash
exec /usr/sbin/vsftpd /etc/vsftpd.conf
```

Using `exec` replaces the startup shell with the main service process.

This allows the service to become PID 1 inside the container.

---

# Shell Script Safety

Startup scripts use:

```bash
set -eu
```

`-e` stops the script when a command fails.

`-u` treats access to an unset variable as an error.

Required environment variables are validated with syntax such as:

```bash
: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set}"
```

This makes the container fail early when required configuration is missing.

---

# Dockerfile Design

Each service has its own Dockerfile.

The images are built from:

```dockerfile
FROM debian:12-slim
```

The Dockerfiles:

- install only required packages
- remove APT package lists after installation where appropriate
- copy configuration or startup scripts
- expose internal service ports
- start the main service in foreground mode

---

# Important Concepts

## Dockerfile

A Dockerfile describes how an image is built.

Example:

```text
Dockerfile
    |
    v
docker build
    |
    v
Image
```

---

## Image

An image is an immutable template used to create containers.

---

## Container

A container is a running instance of an image.

---

## Docker Compose

Docker Compose orchestrates multiple containers together.

It manages:

- service builds
- runtime configuration
- networks
- volumes
- ports
- environment variables
- startup dependencies

---

## EXPOSE vs ports

Dockerfile:

```dockerfile
EXPOSE 9000
```

documents the internal service port.

It does not publish that port to the host.

Compose:

```yaml
ports:
  - "443:443"
```

publishes the port.

This maps:

```text
host:443 -> container:443
```

---

## depends_on

Example:

```yaml
depends_on:
  - mariadb
```

This controls container startup order.

It does not guarantee that the application inside the container is ready.

For this reason, WordPress also waits for MariaDB:

```bash
until mariadb-admin ping -h mariadb --silent; do
    sleep 2
done
```

---

## restart: unless-stopped

Containers use:

```yaml
restart: unless-stopped
```

Docker automatically restarts the container after failure or Docker daemon restart unless the container was manually stopped.

---

# Common Problems

## Docker Permission Denied

Example:

```text
permission denied while trying to connect to the Docker daemon socket
```

Check:

```bash
groups
```

Add the user to the Docker group if required:

```bash
sudo usermod -aG docker $USER
```

Then log out and log back in.

---

## Domain Does Not Work

Check `/etc/hosts`.

Example:

```text
127.0.0.1 eeravci.42.fr
```

Then test:

```bash
curl -kI https://eeravci.42.fr
```

---

## WordPress Shows Wrong Domain

Check:

```bash
docker exec srcs-wordpress-1 \
    wp option get home \
    --allow-root \
    --path=/var/www/html
```

```bash
docker exec srcs-wordpress-1 \
    wp option get siteurl \
    --allow-root \
    --path=/var/www/html
```

Update if required:

```bash
docker exec srcs-wordpress-1 \
    wp option update home \
    'https://eeravci.42.fr' \
    --allow-root \
    --path=/var/www/html
```

```bash
docker exec srcs-wordpress-1 \
    wp option update siteurl \
    'https://eeravci.42.fr' \
    --allow-root \
    --path=/var/www/html
```

---

## MariaDB Login Problems

Check MariaDB logs:

```bash
docker logs srcs-mariadb-1
```

Verify environment variables.

Then test:

```bash
docker exec -it srcs-mariadb-1 \
    mariadb -u <MYSQL_USER> -p
```

---

## WordPress Cannot Reach MariaDB

Test Docker DNS:

```bash
docker exec srcs-wordpress-1 \
    getent hosts mariadb
```

Check MariaDB:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps mariadb
```

---

## Redis Is Not Connected

Check Redis:

```bash
docker exec srcs-redis-1 redis-cli ping
```

Then check WordPress:

```bash
docker exec srcs-wordpress-1 \
    wp redis status \
    --allow-root \
    --path=/var/www/html
```

---

## Monitor Reports a Service as Down

Check the service directly:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

Check service logs:

```bash
docker logs <container-name>
```

Then test the expected service port.

---

# Cleaning the Project

Stop and remove containers:

```bash
make down
```

List remaining objects:

```bash
docker ps -a
docker images
docker volume ls
docker network ls
```

Be careful when deleting volumes because they contain persistent application data.

---

# Git Hygiene

The following files should not be committed:

```text
srcs/.env
__pycache__/
*.pyc
```

Recommended `.gitignore` entries:

```gitignore
srcs/.env
**/__pycache__/
*.pyc
```

Do not commit real passwords or secrets.

Use:

```text
srcs/.env.example
```

as the repository configuration template.

---

# Development Notes

The project is intentionally structured so that each service is independent.

Each service has:

- its own Dockerfile
- its own dependencies
- its own configuration
- its own startup process

The services are connected only through Docker networking and shared persistent storage where required.

This keeps the infrastructure modular and easier to inspect, debug, rebuild, and explain during evaluation.
