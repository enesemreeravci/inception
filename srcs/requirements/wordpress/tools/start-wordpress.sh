#!/bin/sh

set -eu

WP_PATH="/var/www/html"

# Validate required environment variables
: "${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST must be set}"
: "${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME must be set}"
: "${WORDPRESS_DB_USER:?WORDPRESS_DB_USER must be set}"
: "${WORDPRESS_TITLE:?WORDPRESS_TITLE must be set}"
: "${WORDPRESS_ADMIN_USER:?WORDPRESS_ADMIN_USER must be set}"
: "${WORDPRESS_ADMIN_EMAIL:?WORDPRESS_ADMIN_EMAIL must be set}"
: "${WORDPRESS_USER:?WORDPRESS_USER must be set}"
: "${WORDPRESS_USER_EMAIL:?WORDPRESS_USER_EMAIL must be set}"
: "${WORDPRESS_DOMAIN:?WORDPRESS_DOMAIN must be set}"

# Read passwords from Docker secrets
WORDPRESS_DB_PASSWORD="$(cat /run/secrets/db_password)"
WORDPRESS_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WORDPRESS_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

# Check that passwords are not empty
[ -n "$WORDPRESS_DB_PASSWORD" ] || exit 1
[ -n "$WORDPRESS_ADMIN_PASSWORD" ] || exit 1
[ -n "$WORDPRESS_USER_PASSWORD" ] || exit 1

# Prepare directories
mkdir -p /run/php "$WP_PATH"

# Download WordPress only when files are missing
if [ ! -f "$WP_PATH/wp-includes/version.php" ]; then
    echo "[WordPress] Downloading WordPress..."

    curl -fsSL \
        https://wordpress.org/wordpress-6.8.2.tar.gz \
        -o /tmp/wordpress.tar.gz

    tar -xzf /tmp/wordpress.tar.gz \
        --strip-components=1 \
        -C "$WP_PATH"

    rm -f /tmp/wordpress.tar.gz
    chown -R www-data:www-data "$WP_PATH"
fi

# Wait until MariaDB accepts WordPress credentials
echo "[WordPress] Waiting for MariaDB..."

count=0

until MYSQL_PWD="$WORDPRESS_DB_PASSWORD" \
    mariadb \
        -h mariadb \
        -u "$WORDPRESS_DB_USER" \
        "$WORDPRESS_DB_NAME" \
        -e "SELECT 1" >/dev/null 2>&1
do
    count=$((count + 1))

    if [ "$count" -ge 60 ]; then
        echo "[WordPress] MariaDB connection failed." >&2
        exit 1
    fi

    sleep 2
done

# Generate WordPress configuration if missing
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "[WordPress] Creating wp-config.php..."

    wp config create \
        --path="$WP_PATH" \
        --dbname="$WORDPRESS_DB_NAME" \
        --dbuser="$WORDPRESS_DB_USER" \
        --dbpass="$WORDPRESS_DB_PASSWORD" \
        --dbhost="$WORDPRESS_DB_HOST" \
        --skip-check \
        --allow-root
fi

# Install WordPress only if not installed
if ! wp core is-installed \
    --path="$WP_PATH" \
    --allow-root
then
    echo "[WordPress] Installing WordPress..."

    wp core install \
        --path="$WP_PATH" \
        --url="https://${WORDPRESS_DOMAIN}" \
        --title="$WORDPRESS_TITLE" \
        --admin_user="$WORDPRESS_ADMIN_USER" \
        --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
        --admin_email="$WORDPRESS_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

# Create the additional user if it does not exist
if ! wp user get "$WORDPRESS_USER" \
    --path="$WP_PATH" \
    --allow-root >/dev/null 2>&1
then
    echo "[WordPress] Creating additional user..."

    wp user create \
        "$WORDPRESS_USER" \
        "$WORDPRESS_USER_EMAIL" \
        --user_pass="$WORDPRESS_USER_PASSWORD" \
        --role=author \
        --path="$WP_PATH" \
        --allow-root
fi

# Configure Redis caching (optional bonus)
setup_redis() {
    if ! wp plugin is-installed redis-cache \
        --path="$WP_PATH" --allow-root; then

        wp plugin install redis-cache --activate \
            --path="$WP_PATH" --allow-root || return 1

    elif ! wp plugin is-active redis-cache \
        --path="$WP_PATH" --allow-root; then

        wp plugin activate redis-cache \
            --path="$WP_PATH" --allow-root || return 1
    fi

    wp config set WP_REDIS_HOST redis \
        --type=constant \
        --path="$WP_PATH" --allow-root || return 1

    wp config set WP_REDIS_PORT 6379 \
        --raw \
        --type=constant \
        --path="$WP_PATH" --allow-root || return 1

    wp redis enable \
        --path="$WP_PATH" --allow-root || return 1
}

if setup_redis; then
    echo "[WordPress] Redis object caching enabled."
else
    echo "[WordPress] Redis setup unavailable. Continuing."
fi

# Start PHP-FPM in foreground
echo "[WordPress] Starting PHP-FPM..."

exec php-fpm8.2 -F
