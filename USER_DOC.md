# Inception User Documentation

## Overview

This project provides a WordPress website running through three Docker services:

* **NGINX**: secure HTTPS web server
* **WordPress**: website and administration panel
* **MariaDB**: database server

The services communicate through a private Docker network. Website files and database files are stored persistently on the host machine.

## Requirements

The following must be installed:

* Docker Engine
* Docker Compose
* Git
* A configured Linux environment or virtual machine

Check Docker:

```bash
docker --version
docker compose version
```

## Configuration and Credentials

Configuration is stored in:

```text
srcs/.env
```

The file contains:

* Domain name
* MariaDB database name
* MariaDB user and password
* MariaDB root password
* WordPress site title
* WordPress administrator credentials
* WordPress regular-user credentials

The `.env` file is private and must not be shared or committed to Git.

A safe template is provided at:

```text
srcs/.env.example
```

If the project has not been configured yet:

```bash
cp srcs/.env.example srcs/.env
```

Edit the copied file and replace the example values with your own credentials.

## Starting the Services

From the project root:

```bash
make up
```

This builds the images and starts the containers in the background.

Equivalent command:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

## Accessing the Website

Open this address in a browser:

```text
https://eeravci.42.fr
```

The project uses a self-signed certificate, so the browser may show a security warning during development. Accept the certificate exception only when you trust the local environment.

## Accessing the Administration Panel

Open:

```text
https://eeravci.42.fr/wp-admin
```

Log in with the administrator username and password defined in `srcs/.env`.

The administrator can:

* Create and edit posts
* Manage pages
* Manage media
* Manage themes and plugins
* Manage WordPress users
* Change site settings

A regular user is also created during the first WordPress installation. The regular user has the `author` role.

## Stopping the Services

Stop the running containers:

```bash
make stop
```

Remove the containers and Docker network:

```bash
make down
```

The persistent data remains available after these commands.

Do not use:

```bash
docker compose down -v
```

unless you intentionally want to remove the project volumes and all stored data.

## Checking Service Status

From the project root:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

All three services should show a running status:

```text
nginx
wordpress
mariadb
```

## Checking Logs

View logs for all services:

```bash
make logs
```

View logs for a specific service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs nginx
```

Other service names are:

```text
wordpress
mariadb
```

Follow logs continuously:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs -f wordpress
```

Press `Ctrl+C` to stop following the logs.

## Testing HTTPS

Run:

```bash
curl -k -I --resolve eeravci.42.fr:443:127.0.0.1 \
https://eeravci.42.fr
```

A working installation should return:

```text
HTTP/1.1 200 OK
```

## Testing NGINX

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec nginx nginx -t
```

Expected result:

```text
syntax is ok
test is successful
```

## Testing PHP-FPM

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress php-fpm8.2 -t
```

Expected result:

```text
configuration file ... test is successful
```

## Testing MariaDB

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb-admin ping -uroot -p
```

Enter the MariaDB root password when prompted.

Expected result:

```text
mysqld is alive
```

## Checking WordPress Installation

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress \
wp core is-installed --path=/var/www/html --allow-root
```

No output means WordPress is installed successfully.

## Viewing WordPress Users

Using WP-CLI:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress \
wp user list --path=/var/www/html --allow-root
```

Using MariaDB:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb -uroot -p
```

Then run:

```sql
USE wordpress;

SELECT ID, user_login, user_email, user_registered
FROM wp_users;
```

Exit with:

```sql
EXIT;
```

Never share passwords or password hashes publicly.

## Persistent Data

MariaDB data is stored at:

```text
/home/eeravci/data/mariadb
```

WordPress files are stored at:

```text
/home/eeravci/data/wordpress
```

These locations preserve the website and database data when containers are removed or recreated.

To verify persistence:

```bash
make down
make up
```

Then open the website and confirm that existing users and posts are still present.

## Basic Troubleshooting

### The website does not open

Check the services:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

Check NGINX logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs nginx
```

### WordPress keeps restarting

Check WordPress logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs wordpress
```

Verify that all WordPress and database variables exist in `srcs/.env`.

### MariaDB is unavailable

Check MariaDB logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs mariadb
```

Then test:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb-admin ping -uroot -p
```

### The browser displays an old or unstyled page

Perform a hard refresh in the browser. Then check that NGINX includes the MIME types file and that the WordPress volume contains the expected files.

## Safe Shutdown

For normal daily use:

```bash
make stop
```

For removing containers while keeping data:

```bash
make down
```

Start the project again with:

```bash
make up
```

