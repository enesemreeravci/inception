*This project has been created as part of the 42 curriculum by eeravci*

# Inception

## Description

Inception is a system-administration and Docker infrastructure project from the 42 curriculum.

The goal is to build a small, secure, multi-service web infrastructure using Docker Compose. The stack is composed of separate containers for:

* NGINX
* WordPress
* MariaDB

Each service is built from its own Dockerfile using `debian:12-slim`. The containers communicate through a private Docker bridge network, while persistent data is stored in host-backed Docker volumes.

The project provides a WordPress website accessible through HTTPS at:

```text
https://eeravci.42.fr
```

The NGINX container is the only service exposed to the host. It receives HTTPS requests and forwards PHP requests to the WordPress PHP-FPM container. WordPress stores its data in MariaDB.

## Project Structure

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
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── 50-server.cnf
        │   └── tools
        │       └── start-mariadb.sh
        ├── nginx
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── nginx.conf
        │   └── tools
        │       └── start-nginx.sh
        └── wordpress
            ├── Dockerfile
            └── tools
                └── start-wordpress.sh
```

## Services

### NGINX

NGINX is the public entry point of the infrastructure.

* Listens on HTTPS port `443`
* Uses a self-signed TLS certificate
* Serves WordPress files
* Forwards PHP requests to WordPress on port `9000`
* Uses the configured domain name

### WordPress

WordPress provides the website and administration interface.

* Runs with PHP-FPM
* Listens internally on port `9000`
* Downloads and configures WordPress during first startup
* Connects to MariaDB through the Docker network
* Stores website files in a persistent volume

### MariaDB

MariaDB provides the database used by WordPress.

* Listens internally on port `3306`
* Creates the configured database and user during first startup
* Stores database files in a persistent volume
* Is not directly exposed to the host

## Main Design Choices

* One Dockerfile per service
* One container per service
* Docker Compose manages the complete application
* NGINX is the only publicly exposed service
* WordPress and MariaDB communicate through Docker DNS service names
* Environment variables provide configuration without hardcoding passwords
* Persistent data is stored outside the container filesystem
* Services run in the foreground so Docker can monitor them correctly
* Image versions and WordPress versions are explicitly pinned

## Instructions

### Prerequisites

Install:

* Docker Engine
* Docker Compose plugin
* Git
* A Linux environment or a compatible Docker environment

Check the installation:

```bash
docker --version
docker compose version
```

### Configuration

Copy the example environment file:

```bash
cp srcs/.env.example srcs/.env
```

Edit `srcs/.env` and set your own values:

```dotenv
DOMAIN_NAME=yourlogin.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD=change-me
MYSQL_ROOT_PASSWORD=change-me-root
WP_TITLE=Inception
WP_ADMIN_USER=siteowner
WP_ADMIN_PASSWORD=choose-a-password
WP_ADMIN_EMAIL=your-email@example.com
WP_USER=author
WP_USER_PASSWORD=choose-another-password
WP_USER_EMAIL=author@example.com
```

The `.env` file contains private values and must not be committed to Git.

### Start the project

From the repository root:

```bash
make up
```

This builds the images and starts all services in detached mode.

Equivalent command:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

### Stop the project

Stop containers while preserving volumes:

```bash
make stop
```

Remove containers and the Docker network while preserving volumes:

```bash
make down
```

Do not use `docker compose down -v` unless you intentionally want to delete the persistent volumes.

### View logs

```bash
make logs
```

Or view one service:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml logs nginx
```

### Check service status

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml ps
```

### Access WordPress

Open the following URL in a browser inside the VM or configured host environment:

```text
https://yourlogin.42.fr
```

The WordPress administration panel is available at:

```text
https://yourlogin.42.fr/wp-admin
```

Because the project uses a self-signed certificate, the browser may display a certificate warning during development.

## Technical Comparisons

### Virtual Machines vs Docker

A virtual machine emulates a complete computer, including its own kernel and operating system. This provides strong isolation but requires more memory, storage, and startup time.

Docker containers share the host kernel and isolate applications and their dependencies. Containers are lighter, start faster, and are easier to reproduce.

This project uses Docker because each service can run independently while sharing a private network and persistent storage.

### Secrets vs Environment Variables

Environment variables are simple configuration values passed to containers. They are suitable for development, but passwords may be visible through Compose configuration or container inspection.

Docker secrets provide a more secure mechanism for sensitive data by mounting secret values as files inside containers. They are preferable for production systems.

This project uses an ignored `.env` file for simplicity and because it is intended for development and educational purposes. Real credentials must never be committed to Git.

### Docker Network vs Host Network

A Docker bridge network creates an isolated virtual network for containers. Containers can reach each other by service name, such as:

```text
mariadb:3306
wordpress:9000
```

Host networking removes this isolation and places containers directly on the host network.

This project uses a private bridge network so that MariaDB and WordPress remain internal. Only NGINX publishes port `443` to the host.

### Docker Volumes vs Bind Mounts

A Docker-managed volume is controlled by Docker and is portable between containers.

A bind mount maps a specific host directory into a container. It provides direct visibility and control over the stored files.

This project uses named Docker volumes configured with bind options:

```text
/home/eeravci/data/mariadb
/home/eeravci/data/wordpress
```

This makes the database and WordPress files persistent and easy to inspect on the VM.

## Data Persistence

MariaDB data is stored at:

```text
/home/eeravci/data/mariadb
```

WordPress files are stored at:

```text
/home/eeravci/data/wordpress
```

Removing containers does not remove this data:

```bash
make down
make up
```

After restarting, the WordPress installation, users, posts, and database contents remain available.

## Validation Commands

Check the NGINX configuration:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec nginx nginx -t
```

Check PHP-FPM:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress php-fpm8.2 -t
```

Check MariaDB:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec mariadb \
mariadb-admin ping -uroot -p
```

Check HTTPS:

```bash
curl -k -I --resolve yourlogin.42.fr:443:127.0.0.1 \
https://yourlogin.42.fr
```

Check WordPress installation:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml exec wordpress \
wp core is-installed --path=/var/www/html --allow-root
```

## Resources

* [Docker Documentation](https://docs.docker.com/)
* [Docker Compose Documentation](https://docs.docker.com/compose/)
* [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
* [NGINX Documentation](https://nginx.org/en/docs/)
* [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
* [WordPress Developer Resources](https://developer.wordpress.org/)
* [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
* [OpenSSL Documentation](https://docs.openssl.org/)
* [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php)

## AI Usage

AI assistance was used as a learning and development aid during this project.

It helped with:

* Understanding Docker images, containers, networks, volumes, and Compose
* Designing the project structure
* Explaining Dockerfile and shell-script instructions
* Debugging NGINX TLS and WordPress routing
* Troubleshooting PHP-FPM and WP-CLI configuration
* Designing the MariaDB initialization script
* Explaining database users, privileges, and SQL commands
* Reviewing shell syntax and Docker Compose configuration
* Creating test procedures and troubleshooting commands
* Reviewing documentation requirements

All commands and configuration were tested and adapted manually in the Debian virtual machine. The final implementation and validation were performed by the project author.

