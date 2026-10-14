*This project has been created as part of the 42 curriculum by eeravci.*

# Inception

## Description

Inception is a system administration project that builds a small Docker-based infrastructure inside a virtual machine. Each service has its own Dockerfile and container; Docker Compose manages the shared bridge network, startup dependencies, named volumes, and secrets.

The mandatory stack consists of **NGINX (TLS 1.2/1.3)**, **WordPress with PHP-FPM**, and **MariaDB**. Bonus services are **Redis object caching**, **vsftpd**, **Adminer**, a **static portfolio**, and a **custom Python TCP-connectivity monitor**.

### Architecture

```text
Browser --HTTPS :443--> NGINX --FastCGI :9000--> WordPress/PHP-FPM
                              |                     |          |
                              |                     |          +--> Redis :6379
                              |                     +--> MariaDB :3306
                              +--> /portfolio/ --> static-site :80
                              +--> /health -----> monitor :9090

Local VM access: Adminer :8080, FTP :21 and passive ports :21100-21110
```

Only NGINX is published as the mandatory public entry point, on host port 443. The optional Adminer and FTP ports are bound to `127.0.0.1`. MariaDB, PHP-FPM, Redis, the static site, and the monitor have no direct host port publishing.

### Repository layout

```text
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/                  # Created locally; ignored by Git
└── srcs/
    ├── .env                  # Created locally; ignored by Git
    ├── .env.example          # Non-secret configuration template
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/{Dockerfile,conf/,tools/}
        ├── nginx/{Dockerfile,conf/,tools/}
        ├── wordpress/{Dockerfile,conf/,tools/}
        ├── tools/
        └── bonus/
            ├── adminer/
            ├── ftp/{Dockerfile,conf/,tools/}
            ├── monitor/{Dockerfile,tools/}
            ├── redis/
            └── static-site/{Dockerfile,index.html}
```

## Instructions

### Prerequisites

Use a Linux virtual machine with Docker Engine, the Docker Compose plugin, GNU Make, Git, and OpenSSL. Docker must be accessible to the current user. The Makefile's data location is `/home/eeravci/data`; this setup therefore assumes the learner account `eeravci`.

### First installation

From the repository root:

```bash
make
```

The `prepare` prerequisite copies `srcs/.env.example` to `srcs/.env` **only if `.env` is missing**, creates `/home/eeravci/data/{mariadb,wordpress}`, and generates five missing password files under `secrets/` using OpenSSL. Existing nonempty secrets are not overwritten. Then Docker Compose builds and starts all eight services.

Before launching, ensure the copied `.env` values match this VM, especially `DOMAIN_NAME=eeravci.42.fr` and `DATA_ROOT=/home/eeravci/data`. For another machine or login, adjust the local configuration and the Makefile's `DATA_ROOT` accordingly. The hostname must resolve to the VM's address (for VM-local tests, a matching `/etc/hosts` entry may be used).

Secrets created by `make prepare`:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
secrets/ftp_password.txt
```

**Passwords are not stored in `.env`**, which contains nonsensitive names, addresses, and settings. Compose mounts the secret files at `/run/secrets/` for the relevant containers. Neither `.env` nor `secrets/` belongs in Git. Keep the files secure and do not reveal passwords in logs or screenshots.

### Commands

| Command | Purpose |
|---|---|
| `make` / `make up` | Prepare missing local files and directories; build and start services |
| `make prepare` | Prepare `.env`, host data directories, and missing secrets |
| `make build` | Build images without starting containers |
| `make start` | Start previously created, stopped containers |
| `make stop` | Stop existing containers without deleting them |
| `make down` / `make clean` | Remove Compose containers/network; preserve persistent data |
| `make restart` | Restart existing containers |
| `make ps` | List all Compose container statuses |
| `make logs` | Follow Compose logs |
| `make fclean` | Remove Compose containers, named volumes, and service images; **does not erase host data** |
| `make re` | `fclean` followed by `make` (not necessarily a fresh database) |

### Access

| Service | Address |
|---|---|
| WordPress | `https://eeravci.42.fr/` |
| WordPress administration | `https://eeravci.42.fr/wp-admin/` |
| Static portfolio | `https://eeravci.42.fr/portfolio/` |
| Monitor JSON | `https://eeravci.42.fr/health` |
| Monitor dashboard | `https://eeravci.42.fr/monitor` |
| Adminer (on VM) | `http://127.0.0.1:8080/` |
| FTP (on VM) | `127.0.0.1:21` with passive ports `21100-21110` |

The certificate is self-signed; a browser warning is expected. The administrator is `siteowner`, with password in `secrets/wp_admin_password.txt`. The second WordPress user is `author`, with password in `secrets/wp_user_password.txt`. These usernames come from `.env`; fresh installation recreates them using the current secrets.

### Persistence and reset behavior

Docker Compose declares two **named volumes**, `srcs_wordpress_data` and `srcs_mariadb_data`. Their local-driver options map them to `/home/eeravci/data/wordpress` and `/home/eeravci/data/mariadb`. Data survives stop/start, container recreation, and VM restart while those files remain intact.

**Important:** The underlying named volumes use local-driver `o: bind` options to reach the required host paths. `docker compose down -v`, `make fclean`, or the evaluation's volume removal commands can remove the volume objects **without erasing the underlying host directories**. A genuinely empty WordPress installation requires deliberately removing the old host data too. This is destructive and should only be done after stopping containers and confirming the target paths.

Missing secrets can be regenerated from scratch, but **do not regenerate passwords for an existing database**: its credentials may no longer match. See `DEV_DOC.md` for the reset procedure and recovery precautions.

## Design choices and comparisons

### Virtual machines vs Docker

A VM runs a guest OS with its own kernel, whereas containers isolate processes while sharing the VM host's kernel. The project runs Docker **inside a VM** as required by the subject.

### Docker image vs container; Docker vs Compose

A Dockerfile defines an image; a container is an instance of that image. Docker Compose defines and coordinates this project's eight containers, bridge network, named volumes, secrets, and port mappings.

### Secrets vs environment variables

Environment variables supply nonsecret settings such as domain, database name, and usernames. Passwords are generated into local `secrets/*.txt` files and mounted as Compose secrets. Unlike process environment variables, secret file contents are read only when needed by entrypoint scripts. Secrets must not be committed to the repository.

### Docker network vs host network

All services use an explicit, user-defined bridge network (`inception`, typically named `srcs_inception` by Compose). Docker DNS resolves names such as `mariadb`, `wordpress`, and `redis`. Host networking and Docker links are not used.

### Docker named volumes vs direct bind mounts

Services reference named volumes, rather than directly specifying absolute host-path mounts. Docker's local volume driver uses host-directory backing to satisfy the subject's required data location. A direct service-level bind mount maps a host path straight into a container without a named volume object.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.com/kb/en/)
- [WordPress developer documentation](https://developer.wordpress.org/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [Redis documentation](https://redis.io/docs/)
- [Adminer](https://www.adminer.org/)
- [OpenSSL documentation](https://docs.openssl.org/)
- [Python documentation](https://docs.python.org/3/)

### AI usage

AI was used as a learning and review assistant for Docker/Compose concepts, Dockerfile and shell-script reviews, diagnosing volume-persistence and initialization problems, and preparing evaluation tests and documentation. Generated suggestions were reviewed and adjusted against the subject, actual source code, and observed VM results. Full bonus functionality, VM-reboot persistence, and the complete evaluation reset still require dedicated verification.
