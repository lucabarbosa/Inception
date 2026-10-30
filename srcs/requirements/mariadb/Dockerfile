FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y && \
	apt-get install -y --no-install-recommends mariadb-server \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init_mdb.sh /usr/local/bin/init_mdb.sh
RUN chmod +x /usr/local/bin/init_mdb.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init_mdb.sh"]