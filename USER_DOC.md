# User Documentation

## Overview

This document explains how to configure, start, stop, access, and use the Inception infrastructure.

The project provides:

- WordPress website
- NGINX with HTTPS
- MariaDB database
- Redis object cache
- FTP access to WordPress files
- Adminer database interface
- Static portfolio website
- Service monitoring endpoint

The infrastructure is managed with Docker Compose through the provided Makefile.

---

## Prerequisites

The system requires:

- Linux or a Linux virtual machine
- Docker
- Docker Compose
- Make
- Git

Check that Docker is installed:

```bash
docker --version
```

Check Docker Compose:

```bash
docker compose version
```

Check Make:

```bash
make --version
```

---

## Project Setup

Clone or copy the project to the machine.

Enter the project directory:

```bash
cd inception
```

The project root should contain:

```text
Makefile
README.md
USER_DOC.md
DEV_DOC.md
srcs/
```

---

## Environment Configuration

The project requires a private environment file.

Create it from the example:

```bash
cp srcs/.env.example srcs/.env
```

Then edit:

```text
srcs/.env
```

The environment file contains configuration such as:

- domain name
- database name
- database username
- database passwords
- WordPress credentials
- FTP credentials
- data storage path

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

Do not commit the real `.env` file to Git.

---

## Hostname Configuration

The main website uses:

```text
https://eeravci.42.fr
```

The hostname must resolve to the local machine.

If required, edit:

```text
/etc/hosts
```

and add:

```text
127.0.0.1 eeravci.42.fr
```

Check resolution:

```bash
getent hosts eeravci.42.fr
```

---

## Data Directories

The project stores persistent data on the host.

Create the directories if they do not already exist:

```bash
mkdir -p /home/eeravci/data/wordpress
mkdir -p /home/eeravci/data/mariadb
```

These directories store:

```text
/home/eeravci/data/wordpress
```

WordPress files.

```text
/home/eeravci/data/mariadb
```

MariaDB database files.

These directories allow important data to survive container recreation and virtual machine reboots.

---

# Starting the Project

From the project root:

```bash
make
```

or:

```bash
make up
```

The project will:

1. build the Docker images
2. create the Docker network
3. create the persistent volumes
4. start all containers

---

## Check Running Services

Run:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

All services should show:

```text
Up
```

The running services include:

```text
nginx
wordpress
mariadb
redis
ftp
adminer
static-site
monitor
```

---

# Accessing the Services

## WordPress Website

Open:

```text
https://eeravci.42.fr
```

The browser may display a certificate warning because the project uses a self-signed TLS certificate.

This is expected.

---

## WordPress Administration

Open:

```text
https://eeravci.42.fr/wp-admin
```

Log in using the WordPress administrator credentials configured in:

```text
srcs/.env
```

Variables:

```text
WP_ADMIN_USER
WP_ADMIN_PASSWORD
```

The administrator username should not contain:

```text
admin
```

---

## Regular WordPress User

A second WordPress user is also created.

Use the credentials configured through:

```text
WP_USER
WP_USER_PASSWORD
```

This account can be used for normal WordPress actions such as creating content or comments depending on its role.

---

## Static Portfolio

Open:

```text
https://eeravci.42.fr/portfolio/
```

The portfolio runs in a separate container and is served through the main NGINX reverse proxy.

---

## Monitor Health Endpoint

Open:

```text
https://eeravci.42.fr/health
```

or test from the terminal:

```bash
curl -k https://eeravci.42.fr/health
```

Example output:

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

When every monitored service is reachable, the overall status is:

```text
healthy
```

---

## Adminer

Adminer is available locally at:

```text
http://127.0.0.1:8080
```

Use the following connection values:

```text
System:   MySQL
Server:   mariadb
Username: MYSQL_USER
Password: MYSQL_PASSWORD
Database: MYSQL_DATABASE
```

Use the actual values from:

```text
srcs/.env
```

Adminer can be used to inspect:

- WordPress tables
- users
- posts
- comments
- WordPress options
- database structure

---

## FTP

FTP is available locally through:

```text
127.0.0.1:21
```

Connect with:

```bash
ftp 127.0.0.1
```

Use:

```text
Username: FTP_USER
Password: FTP_PASSWORD
```

from:

```text
srcs/.env
```

After logging in, useful FTP commands include:

```text
pwd
ls
get
put
quit
```

The FTP user accesses the WordPress files.

You should see files such as:

```text
index.php
wp-admin
wp-content
wp-includes
wp-config.php
```

Anonymous FTP access is disabled.

---

# WordPress Usage

## Log In

Open:

```text
https://eeravci.42.fr/wp-admin
```

Enter the configured administrator credentials.

---

## Edit a Page

From the WordPress dashboard:

1. open `Pages`
2. choose a page
3. edit the content
4. click `Update`
5. open the page on the website
6. verify that the change is visible

The change is stored in MariaDB and survives container recreation.

---

## Add a Comment

Use the normal WordPress interface.

If comments are enabled on a post or page:

1. open the content
2. enter a comment
3. submit it
4. verify that it appears

---

# Stopping the Project

Stop the running containers:

```bash
make stop
```

This stops the containers without deleting the persistent data.

---

## Remove Containers and Network

Run:

```bash
make down
```

This removes the containers and project network.

Persistent WordPress and MariaDB data remains unless the volumes or host data directories are intentionally deleted.

---

# Restarting the Project

After stopping or rebooting the machine:

```bash
cd ~/inception
make
```

Check the services:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

The existing WordPress content and database data should still be available.

---

# Persistence

The project stores persistent data outside the containers.

WordPress data:

```text
/home/eeravci/data/wordpress
```

MariaDB data:

```text
/home/eeravci/data/mariadb
```

This means that:

- restarting a container does not remove the data
- recreating a container does not remove the data
- rebooting the VM does not remove the data

---

## Verify WordPress Persistence

Edit a WordPress page.

Then reboot:

```bash
sudo reboot
```

After the VM restarts:

```bash
cd ~/inception
make
```

Open:

```text
https://eeravci.42.fr
```

The previous WordPress content should still exist.

---

# Testing the Infrastructure

## HTTPS

Run:

```bash
curl -kI https://eeravci.42.fr
```

Expected:

```text
HTTP/1.1 200 OK
```

---

## HTTP Port 80

Run:

```bash
curl -I http://eeravci.42.fr
```

The connection should fail because the main website is only exposed through HTTPS port `443`.

---

## TLS 1.2

Run:

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_2
```

The connection should succeed.

---

## TLS 1.3

Run:

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_3
```

The connection should succeed.

---

## Redis

Test Redis:

```bash
docker exec srcs-redis-1 redis-cli ping
```

Expected:

```text
PONG
```

Check WordPress Redis connection:

```bash
docker exec srcs-wordpress-1 \
    wp redis status \
    --allow-root \
    --path=/var/www/html
```

Expected status:

```text
Connected
```

---

## MariaDB

Test that root access without a password is rejected:

```bash
docker exec -it srcs-mariadb-1 mariadb -u root
```

Expected:

```text
Access denied
```

Connect using the configured database user:

```bash
docker exec -it srcs-mariadb-1 \
    mariadb -u <MYSQL_USER> -p
```

Inside MariaDB:

```sql
SHOW DATABASES;
```

Then:

```sql
USE wordpress;
```

and:

```sql
SHOW TABLES;
```

---

## WordPress Users

List WordPress users:

```bash
docker exec srcs-wordpress-1 \
    wp user list \
    --allow-root \
    --path=/var/www/html
```

---

## Monitor

Test:

```bash
curl -k https://eeravci.42.fr/health
```

A working system should report:

```text
healthy
```

---

# Viewing Logs

If a service does not work, check its logs.

NGINX:

```bash
docker logs srcs-nginx-1
```

WordPress:

```bash
docker logs srcs-wordpress-1
```

MariaDB:

```bash
docker logs srcs-mariadb-1
```

Redis:

```bash
docker logs srcs-redis-1
```

FTP:

```bash
docker logs srcs-ftp-1
```

Adminer:

```bash
docker logs srcs-adminer-1
```

Static site:

```bash
docker logs srcs-static-site-1
```

Monitor:

```bash
docker logs srcs-monitor-1
```

---

# Common Problems

## Docker Permission Denied

If Docker returns:

```text
permission denied while trying to connect to the Docker daemon socket
```

Check the current groups:

```bash
groups
```

If necessary, add the current user to the Docker group:

```bash
sudo usermod -aG docker $USER
```

Log out and log in again.

---

## Website Does Not Open

Check that the containers are running:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

Check NGINX:

```bash
docker logs srcs-nginx-1
```

Test:

```bash
curl -kI https://eeravci.42.fr
```

---

## Domain Does Not Resolve

Check:

```bash
getent hosts eeravci.42.fr
```

If required, add the hostname to:

```text
/etc/hosts
```

Example:

```text
127.0.0.1 eeravci.42.fr
```

---

## WordPress Shows Installation Page

Check the WordPress container:

```bash
docker logs srcs-wordpress-1
```

Check MariaDB:

```bash
docker logs srcs-mariadb-1
```

Check whether WordPress is installed:

```bash
docker exec srcs-wordpress-1 \
    wp core is-installed \
    --allow-root \
    --path=/var/www/html
```

---

## WordPress Cannot Reach MariaDB

Check MariaDB status:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps mariadb
```

Check Docker name resolution:

```bash
docker exec srcs-wordpress-1 \
    getent hosts mariadb
```

---

## Redis Is Not Connected

Run:

```bash
docker exec srcs-redis-1 redis-cli ping
```

Then:

```bash
docker exec srcs-wordpress-1 \
    wp redis status \
    --allow-root \
    --path=/var/www/html
```

---

## FTP Login Fails

Check the FTP container:

```bash
docker logs srcs-ftp-1
```

Verify the credentials inside:

```text
srcs/.env
```

Connect again:

```bash
ftp 127.0.0.1
```

Use:

```text
FTP_USER
FTP_PASSWORD
```

---

## Adminer Cannot Connect

Make sure the database server field is:

```text
mariadb
```

Do not use:

```text
127.0.0.1
```

for the MariaDB server inside Adminer.

The Adminer container communicates with MariaDB through the Docker network.

---

## Monitor Reports Degraded

Check:

```bash
curl -k https://eeravci.42.fr/health
```

The response shows which service is down.

Then inspect that service:

```bash
docker logs <container-name>
```

and:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

---

# Important Notes

Do not manually delete:

```text
/home/eeravci/data/wordpress
```

or:

```text
/home/eeravci/data/mariadb
```

unless you intentionally want to remove the persistent project data.

Do not commit:

```text
srcs/.env
```

to Git.

Do not expose MariaDB or WordPress PHP-FPM directly to the public host network.

The main public entry point is:

```text
https://eeravci.42.fr
```

through NGINX on port `443`.

---

# Service Summary

| Service | Port | Access |
|---|---:|---|
| NGINX | 443 | Public HTTPS |
| WordPress / PHP-FPM | 9000 | Internal |
| MariaDB | 3306 | Internal |
| Redis | 6379 | Internal |
| FTP | 21 | Localhost |
| Adminer | 8080 | Localhost |
| Static Site | 80 | Internal through NGINX |
| Monitor | 9090 | Internal through NGINX |

---

# Quick Start

Configure:

```bash
cp srcs/.env.example srcs/.env
```

Start:

```bash
make
```

Check:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

Open:

```text
https://eeravci.42.fr
```

Admin:

```text
https://eeravci.42.fr/wp-admin
```

Portfolio:

```text
https://eeravci.42.fr/portfolio/
```

Monitor:

```text
https://eeravci.42.fr/health
```

Adminer:

```text
http://127.0.0.1:8080
```

Stop:

```bash
make stop
```

Remove containers:

```bash
make down
```
