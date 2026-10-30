#!/bin/bash
set -e

WP_DB_NAME=$(cat /run/secrets/mdb_name)
WP_DB_USER=$(cat /run/secrets/mdb_user)
DB_PASSWORD="$(cat /run/secrets/mdb_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/mdb_root_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
	echo "\033[0;33m[mariadb]\033[0m Initializing MariaDB database with Secrets..."

	if [ ! -d "/var/lib/mysql/mysql" ]; then
		mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
	fi

	mariadbd --user=mysql --bootstrap <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

	echo "\033[0;33m[mariadb]\033[0m Database '${MYSQL_DATABASE}' and user '${MYSQL_USER}' created."
fi

exec mariadbd --user=mysql