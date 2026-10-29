FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y && \
	apt-get install -y --no-install-recommends nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl/cert && \
	openssl req -x509 -nodes \
	-days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/cert/lbento.42.fr.key \
	-out /etc/nginx/ssl/cert/lbento.42.fr.crt \
	-subj "/C=BR/O=42/CN=lbento.42.fr"

RUN rm -f /etc/nginx/sites-enabled/default
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]