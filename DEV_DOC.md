# Inception — Developer Documentation

## Architecture and source layout

This project builds eight images with local Dockerfiles and runs them as separate containers: mandatory NGINX, WordPress/PHP-FPM, MariaDB; bonus Redis, FTP, Adminer, static-site, and monitor. Compose connects them over the `inception` user-defined bridge network. Docker DNS resolves service names such as `mariadb:3306`, `wordpress:9000`, `redis:6379`, `static-site:80`, and `monitor:9090`.

```text
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/                 # Local, Git-ignored
└── srcs/
    ├── .env                 # Local, Git-ignored
    ├── .env.example
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/Dockerfile, conf/, tools/
        ├── nginx/Dockerfile, conf/, tools/
        ├── wordpress/Dockerfile, conf/, tools/
        ├── tools/
        └── bonus/
            ├── adminer/Dockerfile
            ├── ftp/Dockerfile, conf/, tools/
            ├── monitor/Dockerfile, tools/
            ├── redis/Dockerfile
            └── static-site/Dockerfile, index.html
```

## Prerequisites and first-time setup

Use the Linux virtual machine with Docker Engine, Docker Compose plugin, Make, Git, and OpenSSL. The current Makefile uses `/home/eeravci/data`. Verify `srcs/.env.example` is tracked and includes valid local values (`DOMAIN_NAME`, `DATA_ROOT`, database, WordPress, and FTP user settings).

From a fresh Git checkout:

```bash
make prepare
make
```

`make prepare` creates `.env` from `.env.example` if missing, protects it with mode 600, creates host data directories, creates `secrets/` with mode 700, generates missing password files using `openssl rand -hex 24`, and sets password files to mode 600. Existing nonempty secret files are retained. `make` also runs `prepare` automatically, then `docker compose up -d --build`.

The expected secrets are `db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`, `wp_user_password.txt`, and `ftp_password.txt`, all under root-level `secrets/`. The `srcs/.env` file contains **nonsecret settings only**. Compose resolves `${...}` values through `--env-file` and mounts secrets from `../secrets/*.txt` at `/run/secrets/`.

Security checks (do not print passwords):

```bash
git ls-files srcs/.env secrets/
ls -ld secrets
ls -l secrets
```

The `git ls-files` command should return no tracked secret paths. Inspect `.gitignore` as well.

## Build and lifecycle commands

```bash
make               # prepare, build, and start
make prepare       # configuration, data directories, missing secrets
make build         # build images
make up            # prepare, build, and start
make ps            # all Compose container states
make logs          # follow logs; Ctrl+C to stop
make stop          # stop existing containers
make start         # start stopped containers
make restart       # restart existing containers
make down          # remove project containers and network; retain data
make clean         # same as down
make fclean        # Compose down -v --rmi all --remove-orphans
make re            # fclean then all; host data is retained
```

Equivalent Compose invocation:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps -a
```

Compose normally prefixes resource names using the Compose project name inferred from `srcs` (for example `srcs_mariadb_data`, `srcs_wordpress_data`, `srcs_inception`). Service commands avoid depending on exact generated container names:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=50 mariadb wordpress
```

## Service implementation

**MariaDB:** `srcs/requirements/mariadb/tools/start-mariadb.sh` validates identifiers, reads two secret files, initializes system tables on empty storage, starts a temporary server with networking disabled, creates the WordPress database and user, and finally `exec`s `mariadbd --user=mysql`. It uses an initialization marker to avoid repeating SQL setup. The password validation expects hexadecimal credentials, matching the Makefile.

**WordPress:** `srcs/requirements/wordpress/tools/start-wordpress.sh` reads its three password secrets, downloads WordPress when files are absent, waits for authenticated MariaDB connectivity, generates `wp-config.php`, installs WordPress if not already installed, and ensures the extra author user exists. It attempts Redis setup as a bonus; failure is logged without preventing PHP-FPM from starting. The final process is `exec php-fpm8.2 -F` on port 9000. The initial download requires network connectivity.

**NGINX:** `srcs/requirements/nginx/tools/start-nginx.sh` generates a self-signed certificate if needed, expands `DOMAIN_NAME` in the NGINX template, validates its configuration, then runs `exec nginx -g 'daemon off;'`. Only TLS 1.2/1.3 is configured, and NGINX publishes port 443. PHP requests go to `wordpress:9000`; `/portfolio/` and `/health` are proxied to bonus services.

**Redis:** Debian Redis server listens on internal port 6379. WordPress uses the Redis Object Cache plugin. Actual plugin/cache state must be checked, not inferred from container status alone.

**FTP:** `srcs/requirements/bonus/ftp/` contains its Dockerfile, `conf/vsftpd.conf`, and `tools/start-ftp.sh`. The script reads the FTP password secret, creates the FTP user, adjusts uploads-directory group permissions, expands `FTP_PASV_ADDRESS`, and executes vsftpd. Its WordPress named volume is shared at `/var/www/html`; its locally published FTP port is 21, with passive ports 21100–21110.

**Adminer:** Runs PHP's built-in server on container port 8080; host access is `127.0.0.1:8080`. Connect to database server `mariadb` using the database account/password.

**Static site:** Serves `srcs/requirements/bonus/static-site/index.html` through an internal NGINX on port 80, proxied at `/portfolio/` on the main domain.

**Monitor:** `srcs/requirements/bonus/monitor/tools/monitor.py` serves a dashboard and `/health` JSON on port 9090. It checks TCP connectivity, not complete application health. The main NGINX proxies `/health` and `/monitor` to this service.

## Network and storage

Only the mandatory HTTPS entry point is publicly published (`443:443`). FTP and Adminer use localhost-only host mappings; MariaDB, WordPress/PHP-FPM, Redis, static-site, and monitor are internal to the Docker network.

Docker Compose declares **named volumes**, not direct service-level host-directory mounts:

| Volume | Host-backed location | Container |
|---|---|---|
| `srcs_mariadb_data` | `/home/eeravci/data/mariadb` | `/var/lib/mysql` |
| `srcs_wordpress_data` | `/home/eeravci/data/wordpress` | `/var/www/html` |

The local driver options use `type: none`, `o: bind`, and `device: ${DATA_ROOT}/...`. The named volume object is Docker-managed; the underlying host files are separate. Inspect with:

```bash
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
docker network ls
docker network inspect srcs_inception
```

**Critical distinction:** Deleting containers or Docker volume objects does **not** necessarily delete `/home/eeravci/data`. `make down` deliberately preserves persistent data. `make fclean` removes Compose volumes and service images but **does not wipe host-backed files**. To simulate a truly fresh website, remove the host files too only after stopping services and confirming the directories are exclusively used by this project.

## Persistence, reset, and evaluation preparation

**Nondestructive persistence test:** Edit a WordPress page or create a post; run `make down` then `make`; verify the change remains. The evaluation sheet also requires a **VM reboot** and checking that the edit and database survive afterward.

**Destructive fresh-install test (erases the WordPress site and database):** From the correct project checkout, stop/remove Compose containers and named volumes, then deliberately remove only the project's two host-data directories. The Makefile will recreate them and, on `make`, MariaDB/WordPress will initialize with the retained secrets. If the secrets were also removed, `make` creates new passwords; do not do this while keeping an old initialized database.

```bash
# DESTRUCTIVE — only when intentional and after checking exact paths!
docker compose --env-file srcs/.env -f srcs/docker-compose.yml down -v --remove-orphans
sudo rm -rf -- /home/eeravci/data/mariadb /home/eeravci/data/wordpress
make
```

The evaluator's published Docker cleanup removes containers, images, volumes, and networks, but may leave these backing directories. A fresh clone also needs a valid `.env.example`, so test cloning into an empty directory separately. Do not erase shared resources or blindly remove all host data when unrelated projects use the VM.

## Functional tests

```bash
# Containers and network
make ps
docker network ls

# HTTPS website with correct hostname even without DNS configuration
curl -kI --resolve eeravci.42.fr:443:127.0.0.1 https://eeravci.42.fr/

# WordPress installed and accounts created
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T wordpress wp core is-installed --allow-root
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T wordpress wp user list --fields=ID,user_login,roles --allow-root

# Redis server and WordPress integration
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T redis redis-cli ping
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T wordpress wp redis status --allow-root

# Monitoring JSON
curl -k --resolve eeravci.42.fr:443:127.0.0.1 https://eeravci.42.fr/health
```

Test WordPress page edits and comments in the browser, Adminer login from inside the VM, FTP upload/download and permission behavior, port 80 refusal, TLS 1.2/1.3, named-volume inspection, and service configuration modification/rebuild separately. These are evaluation checkpoints; container startup alone does not establish that they pass.

## Troubleshooting

If `docker compose config --quiet` reports missing variables, inspect `.env` (without sharing secret values). If a build fails, read the failing service's Dockerfile and error; a failing bonus image can stop the whole `make` build. If MariaDB is restarting, inspect its initialization log and data directory. If WordPress cannot start, inspect its database credentials, network access, and startup log. Use `make ps` and service-specific Compose logs.

Check shell syntax without running scripts:

```bash
sh -n srcs/requirements/mariadb/tools/start-mariadb.sh
sh -n srcs/requirements/wordpress/tools/start-wordpress.sh
sh -n srcs/requirements/nginx/tools/start-nginx.sh
sh -n srcs/requirements/bonus/ftp/tools/start-ftp.sh
```

For defense, be able to explain container PID 1, the temporary MariaDB initialization server, Docker DNS, named-volume/host-data differences, Docker secrets, the lack of direct MariaDB/WordPress host ports, and the rationale for the Python monitoring bonus.
