# Inception — User Documentation

## What the stack provides

The main website is WordPress, served by NGINX over HTTPS and backed by MariaDB. Redis provides optional object caching. The bonus stack also includes FTP access to WordPress files, Adminer for database inspection, a static portfolio, and a Python service-connectivity monitor.

## Starting from a fresh checkout

Use the `eeravci` Linux VM with Docker, Docker Compose, Make, and OpenSSL installed. In the repository root run:

```bash
make
```

`make` creates `srcs/.env` from `srcs/.env.example` if it does not exist, generates **missing** secret passwords under `secrets/`, creates `/home/eeravci/data/mariadb` and `/home/eeravci/data/wordpress`, builds images, and starts services. It will not replace a nonempty secret. Review `.env` for the correct VM domain and data root before first launch; the website hostname must resolve to the VM.

Check services:

```bash
make ps
```

To stop without deleting data, run `make stop`. To start those containers again, run `make start`. To remove the containers and project network but retain the site data, run `make down`; then `make` to recreate them.

## Website and administration

- Website: `https://eeravci.42.fr/`
- Administration: `https://eeravci.42.fr/wp-admin/`
- Administrator username: `siteowner` (from `WP_ADMIN_USER` in `srcs/.env`)
- Second user: `author` (from `WP_USER` in `srcs/.env`)

Find the administrator password in the **local** file `secrets/wp_admin_password.txt`, and the author password in `secrets/wp_user_password.txt`. Keep these confidential. A browser warning is expected because the site uses a self-signed TLS certificate.

To verify editing, log in as `siteowner`, open **Pages**, update a page and view it on the website. To test comments, use a post with comments enabled and submit a comment as an authorized user. WordPress user permissions depend on the assigned role and comment settings.

## Bonus service access

| Service | Where | Credentials / notes |
|---|---|---|
| Adminer | `http://127.0.0.1:8080/` on VM | MySQL server `mariadb`; user `wp_user`; password in `secrets/db_password.txt`; database `wordpress` |
| FTP | `127.0.0.1:21` on VM | User `ftpuser`; password in `secrets/ftp_password.txt`; passive ports `21100-21110` |
| Static portfolio | `https://eeravci.42.fr/portfolio/` | Proxied via main NGINX |
| Monitor JSON | `https://eeravci.42.fr/health` | Reports TCP reachability of services |
| Monitor dashboard | `https://eeravci.42.fr/monitor` | Refreshing status page |

The optional bonus services still need their own functional tests, especially FTP upload/download and Adminer login. FTP is not encrypted by this configuration; use it only in the trusted VM testing environment. FTP write permissions are prepared for the WordPress uploads directory, not indiscriminately for every WordPress file.

## Where credentials are managed

The file `srcs/.env` stores nonsecret configuration: the domain, usernames, database name, FTP passive address, and storage path. **Passwords are not in `.env`.** The Makefile generates local password files in `secrets/`, which Docker Compose mounts inside the relevant containers at `/run/secrets/`.

The secret directory and `.env` are excluded from Git. Protect the files and do not paste the passwords into chats or screenshots. If you delete secrets while retaining an initialized database, new passwords may no longer work against that database.

## Checking service health

```bash
make ps
make logs
curl -kI --resolve eeravci.42.fr:443:127.0.0.1 https://eeravci.42.fr/
curl -k --resolve eeravci.42.fr:443:127.0.0.1 https://eeravci.42.fr/health
```

`make logs` follows logs until interrupted with Ctrl+C. A TCP service being `up` does not prove its complete application functionality.

## Data persistence and restarts

WordPress website files: `/home/eeravci/data/wordpress` (container `/var/www/html`). MariaDB files: `/home/eeravci/data/mariadb` (container `/var/lib/mysql`). These are backing directories for Compose named volumes.

To test persistence, edit a page or create a post, run `make down` and `make`, and confirm the change remains. The evaluation also requires rebooting the VM and checking that the change remains after startup. **Do not delete the host data directories if you want to preserve the site.** Removing Docker volume objects does not necessarily erase these directories.

## Common problems

**Website unavailable:** Verify `make ps`, check NGINX/WordPress/MariaDB logs, and test domain resolution with `getent hosts eeravci.42.fr`. A VM-local `/etc/hosts` entry such as `127.0.0.1 eeravci.42.fr` may be used where appropriate.

**WordPress installation page:** Check the WordPress and MariaDB logs and their volumes. The first run should automatically install WordPress through WP-CLI.

**Cannot log in:** Use the WordPress password file, not the database password. Confirm the username is `siteowner` or `author` as appropriate.

**Adminer login fails:** In the *Server* field use `mariadb`, not `127.0.0.1`; use the DB username and `secrets/db_password.txt`.

**FTP problems:** Connect from within the VM unless port publishing and passive address are deliberately reconfigured. Check `docker compose ... logs ftp` and the files' permissions.

For detailed build, volume, troubleshooting, and evaluation commands, see `DEV_DOC.md`.
