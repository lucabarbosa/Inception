# Developer Documentation

This guide explains how to set up, build, run and maintain the Inception stack as a
developer. For everyday use (opening the site, credentials, health checks), see
[USER_DOC.md](USER_DOC.md).

## 1. Set up the environment from scratch

### 1.1 Prerequisites

- A Linux VM (the project is meant to run on Debian) with `sudo` rights
- Docker Engine and the Compose v2 plugin. Check with `docker --version` and
  `docker compose version`
- `make` and `git`
- Your user in the `docker` group (`sudo usermod -aG docker $USER`, then log out and in
  again), or every `docker` command run with `sudo`

On Debian, for example:

```bash
sudo apt-get update
sudo apt-get install -y make git ca-certificates curl
# then install Docker Engine + compose plugin: https://docs.docker.com/engine/install/debian/
```

### 1.2 Get the code

```bash
git clone <repository-url> inception
cd inception
```

### 1.3 Configuration files

| File                 | Versioned | Purpose                                                    |
|----------------------|-----------|------------------------------------------------------------|
| `srcs/.env`          | yes       | Non-sensitive settings: `DOMAIN_NAME`, `WP_TITLE`, `WP_ADMIN_USER`, `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_EMAIL` |
| `secrets/*.txt`      | **no**    | Sensitive values, mounted as Docker secrets                |
| `srcs/docker-compose.yml` | yes  | Services, volumes, network and secrets                     |

`WP_ADMIN_USER` must **not** contain `admin` (in any case). `wp_init.sh` stops with an
error if it does.

### 1.4 Secrets

`secrets/` is listed in `.gitignore`. Create it at the root of the repository:

```bash
mkdir -p secrets
printf 'wordpress' > secrets/mdb_name.txt
printf 'wpuser'    > secrets/mdb_user.txt
openssl rand -base64 18 | tr -d '\n' > secrets/mdb_password.txt
openssl rand -base64 18 | tr -d '\n' > secrets/mdb_root_password.txt
openssl rand -base64 18 | tr -d '\n' > secrets/wp_admin_password.txt
openssl rand -base64 18 | tr -d '\n' > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

| Secret              | Used by              | Read in                        |
|---------------------|----------------------|--------------------------------|
| `mdb_name`          | mariadb, wordpress   | `/run/secrets/mdb_name`        |
| `mdb_user`          | mariadb, wordpress   | `/run/secrets/mdb_user`        |
| `mdb_password`      | mariadb, wordpress   | `/run/secrets/mdb_password`    |
| `mdb_root_password` | mariadb              | `/run/secrets/mdb_root_password` |
| `wp_admin_password` | wordpress            | `/run/secrets/wp_admin_password` |
| `wp_user_password`  | wordpress            | `/run/secrets/wp_user_password`  |

`make setup` refuses to continue if any of these files is missing or empty.

### 1.5 Using another login

The login `lbento` is hard-coded in a few places. To run the project under another
login, replace it in:

- `Makefile`: the `/etc/hosts` entry and the `/home/lbento/data` paths
- `srcs/.env`: `DOMAIN_NAME` and the e-mails
- `srcs/docker-compose.yml`: the `device:` path of both volumes
- `srcs/requirements/nginx/Dockerfile`: the certificate's file names and `CN`
- `srcs/requirements/nginx/conf/nginx.conf`: `server_name` and the certificate paths

## 2. Build and launch

The `Makefile` wraps Docker Compose with the project name `inception`
(`docker compose -p inception -f srcs/docker-compose.yml ...`).

| Target        | Action                                                                          |
|---------------|---------------------------------------------------------------------------------|
| `all` (default) | `setup` + `up`                                                                |
| `setup`       | Checks the secrets, adds `127.0.0.1 lbento.42.fr` to `/etc/hosts` if it is missing, creates `/home/lbento/data/{wp_data,db_data}` |
| `bonus`       | Same as `all`. The bonus services are part of the same compose file           |
| `up`          | `docker compose up --build -d`: builds the images and starts the containers   |
| `down`        | Removes the containers and the network. Volumes and data are kept             |
| `stop` / `start` | Stops / starts the existing containers                                      |
| `ps`          | Container status                                                                |
| `logs`        | Follows the logs of all services                                                |
| `clean`       | `down --rmi all -v --remove-orphans`: removes containers, images and the Docker volume objects |
| `fclean`      | `clean` + `docker system prune -af --volumes` + deletes `/home/lbento/data/*`   |
| `re`          | `clean` + `all`: rebuilds everything from scratch                               |

What happens on the first `make`:

1. `mariadb` starts. `init_mdb.sh` sees that the database folder does not exist, runs
   `mariadb-install-db` if needed, then runs `mariadbd --bootstrap` to create the
   database, the user, the grants and the root password. It finishes with
   `exec mariadbd`, so MariaDB becomes PID 1.
2. Once the healthcheck (`mariadb-admin ping`) reports `healthy` and `redis` has
   started, Compose starts `wordpress`.
3. `wp_init.sh` waits until it can log in to the database. It then uses WP-CLI to
   download WordPress, create `wp-config.php`, install the site, create the second user
   (role *author*) and turn on the Redis object cache. It finishes with
   `exec php-fpm8.2 -F`.
4. `nginx` serves `/var/www/html` from the shared `wp_data` volume and passes `*.php` to
   `wordpress:9000` over FastCGI.

Every step checks whether it has already been done. On later starts, nothing is
reinstalled and the existing data is used.

### Running Compose directly

```bash
docker compose -p inception -f srcs/docker-compose.yml build nginx      # rebuild one image
docker compose -p inception -f srcs/docker-compose.yml up -d --build wordpress
docker compose -p inception -f srcs/docker-compose.yml config           # print the resolved file
```

Always pass `-p inception`. Without it, Compose uses a different project name and creates
separate containers, volumes and networks.

## 3. Managing containers, images, volumes and the network

```bash
# Containers
docker ps                                   # running containers
docker logs -f wordpress                    # logs of one service
docker exec -it wordpress bash              # shell inside a container
docker restart nginx                        # restart one service
docker inspect --format '{{.State.Health.Status}}' mariadb

# Images (one per service, same name as the service)
docker image ls

# Volumes
docker volume ls                            # inception_wp_data, inception_db_data
docker volume inspect inception_db_data     # shows the device: /home/lbento/data/db_data

# Network
docker network ls                           # inception_inception
docker network inspect inception_inception  # containers and their IPs
```

Useful commands inside the containers:

```bash
# WordPress (WP-CLI)
docker exec wordpress wp user list --allow-root
docker exec wordpress wp plugin list --allow-root
docker exec wordpress wp redis status --allow-root

# MariaDB (root password: secrets/mdb_root_password.txt)
docker exec -it mariadb mariadb -u root -p
#   SHOW DATABASES;  SELECT user, host FROM mysql.user;

# NGINX
docker exec nginx nginx -t                  # check the configuration

# Redis
docker exec redis redis-cli info keyspace
```

## 4. Where the data lives and how it persists

| Volume (Docker name)  | Mounted at (container)                   | Stored on the host           |
|-----------------------|------------------------------------------|------------------------------|
| `inception_wp_data`   | `/var/www/html` in `nginx` and `wordpress` | `/home/lbento/data/wp_data` |
| `inception_db_data`   | `/var/lib/mysql` in `mariadb`            | `/home/lbento/data/db_data`  |

Both are **named volumes** using the `local` driver with
`driver_opts: { type: none, o: bind, device: /home/lbento/data/... }`. Docker manages them
like any other volume, and their contents are written to the host folder the subject
requires.

What each command does to the data:

| Command                       | Containers | Images  | Volume objects | Files in `/home/lbento/data` |
|-------------------------------|------------|---------|----------------|------------------------------|
| `make stop` / `make down`     | stopped / removed | kept | kept     | **kept**                     |
| `make clean` / `make re`      | removed    | removed | removed        | **kept**                     |
| `make fclean`                 | removed    | removed | removed        | **deleted**                  |

Since the files stay on the host after `make clean`, the next `make` creates the volumes
again on the same folders. The init scripts then find the existing database and
WordPress files and skip the setup. To start over with a clean install, use `make fclean`.

Redis keeps no data (`save ""`, `appendonly no`): the cache is empty after each restart.
The static site and Adminer have no volumes. Their content is copied in or downloaded
when the image is built.

## 5. Project layout

```
.
├── Makefile
├── secrets/                             # git-ignored, see 1.4
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile               # nginx + openssl, self-signed cert at build time
        │   └── conf/nginx.conf          # 443 ssl, TLSv1.2/1.3, FastCGI to wordpress:9000
        ├── wordpress/
        │   ├── Dockerfile               # php8.2-fpm + extensions + WP-CLI
        │   ├── conf/www.conf            # FPM pool listening on 9000
        │   └── tools/wp_init.sh         # WordPress install/config, users, Redis
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/mariadb.cnf         # bind-address 0.0.0.0, port 3306
        │   └── tools/init_mdb.sh        # first-run database creation
        └── bonus/
            ├── redis/                   # redis-server, cache only (256 MB, LRU)
            ├── static/                  # nginx on 80 → host 8080, site/index.html
            └── adminer/                 # PHP built-in server on 8080 → host 8081
```

## 6. Troubleshooting

- **`Missing ./secrets/<name>.txt`:** create the file (section 1.4).
- **WordPress exits with `MariaDB did not respond in time`:** check `docker logs mariadb`.
  This often happens when `db_data` holds a database created with other credentials. Run
  `make fclean` to start over.
- **Changes to `secrets/` or `.env` have no effect:** the values are only applied on the
  first install. Run `make fclean && make`.
- **`502 Bad Gateway`:** PHP-FPM is not up yet or has crashed. Check
  `docker logs wordpress`.
- **Permission errors on `/home/lbento/data`:** the folders are created with `sudo`.
  MariaDB and WordPress fix the ownership inside the containers with `chown` at startup.