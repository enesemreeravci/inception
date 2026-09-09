COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

.PHONY: all up stop down logs
