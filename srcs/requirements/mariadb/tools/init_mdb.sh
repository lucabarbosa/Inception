#!/bin/bash
set -e

WP_DB_NAME="$(cat /run/secrets/mdb_name)"
WP_DB_USER="$(cat /run/secrets/mdb_user)"
DB_PASSWORD="$(cat /run/secrets/mdb_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/mdb_root_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

if [ ! -d "/var/lib/mysql/${WP_DB_NAME}" ]; then
	printf "\033[0;33m[mariadb]\033[0m Initializing MariaDB database with Secrets...\n"

	if [ ! -d "/var/lib/mysql/mysql" ]; then
		mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
	fi

	mariadbd --user=mysql --bootstrap <<SQL
FLUSH PRIVILEGES;
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

	printf "\033[0;33m[mariadb]\033[0m Database '%s' and user '%s' created.\n" "${WP_DB_NAME}" "${WP_DB_USER}"
fi

exec mariadbd --user=mysql