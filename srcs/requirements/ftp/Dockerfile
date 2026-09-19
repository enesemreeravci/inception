FROM debian:12-slim

RUN apt-get update && apt-get install -y vsftpd \
    gettext-base && rm -rf /var/lib/apt/lists/*

COPY conf/vsftpd.conf /etc/vsftpd.conf.template
COPY tools/start-ftp.sh /usr/local/bin/start-ftp.sh

RUN chmod +x /usr/local/bin/start-ftp.sh

EXPOSE 21 21100-21110

CMD ["/usr/local/bin/start-ftp.sh"]
