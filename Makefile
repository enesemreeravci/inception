
.DEFAULT_GOAL := all

COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
DATA_ROOT = /home/eeravci/data
SECRETS = db_password db_root_password wp_admin_password wp_user_password ftp_password

.PHONY: all prepare up build down start stop restart ps logs clean fclean re

all: up

prepare:
	@if [ ! -f srcs/.env ]; then \
		cp srcs/.env.example srcs/.env; \
		echo "Created .env file"; \
	fi
	@chmod 600 srcs/.env
	@mkdir -p $(DATA_ROOT)/mariadb $(DATA_ROOT)/wordpress
	@mkdir -p secrets
	@chmod 700 secrets
	@set -e; umask 077; \
	for name in $(SECRETS); do \
		if [ ! -s secrets/$$name.txt ]; then \
			openssl rand -hex 24 > secrets/$$name.txt; \
			echo "Created $$name secret"; \
		fi; \
	done
	@echo "Preparation completed."

build: prepare
	$(COMPOSE) build

up: prepare
	$(COMPOSE) up -d --build
	@echo "Inception started."

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps -a

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v --rmi all --remove-orphans
	@echo "Docker containers, project volumes and images removed."
	@echo "Host data and secrets have NOT been deleted."

re: fclean all

