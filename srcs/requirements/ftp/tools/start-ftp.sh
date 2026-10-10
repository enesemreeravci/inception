#!/bin/sh

set -eu

# Validate environment variables
: "${FTP_USER:?FTP_USER must be set}"
: "${FTP_PASV_ADDRESS:?FTP_PASV_ADDRESS must be set}"

# Read FTP password from Docker secret
FTP_PASSWORD="$(cat /run/secrets/ftp_password)"

[ -n "$FTP_PASSWORD" ] || {
    echo "Error: FTP password is empty" >&2
    exit 1
}

# Prepare vsftpd runtime directory
mkdir -p /var/run/vsftpd/empty

# Allow FTP authentication for users with nologin shell
grep -qxF /usr/sbin/nologin /etc/shells \
    || echo /usr/sbin/nologin >> /etc/shells

# Create or update FTP user
if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd \
        -M \
        -d /var/www/html \
        -s /usr/sbin/nologin \
        -G www-data \
        "$FTP_USER"
else
    usermod \
        -d /var/www/html \
        -s /usr/sbin/nologin \
        -G www-data \
        "$FTP_USER"
fi

# Set FTP password
printf '%s:%s\n' "$FTP_USER" "$FTP_PASSWORD" | chpasswd
unset FTP_PASSWORD

# Prepare WordPress uploads directory
mkdir -p /var/www/html/wp-content/uploads

# Give WordPress group ownership of uploads
chgrp -R www-data /var/www/html/wp-content/uploads

# Allow owner and group to read/write uploads
chmod -R ug+rwX /var/www/html/wp-content/uploads

# Ensure new subdirectories inherit the www-data group
find /var/www/html/wp-content/uploads \
    -type d -exec chmod g+s {} +

# Generate vsftpd configuration
envsubst '${FTP_PASV_ADDRESS}' \
    < /etc/vsftpd.conf.template \
    > /etc/vsftpd.conf

# Start FTP server in foreground
exec /usr/sbin/vsftpd /etc/vsftpd.conf

