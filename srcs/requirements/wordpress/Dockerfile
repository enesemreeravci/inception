FROM debian:12-slim

RUN apt-get update && apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-cli \
    php8.2-curl \
    php8.2-gd \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    curl \
    ca-certificates \
    mariadb-client

RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' \
	/etc/php/8.2/fpm/pool.d/www.conf

RUN curl -fsSL \
    https://github.com/wp-cli/wp-cli/releases/download/v2.11.0/wp-cli-2.11.0.phar \
    -o /usr/local/bin/wp-cli.phar \
    && chmod +x /usr/local/bin/wp-cli.phar \
    && printf '#!/bin/sh\nexec php /usr/local/bin/wp-cli.phar "$@"\n' \
       > /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

COPY tools/start-wordpress.sh /usr/local/bin/start-wordpress.sh

RUN chmod +x /usr/local/bin/start-wordpress.sh

EXPOSE 9000

CMD ["/usr/local/bin/start-wordpress.sh"]
