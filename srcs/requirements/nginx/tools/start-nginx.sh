#!/bin/sh

set -eu

mkdir -p /etc/nginx/ssl


if [ ! -f /etc/nginx/ssl/inception.crt ] || [ ! -f /etc/nginx/ssl/inception.key ]; then
    openssl req -x509 -newkey rsa:2048 -sha256 -noenc \
    -days 365 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/CN=eeravci.42.fr" \
    -addext "subjectAltName=DNS:eeravci.42.fr"
fi
chmod 600 /etc/nginx/ssl/inception.key
nginx -t
exec nginx -g "daemon off;"
