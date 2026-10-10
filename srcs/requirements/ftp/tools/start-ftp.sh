
#!/bin/sh

set -eu

: "${FTP_USER:?FTP_USER must be set}"
: "${FTP_PASV_ADDRESS:?FTP_PASV_ADDRESS must be set}"

# Read FTP password from Docker secret
FTP_PASSWORD="$(cat /run/secrets/ftp_password)"

[ -n "$FTP_PASSWORD" ] || {
    echo "Error: FTP password is empty" >&2
    exit 1
}

mkdir -p /var/run/vsftpd/empty

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

# Set FTP user password
printf '%s:%s\n' "$FTP_USER" "$FTP_PASSWORD" | chpasswd
unset FTP_PASSWORD

# Ensure WordPress files are writable by www-data group
chmod -R g+rwX /var/www/html

# Generate vsftpd configuration
envsubst '${FTP_PASV_ADDRESS}' \
    < /etc/vsftpd.conf.template \
    > /etc/vsftpd.conf

exec /usr/sbin/vsftpd /etc/vsftpd.conf
