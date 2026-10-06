*This project has been created as part of the 42 curriculum by eeravci.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum.

The goal of the project is to build a small infrastructure composed of multiple services running inside Docker containers and managed with Docker Compose.

The mandatory infrastructure contains:

- NGINX with TLS
- WordPress with PHP-FPM
- MariaDB
- Persistent WordPress and MariaDB volumes
- A custom Docker bridge network

This implementation also includes the following bonus services:

- Redis object cache
- FTP server
- Adminer
- Static portfolio website
- Custom monitoring service

Each service has its own Dockerfile and runs inside its own container.

The containers communicate through a private Docker bridge network using Docker DNS and service names.

### Main Architecture

```text
Browser
   |
   | HTTPS :443
   v
 NGINX
   |
   | FastCGI :9000
   v
WordPress / PHP-FPM
   |
   | MySQL :3306
   v
MariaDB
```

Additional services such as Redis, FTP, Adminer, the static website, and the monitoring service communicate through the same Docker network.

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

The real `srcs/.env` file is excluded from Git.

---

## Services

| Service | Purpose | Access |
|---|---|---|
| NGINX | HTTPS entry point and reverse proxy | `https://eeravci.42.fr` |
| WordPress | Website running with PHP-FPM | Internal port `9000` |
| MariaDB | WordPress database | Internal port `3306` |
| Redis | WordPress object cache | Internal port `6379` |
| FTP | Access to WordPress files | `127.0.0.1:21` |
| Adminer | MariaDB administration interface | `http://127.0.0.1:8080` |
| Static Site | Static portfolio website | `https://eeravci.42.fr/portfolio/` |
| Monitor | Infrastructure health monitoring | `https://eeravci.42.fr/health` |

---

## NGINX

NGINX is the public entry point of the infrastructure.

It:

- listens on port `443`
- uses TLS 1.2 and TLS 1.3
- serves the WordPress website
- forwards PHP requests to WordPress/PHP-FPM
- proxies the static portfolio website
- proxies the monitoring health endpoint

HTTP port `80` is not exposed on the host.

Main website:

```text
https://eeravci.42.fr
```

Portfolio:

```text
https://eeravci.42.fr/portfolio/
```

Health endpoint:

```text
https://eeravci.42.fr/health
```

---

## WordPress

WordPress runs in its own container with PHP-FPM.

NGINX is not installed inside the WordPress container.

PHP-FPM listens internally on:

```text
9000
```

WordPress connects to MariaDB through:

```text
mariadb:3306
```

WordPress connects to Redis through:

```text
redis:6379
```

WordPress files are stored persistently in:

```text
/var/www/html
```

---

## MariaDB

MariaDB stores the WordPress database.

It listens internally on:

```text
3306
```

On the first startup, the MariaDB initialization script:

1. initializes the MariaDB data directory
2. creates the WordPress database
3. creates the database user
4. grants the required privileges
5. starts MariaDB as the main foreground process

MariaDB data is stored persistently in:

```text
/var/lib/mysql
```

---

## Redis

Redis is used as an object cache for WordPress.

It stores frequently accessed data in memory and reduces unnecessary repeated database queries.

Redis listens internally on:

```text
6379
```

WordPress connects using the Docker service name:

```text
redis
```

---

## FTP

The FTP service uses `vsftpd`.

Anonymous login is disabled.

The FTP container shares the WordPress volume so that the authenticated FTP user can access and modify the same files used by WordPress.

FTP is available locally through:

```text
127.0.0.1:21
```

Passive FTP ports are also configured for file transfers.

---

## Adminer

Adminer provides a browser-based interface for MariaDB.

It connects to the MariaDB container through the Docker network using:

```text
mariadb
```

Adminer is available locally at:

```text
http://127.0.0.1:8080
```

---

## Static Portfolio

The portfolio website runs inside a separate NGINX container.

The static-site container listens on port `80` only inside the Docker network.

It is not directly published on the host.

The main NGINX service proxies:

```text
https://eeravci.42.fr/portfolio/
```

to:

```text
static-site:80
```

---

## Monitor

The monitor is a custom Python HTTP service.

It checks TCP connectivity to the other services using their Docker service names and expected ports.

It monitors:

```text
MariaDB      3306
Redis        6379
WordPress    9000
Adminer      8080
FTP          21
Static Site  80
NGINX        443
```

The monitor listens internally on:

```text
9090
```

The health endpoint returns a JSON report.

Example:

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

The public endpoint is:

```text
https://eeravci.42.fr/health
```

---

## Instructions

### Prerequisites

The project requires:

- Docker
- Docker Compose
- Make
- Git
- Linux or a Linux virtual machine

Verify Docker:

```bash
docker --version
docker compose version
```

---

### Environment Configuration

Create the private environment file:

```bash
cp srcs/.env.example srcs/.env
```

Then edit:

```text
srcs/.env
```

and configure the required values.

The real `.env` file must not be committed to Git.

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

### Start the Project

From the repository root:

```bash
make
```

or:

```bash
make up
```

Equivalent Docker Compose command:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    up -d --build
```

---

### Check Running Services

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

---

### Stop the Project

```bash
make stop
```

---

### Remove Containers and Network

```bash
make down
```

Persistent data remains unless the Docker volumes or host data directories are intentionally removed.

---

## Website Access

WordPress:

```text
https://eeravci.42.fr
```

WordPress administration:

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

FTP:

```text
127.0.0.1:21
```

---

## Data Persistence

Two mandatory persistent data locations are used.

### WordPress

Host path:

```text
/home/eeravci/data/wordpress
```

Container path:

```text
/var/www/html
```

### MariaDB

Host path:

```text
/home/eeravci/data/mariadb
```

Container path:

```text
/var/lib/mysql
```

The Docker volumes are backed by host directories.

This allows WordPress and MariaDB data to survive container recreation and virtual machine reboots.

---

## Technical Comparisons

### Virtual Machines vs Docker

A virtual machine runs a complete guest operating system and its own kernel through a hypervisor.

Docker containers share the host kernel while isolating applications and dependencies.

Containers are generally lighter, require fewer resources, and start faster than complete virtual machines.

---

### Docker Image vs Docker Container

A Docker image is the blueprint used to create containers.

A container is a running instance of an image.

```text
Dockerfile
    |
    v
Image
    |
    v
Container
```

---

### Docker vs Docker Compose

Docker manages images and containers.

Docker Compose manages multiple related containers using one YAML configuration file.

Docker Compose defines:

- services
- images
- networks
- volumes
- ports
- environment variables
- dependencies

---

### Secrets vs Environment Variables

Environment variables are used to configure containers at runtime.

Sensitive values are stored inside:

```text
srcs/.env
```

The real `.env` file is ignored by Git and must not be committed.

The repository contains `.env.example` as a template.

---

### Docker Network vs Host Network

A custom Docker bridge network allows isolated containers to communicate with each other.

Docker provides internal DNS, allowing services to communicate using names such as:

```text
mariadb:3306
redis:6379
wordpress:9000
static-site:80
monitor:9090
```

Container IP addresses do not need to be hardcoded.

Host networking is not used.

---

### Docker Volumes vs Bind Mounts

Docker volumes provide persistent storage.

Bind mounts map specific host directories into containers.

This project declares Docker volumes backed by:

```text
/home/eeravci/data/mariadb
/home/eeravci/data/wordpress
```

This keeps the important data persistent and accessible on the host.

---

## Useful Commands

List containers:

```bash
docker ps
```

List images:

```bash
docker images
```

List volumes:

```bash
docker volume ls
```

Inspect the WordPress volume:

```bash
docker volume inspect srcs_wordpress_data
```

Inspect the MariaDB volume:

```bash
docker volume inspect srcs_mariadb_data
```

List Docker networks:

```bash
docker network ls
```

Inspect the project network:

```bash
docker network inspect srcs_inception
```

View container logs:

```bash
docker logs <container-name>
```

Example:

```bash
docker logs srcs-mariadb-1
```

---

## Testing

### HTTPS

```bash
curl -kI https://eeravci.42.fr
```

Expected:

```text
HTTP/1.1 200 OK
```

HTTP on port 80 should fail:

```bash
curl -I http://eeravci.42.fr
```

---

### TLS 1.2

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_2
```

### TLS 1.3

```bash
openssl s_client \
    -connect eeravci.42.fr:443 \
    -tls1_3
```

---

### Redis

```bash
docker exec srcs-redis-1 redis-cli ping
```

Expected:

```text
PONG
```

Check WordPress Redis integration:

```bash
docker exec srcs-wordpress-1 \
    wp redis status \
    --allow-root \
    --path=/var/www/html
```

---

### WordPress

List users:

```bash
docker exec srcs-wordpress-1 \
    wp user list \
    --allow-root \
    --path=/var/www/html
```

List pages:

```bash
docker exec srcs-wordpress-1 \
    wp post list \
    --post_type=page \
    --allow-root \
    --path=/var/www/html
```

---

### FTP

Connect:

```bash
ftp 127.0.0.1
```

Enter the configured FTP username and password.

Useful commands:

```text
pwd
ls
get
put
quit
```

---

### Adminer

Open:

```text
http://127.0.0.1:8080
```

Connection values:

```text
System:   MySQL
Server:   mariadb
Username: MYSQL_USER
Password: MYSQL_PASSWORD
Database: MYSQL_DATABASE
```

---

### Static Portfolio

Open:

```text
https://eeravci.42.fr/portfolio/
```

---

### Monitor

Test the public health endpoint:

```bash
curl -k https://eeravci.42.fr/health
```

Expected result:

```json
{
  "status": "healthy"
}
```

---

## Persistence Test

Edit something in WordPress.

Then reboot the virtual machine:

```bash
sudo reboot
```

After reboot:

```bash
cd ~/inception
make
```

Check the containers:

```bash
docker compose \
    --env-file srcs/.env \
    -f srcs/docker-compose.yml \
    ps
```

The WordPress content and MariaDB database should still exist because they are stored in persistent volumes.

---

## Resources

The following resources were used while studying and implementing the project:

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [WordPress Developer Resources](https://developer.wordpress.org/)
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [Redis Documentation](https://redis.io/docs/)
- [vsftpd](https://security.appspot.com/vsftpd.html)
- [Adminer](https://www.adminer.org/)
- [OpenSSL Documentation](https://docs.openssl.org/)
- [Python Documentation](https://docs.python.org/3/)

---

## AI Usage

AI tools were used as a learning, debugging, and review aid during development.

AI assistance was used for:

- understanding Docker and Docker Compose concepts
- reviewing Docker networking and volume behavior
- explaining Dockerfiles and shell scripts
- troubleshooting NGINX and TLS
- troubleshooting WordPress and PHP-FPM
- debugging MariaDB initialization
- reviewing Redis integration
- testing FTP and Adminer
- designing and reviewing the monitoring service
- preparing evaluation tests
- reviewing project documentation

All commands, configurations, services, and persistence behavior were manually tested inside the Debian virtual machine.

---

