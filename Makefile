
.DEFAULT_GOAL := all

COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

.PHONY: all prepare up stop down restart logs ps clean

all: up

prepare:
	@set -eu; \
	if [ ! -f srcs/.env ]; then \
		cp srcs/.env.example srcs/.env; \
		echo "Created srcs/.env from template"; \
	fi; \
	chmod 600 srcs/.env; \
	DATA_ROOT=$$(sed -n 's/^DATA_ROOT=//p' srcs/.env | tail -n 1); \
	if [ -z "$$DATA_ROOT" ]; then \
		echo "Error: DATA_ROOT is missing from srcs/.env" >&2; \
		exit 1; \
	fi; \
	mkdir -p "$$DATA_ROOT/wordpress" "$$DATA_ROOT/mariadb"; \
	echo "Persistent data directories ready"; \
	command -v openssl >/dev/null 2>&1 || { \
		echo "Error: openssl is required" >&2; \
		exit 1; \
	}; \
	mkdir -p secrets; \
	chmod 700 secrets; \
	umask 077; \
	for name in db_password db_root_password wp_admin_password wp_user_password ftp_password; do \
		if [ ! -s "secrets/$$name.txt" ]; then \
			openssl rand -hex 24 > "secrets/$$name.txt"; \
			echo "Generated secret: $$name"; \
		fi; \
		chmod 600 "secrets/$$name.txt"; \
	done; \
	echo "Preparation completed"

up: prepare
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps -a

clean:
	$(COMPOSE) down

