#!/bin/sh

set -eu

: "${FTP_USER:?FTP_USER must be set}"
: "${FTP_PASSWORD:?FTP_PASSWORD must be set}"
: "${FTP_PASV_ADDRESS:?FTP_PASV_ADDRESS must be set}"

mkdir -p /var/run/vsftpd/empty

grep -qxF /usr/sbin/nologin /etc/shells \
	|| echo /usr/sbin/nologin >> /etc/shells

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

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

chmod -R g+rwX /var/www/html

envsubst '${FTP_PASV_ADDRESS}' \
	< /etc/vsftpd.conf.template \
	> /etc/vsftpd.conf

exec /usr/sbin/vsftpd /etc/vsftpd.conf
