#!/bin/sh

set -eu

: "${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST must be set}"
: "${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME must be set}"
: "${WORDPRESS_DB_USER:?WORDPRESS_DB_USER must be set}"
: "${WORDPRESS_DB_PASSWORD:?WORDPRESS_DB_PASSWORD must be set}"
: "${WORDPRESS_TITLE:?WORDPRESS_TITLE must be set}"
: "${WORDPRESS_ADMIN_USER:?WORDPRESS_ADMIN_USER must be set}"
: "${WORDPRESS_ADMIN_PASSWORD:?WORDPRESS_ADMIN_PASSWORD must be set}"
: "${WORDPRESS_ADMIN_EMAIL:?WORDPRESS_ADMIN_EMAIL must be set}"
: "${WORDPRESS_USER:?WORDPRESS_USER must be set}"
: "${WORDPRESS_USER_PASSWORD:?WORDPRESS_USER_PASSWORD must be set}"
: "${WORDPRESS_USER_EMAIL:?WORDPRESS_USER_EMAIL must be set}"

mkdir -p /run/php

if [ ! -f /var/www/html/wp-includes/version.php ]; then
	echo "Wordpress files are missing; downloading WordPress"

	curl -fsSL https://wordpress.org/wordpress-6.8.2.tar.gz \
		| tar -xz --strip-components=1 -C /var/www/html


	chown -R www-data:www-data /var/www/html
fi

exec php-fpm8.2 -F
