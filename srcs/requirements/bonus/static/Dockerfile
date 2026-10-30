FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y && \
	apt-get install -y --no-install-recommends nginx \
	&& rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/nginx/sites-enabled/default
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /var/www/static/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
