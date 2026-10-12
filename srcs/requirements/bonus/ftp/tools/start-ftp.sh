#!/bin/sh

set -eu

# Validate required configuration
: "${FTP_USER:?FTP_USER must be set}"
: "${FTP_PASV_ADDRESS:?FTP_PASV_ADDRESS must be set}"

# Read password from Docker secret
FTP_PASSWORD="$(cat /run/secrets/ftp_password)"

if [ -z "$FTP_PASSWORD" ]; then
    echo "Error: FTP password is empty" >&2
    exit 1
fi

# Prepare runtime directory
mkdir -p /var/run/vsftpd/empty

# Allow authentication for users with nologin shell
grep -qxF /usr/sbin/nologin /etc/shells || \
    echo /usr/sbin/nologin >> /etc/shells

# Create the FTP user if missing
if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -M \
        -d /var/www/html \
        -s /usr/sbin/nologin \
        -G www-data \
        "$FTP_USER"
fi

# Set password from secret
printf '%s:%s\n' "$FTP_USER" "$FTP_PASSWORD" | chpasswd
unset FTP_PASSWORD

# Prepare WordPress uploads directory
mkdir -p /var/www/html/wp-content/uploads

chgrp -R www-data /var/www/html/wp-content/uploads
chmod -R ug+rwX /var/www/html/wp-content/uploads

# New directories inherit the WordPress group
find /var/www/html/wp-content/uploads \
    -type d -exec chmod g+s {} +

# Substitute passive address into configuration
envsubst '${FTP_PASV_ADDRESS}' \
    < /etc/vsftpd.conf.template \
    > /etc/vsftpd.conf

# Run FTP server as main container process
exec /usr/sbin/vsftpd /etc/vsftpd.conf
