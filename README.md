*This project has been created as part of the 42 curriculum by eeravci*

# Inception

## Description

Inception is a 42 system-administration project that builds a small WordPress infrastructure using Docker Compose.

The stack contains four independent services:

* NGINX
* WordPress
* MariaDB
* Adminer

NGINX is the public HTTPS entry point. WordPress runs with PHP-FPM and stores its data in MariaDB. Adminer provides a local browser interface for inspecting the MariaDB database.

Each service has its own Dockerfile and runs in its own container. The services communicate through a private Docker bridge network, while WordPress and MariaDB data are stored persistently on the host.

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
        ├── adminer
        ├── mariadb
        ├── nginx
        └── wordpress
```

## Services

| Service   | Purpose                            | Access                  |
| --------- | ---------------------------------- | ----------------------- |
| NGINX     | HTTPS web server and reverse proxy | `https://eeravci.42.fr` |
| WordPress | Website and PHP-FPM application    | Internal port `9000`    |
| MariaDB   | WordPress database                 | Internal port `3306`    |
| Adminer   | Database administration interface  | `http://127.0.0.1:8080` |

## Instructions

### Prerequisites

Install Docker, Docker Compose, Git, and a Linux environment or VM.

```bash
docker --version
docker compose version
```

### Configuration

Create the private environment file:

```bash
cp srcs/.env.example srcs/.env
```

Edit `srcs/.env` and configure the domain, database credentials, and WordPress credentials.

Never commit `.env` to Git.

### Start the project

```bash
make up
```

Equivalent command:

```bash
docker compose --env-file srcs/.env \
-f srcs/docker-compose.yml up -d --build
```

### Stop the project

```bash
make stop
```

Remove containers and the network while preserving data:

```bash
make down
```

Do not use `docker compose down -v` unless you intentionally want to delete the volumes.

### Website access

```text
https://eeravci.42.fr
```

Administration panel:

```text
https://eeravci.42.fr/wp-admin
```

Adminer:

```text
http://127.0.0.1:8080
```

Adminer connection values:

```text
System:   MariaDB
Server:   mariadb
Database: wordpress
Username: root or MYSQL_USER
Password: matching value from srcs/.env
```

Adminer uses HTTP, not HTTPS.

## Data Persistence

MariaDB data:

```text
/home/eeravci/data/mariadb
```

WordPress files:

```text
/home/eeravci/data/wordpress
```

These directories are mounted through Docker volumes and survive container recreation.

## Technical Comparisons

### Virtual Machines vs Docker

A virtual machine contains a complete guest operating system and kernel. It provides strong isolation but uses more resources.

Docker containers share the host kernel and isolate applications and dependencies. They are lighter, faster, and easier to reproduce.

This project uses Docker because each service can be built and managed independently.

### Secrets vs Environment Variables

Environment variables are simple and suitable for development, but values may be visible through Compose configuration or container inspection.

Secrets are designed for sensitive data and are normally mounted as files inside containers.

This project uses an ignored `.env` file for educational development. Real credentials must never be committed.

### Docker Network vs Host Network

A Docker bridge network isolates containers and allows service-name communication such as `mariadb:3306`.

Host networking removes that isolation and uses the host network directly.

This project uses a private bridge network. Only NGINX publishes a public HTTPS port.

### Docker Volumes vs Bind Mounts

Docker volumes are managed by Docker. Bind mounts map explicit host directories into containers.

This project uses named volumes backed by:

```text
/home/eeravci/data/mariadb
/home/eeravci/data/wordpress
```

This provides persistent and inspectable project data.

## Resources

* [Docker Documentation](https://docs.docker.com/)
* [Docker Compose Documentation](https://docs.docker.com/compose/)
* [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
* [NGINX Documentation](https://nginx.org/en/docs/)
* [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
* [WordPress Developer Resources](https://developer.wordpress.org/)
* [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
* [Adminer](https://www.adminer.org/)
* [OpenSSL Documentation](https://docs.openssl.org/)

## AI Usage

AI was used as a learning and development aid for:

* Understanding Docker concepts and Compose
* Designing the service architecture
* Explaining Dockerfiles and shell scripts
* Debugging NGINX, TLS, PHP-FPM, WordPress, and MariaDB
* Designing database initialization
* Reviewing shell syntax and Compose configuration
* Creating testing procedures
* Preparing project documentation
* Explaining the optional Adminer bonus service

All commands and configuration were tested manually in the Debian VM.

