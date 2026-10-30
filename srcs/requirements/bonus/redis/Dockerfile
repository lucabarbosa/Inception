FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y && \
	apt-get install -y --no-install-recommends redis-server \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/redis.conf /etc/redis/redis.conf
RUN chmod +x /usr/local/bin/redis.sh

EXPOSE 6379

CMD ["redis-server", "/etc/redis/redis.conf"]