COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
DATA_ROOT ?= /home/eeravci/data

all: up

prepare:
	@mkdir -p "$(DATA_ROOT)/wordpress" "$(DATA_ROOT)/mariadb"
	if [ ! -f srcs/.env]; then \
		cp srcs/.env.example srcs/.env; \
		echo "Created srcs/.env Edit it with your credentials, then run make again."; \
		exit 1; 
	fi

up: prepare
	$($COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

.PHONY: all prepare up stop down logs
