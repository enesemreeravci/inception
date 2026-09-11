FROM debian:12-slim

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

RUN rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql

COPY tools/start-mariadb.sh /usr/local/bin/start-mariadb.sh

RUN chmod +x /usr/local/bin/start-mariadb.sh

EXPOSE 3306

CMD ["/usr/local/bin/start-mariadb.sh"]
