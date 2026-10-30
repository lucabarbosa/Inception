*This project has been created as part of the 42 curriculum by lbento.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum. The goal is to
build a small web infrastructure on a virtual machine with **Docker** and **Docker Compose**.
Each service runs in its own container, built from a Dockerfile written by hand on top of
`debian:bookworm`. No ready-made images are pulled, apart from the Debian base image.

The stack serves a **WordPress** website over **HTTPS only**:

| Service     | Role                                                         | Exposed port        |
|-------------|--------------------------------------------------------------|---------------------|
| `nginx`     | Single entry point, TLS termination (TLSv1.2 / TLSv1.3 only) | `443`               |
| `wordpress` | WordPress + PHP-FPM 8.2 (no web server), set up with WP-CLI  | internal `9000`     |
| `mariadb`   | MariaDB database for WordPress                               | internal `3306`     |
| `redis`     | *(bonus)* Object cache for WordPress                         | internal `6379`     |
| `static`    | *(bonus)* Static HTML site (a pamonha recipe), served by its own NGINX | `8080` |
| `adminer`   | *(bonus)* Web UI to manage the MariaDB database              | `8081`              |

Two Docker **named volumes** keep the data across restarts. Their contents are stored in
`/home/lbento/data` on the host:

- `wp_data` → `/home/lbento/data/wp_data` (WordPress files)
- `db_data` → `/home/lbento/data/db_data` (MariaDB database)

All containers share one user-defined bridge network called `inception`. The site is
reachable at **https://lbento.42.fr**, which points to `127.0.0.1` through `/etc/hosts`.

```
host :443  ──► nginx ──(FastCGI :9000)──► wordpress ──(:3306)──► mariadb
                 │                          │    │                  │
                 └──── wp_data volume ──────┘    └─(:6379)─► redis  └── db_data volume

host :8080 ──► static            host :8081 ──► adminer ──(:3306)──► mariadb

all containers: network "inception" (bridge)
volumes stored in: /home/lbento/data/{wp_data,db_data}
```

## Instructions

### Prerequisites

- A Linux virtual machine (developed and tested on Debian), with `sudo` rights
- Docker Engine and the Docker Compose v2 plugin (`docker compose`)
- `make`

### Secrets

Credentials are never stored in the repository. Create a `secrets/` folder at the root
of the repository (it is ignored by git) with these six files:

```bash
mkdir -p secrets
printf 'wordpress'      > secrets/mdb_name.txt           # database name
printf 'wpuser'         > secrets/mdb_user.txt           # database user
printf 'CHANGE_ME_1'    > secrets/mdb_password.txt       # database user password
printf 'CHANGE_ME_2'    > secrets/mdb_root_password.txt  # MariaDB root password
printf 'CHANGE_ME_3'    > secrets/wp_admin_password.txt  # WordPress admin password
printf 'CHANGE_ME_4'    > secrets/wp_user_password.txt   # WordPress second user password
```

Settings that are not sensitive (domain, site title, user names and e-mails) are kept in
`srcs/.env`.

### Build and run

```bash
make          # checks the secrets, adds lbento.42.fr to /etc/hosts,
              # creates /home/lbento/data/*, builds the images and starts the stack
make ps       # shows the container status
make logs     # follows the logs
make down     # stops and removes the containers (the data is kept)
make fclean   # removes everything, including the data in /home/lbento/data
```

Then open **https://lbento.42.fr** (the certificate is self-signed, so the browser shows a
warning). The admin panel is at **https://lbento.42.fr/wp-admin**.
The bonus services are at **http://localhost:8080** (static site) and
**http://localhost:8081** (Adminer).

More detail: [USER_DOC.md](USER_DOC.md) (using the stack) and
[DEV_DOC.md](DEV_DOC.md) (developing and maintaining it).

## Project description

### How Docker is used

Each service has its own Dockerfile in `srcs/requirements/<service>/`, with a `conf/`
folder (configuration files) and, when needed, a `tools/` folder (entrypoint scripts).
`srcs/docker-compose.yml` describes how the images are built and connected, and the
`Makefile` at the root drives Compose. Every image has the same name as its service.

```
.
├── Makefile
├── README.md / USER_DOC.md / DEV_DOC.md
├── secrets/                      # not versioned
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── nginx/       {Dockerfile, conf/nginx.conf}
        ├── wordpress/   {Dockerfile, conf/www.conf, tools/wp_init.sh}
        ├── mariadb/     {Dockerfile, conf/mariadb.cnf, tools/init_mdb.sh}
        └── bonus/
            ├── redis/   {Dockerfile, conf/redis.conf}
            ├── static/  {Dockerfile, conf/nginx.conf, site/index.html}
            └── adminer/ {Dockerfile}
```

### Main design choices

- **Base image: `debian:bookworm`** (Debian 12). It is the penultimate stable release,
  as the subject asks, and has PHP 8.2, MariaDB and NGINX in its official repositories.
- **The main process runs as PID 1, in the foreground.** NGINX runs with `daemon off;`,
  PHP-FPM with `-F` and MariaDB with `mariadbd`. The entrypoint scripts end with `exec`,
  so the service replaces the shell and gets the signals sent by `docker stop`.
  No `tail -f`, `sleep infinity` or `while true`.
- **First-run setup that is safe to repeat.** `init_mdb.sh` creates the database, the
  user and the root password only if the database does not exist yet (it uses
  `mariadbd --bootstrap`, so no temporary server is left running). `wp_init.sh` uses
  WP-CLI to download WordPress, write `wp-config.php`, install the site and create the
  second user, and each step runs only when it is still needed.
- **Two WordPress users.** The administrator (`WP_ADMIN_USER`, here `lbento`) and a user
  with the *author* role. The script refuses to start if the admin name contains `admin`.
- **Startup order.** MariaDB has a healthcheck (`mariadb-admin ping`), and WordPress
  waits for `service_healthy`. It then waits until it can actually log in, with a limited
  number of retries.
- **TLS.** The self-signed certificate is created with `openssl` when the image is built,
  so no private key is ever stored in the repository. NGINX accepts only `TLSv1.2` and
  `TLSv1.3`, and port 443 is the only port of the mandatory part open to the host.
- **Restart policy.** `restart: unless-stopped` on every service, so a container that
  crashes is started again.
- **Bonus.** Redis is used only as a cache: no persistence, 256 MB limit, `allkeys-lru`
  eviction. The `redis-cache` plugin is installed and turned on by `wp_init.sh`. Adminer is
  served by PHP's built-in server, and the static site has its own NGINX.

### Virtual Machines vs Docker

A **virtual machine** emulates a whole computer with its own kernel, running on a
hypervisor. It gives strong isolation, but it is heavy: gigabytes of disk, a full OS boot,
and RAM reserved up front. A **Docker container** is an isolated process that shares the
host kernel. Namespaces separate its view of the system (PID, network, filesystem) and
cgroups limit its resources. Containers start in seconds, weigh megabytes and are built
from a Dockerfile that anyone can reproduce. The isolation is weaker than a VM's, since the
kernel is shared. This project uses both: a VM as the host environment, as the subject
requires, and containers for each service inside it.

### Secrets vs Environment Variables

**Environment variables** are easy to use, but they are visible to anyone who can run
`docker inspect` or read `/proc/<pid>/environ`, child processes inherit them, and they
often end up in logs. **Docker secrets** are files mounted read-only into
`/run/secrets/<name>`, only in the services that ask for them, and they never show up in
the image or in `docker inspect`. In this project every sensitive value (database name,
database user and all passwords) is a secret, read by the entrypoint scripts with `cat`.
The `.env` file only holds settings that are not sensitive: domain, site title, user names
and e-mails.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network stack. There is no isolation,
every port the service opens is open on the host, and port clashes are possible. A
**user-defined bridge network** (here `inception`) gives the containers a private network
with built-in DNS, so `wordpress` reaches the database at `mariadb:3306` by service name.
Only the ports listed under `ports:` are published to the host. This keeps MariaDB,
PHP-FPM and Redis unreachable from outside, with NGINX on port 443 as the only entry point
of the mandatory part. Host networking and `links` are forbidden by the subject.

### Docker Volumes vs Bind Mounts

A **bind mount** maps a host path straight into a container (`/host/path:/container/path`).
It depends on the host's folder layout and permissions, and Docker does not manage it.
A **named volume** is an object managed by Docker. It has a name, it shows up in
`docker volume ls`, it can be inspected and removed with Docker commands, and several
services can share it. Here `wp_data` and `db_data` are named volumes that use the
`local` driver with `driver_opts` (`type: none`, `o: bind`, `device: /home/lbento/data/...`).
They remain named volumes managed by Docker, and the `local` driver just stores their data
in the folder the subject requires.

## Resources

- [Docker documentation](https://docs.docker.com/), including
  [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Manage secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/) and
  [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [Docker networking: bridge networks](https://docs.docker.com/engine/network/drivers/bridge/)
- [Docker and the PID 1 zombie reaping problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/)
- [NGINX `ngx_http_ssl_module`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB Server documentation](https://mariadb.com/kb/en/documentation/)
- [Redis Object Cache plugin](https://wordpress.org/plugins/redis-cache/)
- [Adminer](https://www.adminer.org/)

### Use of AI

AI (Claude) was used as a study, create README structure and review aid, following the subject's AI guidelines:

- **Learning concepts:** explanations of Docker topics (PID 1 and `exec`, secrets vs
  environment variables, named volumes vs bind mounts, bridge networks) and of how NGINX,
  PHP-FPM and MariaDB fit together. I checked these against the official documentation.
- **Documentation:** drafting `README.md`, `USER_DOC.md` and `DEV_DOC.md` from the
  finished project. I reviewed and corrected the drafts.