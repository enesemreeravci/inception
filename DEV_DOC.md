# Inception Developer Documentation

## Architecture

The project contains four containers:

```text
Browser
   │
   ├── HTTPS :443 ──> NGINX
   └── HTTP :8080 ──> Adminer
                         │
                         └── MariaDB :3306

NGINX ──> WordPress/PHP-FPM :9000
WordPress ──> MariaDB :3306
```

All services use the private Docker bridge network `inception`.

## Prerequisites

Install:

```bash
docker --version
docker compose version
git --version
```

The Docker user must have Docker permissions:

```bash
id -nG
```

The output should include `docker`.

## Environment Setup

Create the private environment file:

```bash
cp srcs/.env.example srcs/.env
```

Edit it:

```bash
vim srcs/.env
```

The file must contain the domain, database credentials, and WordPress credentials.

Verify Compose syntax:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml config -q
```

No output means valid configuration.

## Build and Start

Start the full project:

```bash
make up
```

Equivalent command:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

List services:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml config --services
```

Expected services:

```text
nginx
mariadb
wordpress
adminer
```

## Service Management

Check status:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

Rebuild one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml build adminer
```

Restart one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml restart adminer
```

View logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs -f adminer
```

Open a shell:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec adminer sh
```

## Adminer Service

Adminer is defined in:

```text
srcs/requirements/adminer/Dockerfile
```

It runs PHP’s built-in web server on port `8080`.

The Compose mapping is:

```text
127.0.0.1:8080:8080
```

This makes Adminer available only from the local VM.

Inside the Docker network, Adminer connects to MariaDB using:

```text
mariadb:3306
```

Adminer must use HTTP:

```text
http://127.0.0.1:8080
```

## Volumes

List volumes:

```bash
docker volume ls
```

Inspect MariaDB volume:

```bash
docker volume inspect srcs_mariadb_data
```

Inspect WordPress volume:

```bash
docker volume inspect srcs_wordpress_data
```

Host data locations:

```text
/home/eeravci/data/mariadb
/home/eeravci/data/wordpress
```

Removing containers does not remove these directories.

Avoid:

```bash
docker compose down -v
```

unless deleting all project data is intentional.

## Network

List networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

Service names resolve through Docker DNS:

```text
mariadb
wordpress
adminer
```

No host networking or legacy links are used.

## Validation

Check shell scripts:

```bash
for file in srcs/requirements/*/tools/*.sh; do
    echo "Checking $file"
    sh -n "$file" || exit 1
done
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

Test Adminer:

```bash
curl -I http://127.0.0.1:8080/
```

Expected result:

```text
HTTP/1.1 200 OK
```

Test HTTPS:

```bash
curl -k -I --resolve eeravci.42.fr:443:127.0.0.1 \
https://eeravci.42.fr
```

## Git Workflow

Check changes:

```bash
git status
```

Review changes:

```bash
git diff
```

Check formatting:

```bash
git diff --check
```

Stage the bonus changes:

```bash
git add README.md USER_DOC.md DEV_DOC.md \
srcs/docker-compose.yml \
srcs/requirements/adminer/Dockerfile
```

Commit:

```bash
git commit -m "Add Adminer database administration service"
```

Push:

```bash
git push origin main
```

Verify:

```bash
git status
```

The `.env` file must never be staged.

