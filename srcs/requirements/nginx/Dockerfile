FROM debian:12-slim

RUN apt-get update && apt-get install -y nginx openssl

COPY conf/nginx.conf /etc/nginx/nginx.conf

COPY tools/start-nginx.sh /usr/local/bin/start-nginx.sh

RUN chmod +x /usr/local/bin/start-nginx.sh

EXPOSE 443

CMD ["/usr/local/bin/start-nginx.sh"]
