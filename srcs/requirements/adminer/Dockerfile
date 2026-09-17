FROM debian:12-slim

RUN apt-get update && apt-get install -y \
    php8.2-cli \
    php8.2-mysql \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/adminer \
    && curl -fsSL https://www.adminer.org/latest.php \
       -o /var/www/adminer/index.php

WORKDIR /var/www/adminer

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/adminer"]
