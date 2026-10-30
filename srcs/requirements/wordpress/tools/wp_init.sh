#!/bin/bash
set -e

MDB_NAME="$(cat /run/secrets/mdb_name)"
MDB_USER="$(cat /run/secrets/mdb_user)"
MDB_PASSWORD="$(cat /run/secrets/mdb_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"
DB_HOST="mariadb:3306"

log() { printf "\033[0;36m[wordpress]\033[0m %s\n" "$*"; }

: "${DOMAIN_NAME:?DOMAIN_NAME not defined in .env}"
: "${WP_TITLE:?WP_TITLE not defined in .env}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER not defined in .env}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL not defined in .env}"
: "${WP_USER:?WP_USER not defined in .env}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL not defined in .env}"

case "${WP_ADMIN_USER,,}" in
	*admin*)
		log "ERROR: WP_ADMIN_USER ('${WP_ADMIN_USER}') can't have 'admin' or similar."
		exit 1
		;;
esac

log "Waiting for MariaDB..."
tries=0
until MYSQL_PWD="${DB_PASSWORD}" mariadb -h mariadb -u "${MDB_USER}" \
		-e "SELECT 1;" "${MDB_NAME}" > /dev/null 2>&1; do
	tries=$((tries + 1))
	if [ "${tries}" -ge 30 ]; then
		log "ERROR: MariaDB did not respond in time."
		exit 1
	fi
	sleep 2
done
log "MariaDB ready."

cd /var/www/html

if [ ! -f wp-load.php ]; then
	log "Downloading WordPress..."
	wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
	log "Creating wp-config.php..."
	wp config create --allow-root \
		--dbname="${MDB_NAME}" \
		--dbuser="${MDB_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost="${DB_HOST}"
fi

if ! wp core is-installed --allow-root 2> /dev/null; then
	log "Instaling WordPress..."
	wp core install --allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email
fi

if ! wp user get "${WP_USER}" --allow-root > /dev/null 2>&1; then
	log "Creating user '${WP_USER}'..."
	wp user create "${WP_USER}" "${WP_USER_EMAIL}" --allow-root \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}"
fi

chown -R www-data:www-data /var/www/html

log "Starting php-fpm..."
exec php-fpm8.2 -F