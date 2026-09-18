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
: "${WORDPRESS_DOMAIN:?WORDPRESS_DOMAIN must be set}"

mkdir -p /run/php

if [ ! -f /var/www/html/wp-includes/version.php ]; then
	echo "Wordpress files are missing; downloading WordPress"

	curl -fsSL https://wordpress.org/wordpress-6.8.2.tar.gz \
		| tar -xz --strip-components=1 -C /var/www/html


	chown -R www-data:www-data /var/www/html
fi

until mariadb-admin ping -h mariadb --silent; do
	sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
	wp config create \
		--path=/var/www/html \
		--dbname="$WORDPRESS_DB_NAME" \
		--dbuser="$WORDPRESS_DB_USER" \
		--dbpass="$WORDPRESS_DB_PASSWORD" \
		--dbhost="$WORDPRESS_DB_HOST" \
		--skip-check \
		--allow-root
fi

if ! wp core is-installed --path=/var/www/html --allow-root; then
	wp core install \
		--path=/var/www/html \
		--url="https://${WORDPRESS_DOMAIN}" \
		--title="$WORDPRESS_TITLE" \
		--admin_user="$WORDPRESS_ADMIN_USER" \
		--admin_password="$WORDPRESS_ADMIN_PASSWORD" \
		--admin_email="$WORDPRESS_ADMIN_EMAIL" \
		--skip-email \
		--allow-root

	wp user create \
		"$WORDPRESS_USER" \
		"$WORDPRESS_USER_EMAIL" \
		--user_pass="$WORDPRESS_USER_PASSWORD" \
		--role=author \
		--path=/var/www/html \
		--allow-root
fi

if ! wp plugin is-installed redis-cache \
	--path=/var/www/html \
	--allow-root
then
	wp plugin install redis-cache \
		--activate \
		--path=/var/www/html \
		--allow-root
elif ! wp plugin is-active redis-cache \
	--path=/var/www/html \
	--allow-root
then
	wp plugin activate redis-cache \
		--path=/var/www/html \
		--allow-root
fi

if ! wp config get WP_REDIS_HOST \
	--path=/var/www/html \
	--allow-root >/dev/null 2>&1
then
	wp config set WP_REDIS_HOST redis \
		--type=constant \
		--path=/var/www/html \
		--allow-root
fi

if ! wp config get WP_REDIS_PORT \
	--path=/var/www/html \
	--allow-root >/dev/null 2>&1
then
	wp config set WP_REDIS_PORT 6379 \
		--raw \
		--type=constant \
		--path=/var/www/html \
		--allow-root
fi

wp redis enable \
	--path=/var/www/html \
	--allow-root

exec php-fpm8.2 -F
