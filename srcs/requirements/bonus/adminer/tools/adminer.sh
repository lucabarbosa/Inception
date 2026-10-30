#!/bin/sh
set -e

if [ ! -f "index.php" ]; then
    echo "Downloading Adminer..."
    wget "https://www.adminer.org/latest.php" -O index.php
fi

sed -i 's|listen = /run/php/php7.4-fpm.sock|listen = 0.0.0.0:8080|g' /etc/php/7.4/fpm/pool.d/www.conf

printf "\033[0;32m[Adminer]\033[0m ready on port 8080\n"
exec "$@"