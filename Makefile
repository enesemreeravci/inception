
COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
DATA_ROOT ?= $(HOME)/data

all: up

prepare:
	@mkdir -p "$(DATA_ROOT)/wordpress" "$(DATA_ROOT)/mariadb"
	@if [ ! -f srcs/.env ]; then \
		cp srcs/.env.example srcs/.env; \
		echo "Created srcs/.env. Review it before running make."; \
		exit 1; \
	fi
	@mkdir -p secrets
	@chmod 700 secrets
	@for name in db_password db_root_password wp_admin_password wp_user_password ftp_password; do \
		if [ ! -s "secrets/$$name.txt" ]; then \
			openssl rand -hex 24 > "secrets/$$name.txt" || exit 1; \
			echo "Generated $$name"; \
		fi; \
		chmod 600 "secrets/$$name.txt"; \
	done

up: prepare
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

.PHONY: all prepare up stop down logs
