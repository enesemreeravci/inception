#!/bin/sh

set -eu
: "${DOMAIN_NAME:?DOMAIN_NAME must be set}"
mkdir -p /etc/nginx/ssl


if [ ! -f /etc/nginx/ssl/inception.crt ] || [ ! -f /etc/nginx/ssl/inception.key ]; then
    openssl req -x509 -newkey rsa:2048 -sha256 -noenc \
    -days 365 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/CN=${DOMAIN_NAME}" \
    -addext "subjectAltName=DNS:${DOMAIN_NAME}"
fi
chmod 600 /etc/nginx/ssl/inception.key
envsubst '${DOMAIN_NAME}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf
nginx -t
exec nginx -g "daemon off;"
