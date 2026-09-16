# Inception Developer Documentation

## Project Overview

Inception is a Docker-based WordPress infrastructure composed of three independent services:

```text
NGINX → WordPress/PHP-FPM → MariaDB
```

The services run in separate containers and communicate through the Docker network named `inception`.

Only NGINX is exposed to the host:

```text
Host port 443 → NGINX container port 443
```

WordPress and MariaDB are accessible only inside the Docker network.

## Prerequisites

Install the following:

* Docker Engine
* Docker Compose plugin
* Git
* Linux, or a Linux virtual machine
* Internet access during the first image build and WordPress download

Verify the installation:

```bash
docker --version
docker compose version
git --version
```

The Docker user must be allowed to access the Docker daemon:

```bash
id -nG
```

The output should include:

```text
docker
```

## Repository Structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs
    ├── .env
    ├── .env.example
    ├── docker-compose.yml
    └── requirements
        ├── nginx
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── nginx.conf
        │   └── tools
        │       └── start-nginx.sh
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── 50-server.cnf
        │   └── tools
        │       └── start-mariadb.sh
        └── wordpress
            ├── Dockerfile
            └── tools
                └── start-wordpress.sh
```

## Environment Configuration

The Compose file reads configuration values from `srcs/.env`.

Create it from the template:

```bash
cd ~/inception
cp srcs/.env.example srcs/.env
```

Edit the file:

```bash
vim srcs/.env
```

Required variables include:

```dotenv
DOMAIN_NAME=yourlogin.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD=your-database-password
MYSQL_ROOT_PASSWORD=your-root-password
WP_TITLE=Inception
WP_ADMIN_USER=siteowner
WP_ADMIN_PASSWORD=your-admin-password
WP_ADMIN_EMAIL=your-email@example.com
WP_USER=author
WP_USER_PASSWORD=your-user-password
WP_USER_EMAIL=author@example.com
```

The `.env` file must remain local and must not be committed.

Check that it is ignored:

```bash
git check-ignore srcs/.env
```

The expected output is:

```text
srcs/.env
```

## Docker Compose Configuration

Validate the Compose file:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml config -q
```

No output means the configuration is valid.

List the services:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml config --services
```

Expected services:

```text
nginx
mariadb
wordpress
```

List the images:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml config --images
```

## Makefile Commands

The Makefile defines the main project operations:

```bash
make up
```

Build images and start all services:

```bash
make up
```

Stop containers while preserving volumes:

```bash
make stop
```

Remove containers and the project network while preserving volumes:

```bash
make down
```

Follow logs:

```bash
make logs
```

The equivalent Compose command is:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs -f
```

## Building and Launching

Build and start the complete infrastructure:

```bash
make up
```

Or directly:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

Check running containers:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

Expected services:

```text
srcs-nginx-1
srcs-wordpress-1
srcs-mariadb-1
```

## Managing Individual Services

Rebuild only one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml build wordpress
```

Restart one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml restart wordpress
```

Stop one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml stop nginx
```

Open a shell inside a running container:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress sh
```

Exit the shell:

```bash
exit
```

## Service Details

### NGINX

NGINX is built from:

```text
srcs/requirements/nginx/Dockerfile
```

Configuration:

```text
srcs/requirements/nginx/conf/nginx.conf
```

Startup script:

```text
srcs/requirements/nginx/tools/start-nginx.sh
```

The startup script:

1. Validates `DOMAIN_NAME`.
2. Creates a self-signed TLS certificate if necessary.
3. Substitutes `${DOMAIN_NAME}` into the NGINX configuration.
4. Tests the configuration.
5. Starts NGINX in the foreground.

Test the configuration:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec nginx nginx -t
```

### MariaDB

MariaDB is built from:

```text
srcs/requirements/mariadb/Dockerfile
```

Configuration:

```text
srcs/requirements/mariadb/conf/50-server.cnf
```

Startup script:

```text
srcs/requirements/mariadb/tools/start-mariadb.sh
```

During first startup, the script:

1. Validates the database environment variables.
2. Creates the required runtime directories.
3. Initializes the MariaDB system tables.
4. Starts a temporary local server.
5. Creates the configured database and user.
6. Grants database privileges.
7. Stops the temporary server.
8. Starts MariaDB normally in the foreground.

Test MariaDB:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb-admin ping -uroot -p
```

Inspect databases:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb -uroot -p
```

Then:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
EXIT;
```

### WordPress

WordPress is built from:

```text
srcs/requirements/wordpress/Dockerfile
```

Startup script:

```text
srcs/requirements/wordpress/tools/start-wordpress.sh
```

The container installs:

* PHP-FPM
* PHP MySQL extension
* PHP CLI
* Required WordPress PHP extensions
* MariaDB client
* WP-CLI

During first startup, the script:

1. Validates all required environment variables.
2. Downloads WordPress if the files are missing.
3. Waits for MariaDB to become available.
4. Generates `wp-config.php`.
5. Installs WordPress.
6. Creates the configured regular user.
7. Starts PHP-FPM in the foreground.

Test PHP-FPM:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress php-fpm8.2 -t
```

Test WordPress:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress \
wp core is-installed --path=/var/www/html --allow-root
```

List WordPress users:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress \
wp user list --path=/var/www/html --allow-root
```

## Volumes and Persistent Storage

The Compose file defines two named volumes:

```text
srcs_mariadb_data
srcs_wordpress_data
```

They are backed by these host directories:

```text
/home/eeravci/data/mariadb
/home/eeravci/data/wordpress
```

List volumes:

```bash
docker volume ls
```

Inspect a volume:

```bash
docker volume inspect srcs_mariadb_data
```

Inspect container mounts:

```bash
docker inspect srcs-mariadb-1 \
--format '{{json .Mounts}}'
```

The data remains when containers are removed:

```bash
make down
make up
```

Do not use `down -v` during normal development because it deletes the volumes.

## Network Management

The services use the Compose-created bridge network:

```text
srcs_inception
```

List networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

Containers resolve one another by service name:

```text
mariadb:3306
wordpress:9000
```

No host networking or legacy Docker links are used.

## Validation and Testing

Check all services:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

Test HTTPS:

```bash
curl -k -I --resolve yourlogin.42.fr:443:127.0.0.1 \
https://yourlogin.42.fr
```

Expected result:

```text
HTTP/1.1 200 OK
```

Test a static WordPress file:

```bash
curl -k -I --resolve yourlogin.42.fr:443:127.0.0.1 \
https://yourlogin.42.fr/wp-includes/css/dashicons.min.css
```

Expected result:

```text
HTTP/1.1 200 OK
Content-Type: text/css
```

Check shell-script syntax:

```bash
for file in srcs/requirements/*/tools/*.sh; do
    echo "Checking $file"
    sh -n "$file" || exit 1
done
```

## Logs and Troubleshooting

View all logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs
```

View one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs wordpress
```

Follow logs:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs -f mariadb
```

Check container exit status:

```bash
docker ps -a
```

If a service repeatedly restarts, inspect its logs and verify:

* Required `.env` variables exist
* Volume directories exist
* File permissions are correct
* Dependent services are running
* Configuration syntax is valid

## Clean Rebuild

To rebuild images while preserving data:

```bash
make down
docker image ls
make up
```

To remove unused Docker resources, inspect first:

```bash
docker system df
```

Avoid deleting volumes unless you intentionally want to erase the WordPress and MariaDB data.

## Git Workflow

Check changes:

```bash
git status
```

Review a diff:

```bash
git diff
```

Stage project files:

```bash
git add README.md USER_DOC.md DEV_DOC.md
```

Commit:

```bash
git commit -m "Add project documentation"
```

Push to GitHub:

```bash
git push
```

Never stage the private `.env` file:

```bash
git status --short
```

## Development Data Locations

WordPress application files:

```text
/home/eeravci/data/wordpress
```

MariaDB database files:

```text
/home/eeravci/data/mariadb
```

These directories are outside the container writable layers and therefore survive container recreation.

## Important Development Rules

* Do not use the `latest` tag for project images.
* Do not store passwords in Dockerfiles or committed configuration files.
* Do not publish MariaDB port `3306` to the host.
* Do not publish WordPress PHP-FPM port `9000` to the host.
* Keep NGINX as the public entry point.
* Keep services on the private Docker bridge network.
* Use `exec` for the final foreground process in startup scripts.
* Do not use `docker compose down -v` unless data deletion is intentional.
* Keep `.env` and private credentials out of Git.

