# User Documentation

This guide is for anyone who needs to **run and use** the Inception stack: start and stop
it, open the website, find the credentials and check that everything works.
To change or rebuild the project, see [DEV_DOC.md](DEV_DOC.md).

## 1. Services in the stack

| Service     | What it does                                                    | How to reach it                    |
|-------------|-----------------------------------------------------------------|------------------------------------|
| `nginx`     | Web server and the only entry point, HTTPS only (TLS 1.2 / 1.3) | https://lbento.42.fr               |
| `wordpress` | The WordPress site (PHP-FPM), called by NGINX                   | through NGINX only                 |
| `mariadb`   | Database that stores posts, users and settings                  | internal only                      |
| `redis`     | *(bonus)* Cache that makes WordPress faster                     | internal only                      |
| `static`    | *(bonus)* Small static website (a pamonha recipe)               | http://localhost:8080              |
| `adminer`   | *(bonus)* Web page to browse and manage the database            | http://localhost:8081              |

The database, PHP-FPM and Redis cannot be reached from outside. Only ports 443, 8080 and
8081 are open on the host.

## 2. Start and stop the project

Run every command from the root of the repository.

| Command       | What it does                                                                 |
|---------------|------------------------------------------------------------------------------|
| `make`        | First start: checks the secrets, sets up the domain and data folders, builds and starts everything |
| `make stop`   | Pauses the containers without removing them                                  |
| `make start`  | Starts paused containers again                                               |
| `make down`   | Stops and removes the containers. **The website and database are kept.**     |
| `make`        | After `make down`, starts the stack again with the same data                  |
| `make fclean` | **Deletes everything**, including the website and the database. Use with care. |

`make` asks for your `sudo` password the first time. It needs it to add `lbento.42.fr`
to `/etc/hosts` and to create the data folders in `/home/lbento/data`.

> `make fclean` also runs `docker system prune -af --volumes`, which removes **all**
> unused Docker images, containers and volumes on the machine, not only this project's.

## 3. Open the website and the admin panel

- **Website:** https://lbento.42.fr
- **WordPress admin panel:** https://lbento.42.fr/wp-admin
- **Static site (bonus):** http://localhost:8080
- **Adminer (bonus):** http://localhost:8081

The HTTPS certificate is self-signed, so the browser shows a security warning the first
time. This is expected. Choose *Advanced → Proceed* to continue.

Plain HTTP (`http://lbento.42.fr`) does **not** work on purpose: only HTTPS on port 443 is
served.

### Logging in to Adminer

| Field    | Value                                       |
|----------|---------------------------------------------|
| System   | MySQL / MariaDB                             |
| Server   | `mariadb`                                   |
| Username | contents of `secrets/mdb_user.txt`          |
| Password | contents of `secrets/mdb_password.txt`      |
| Database | contents of `secrets/mdb_name.txt`          |

## 4. Credentials

Credentials are kept in two places. Neither of them holds a password that is committed to
git.

**`secrets/` folder** (repository root, ignored by git) holds the sensitive values, one per file:

| File                          | Content                                    |
|-------------------------------|--------------------------------------------|
| `secrets/mdb_name.txt`        | Database name                              |
| `secrets/mdb_user.txt`        | Database user used by WordPress            |
| `secrets/mdb_password.txt`    | Password of that database user             |
| `secrets/mdb_root_password.txt` | MariaDB `root` password                  |
| `secrets/wp_admin_password.txt` | Password of the WordPress administrator  |
| `secrets/wp_user_password.txt`  | Password of the second WordPress user    |

**`srcs/.env`** holds settings that are not sensitive:

| Variable          | Current value            | Meaning                              |
|-------------------|--------------------------|--------------------------------------|
| `DOMAIN_NAME`     | `lbento.42.fr`           | Site address                         |
| `WP_TITLE`        | `Inception`              | Site title                           |
| `WP_ADMIN_USER`   | `lbento`                 | Administrator login                  |
| `WP_ADMIN_EMAIL`  | `lbento@student.42.fr`   | Administrator e-mail                 |
| `WP_USER`         | `myuser`                 | Second user's login (role: author)   |
| `WP_USER_EMAIL`   | `myuser@student.42.fr`   | Second user's e-mail                 |

To read a password: `cat secrets/wp_admin_password.txt`.

**Changing credentials.** They are only applied the first time the site and database are
created. To change a password later:

- **WordPress users:** change it in the admin panel (*Users → Profile*). Editing the
  secret file afterwards has no effect.
- **Database credentials:** if you edit the files in `secrets/` and want the new values
  used, the stack has to be rebuilt from scratch with `make fclean && make`. **This erases
  the site's content.**

## 5. Check that everything works

```bash
make ps          # every service should be "Up"; mariadb should say "(healthy)"
make logs        # follow the logs of all services (Ctrl+C to quit)
```

When WordPress has started correctly, its log ends with `[wordpress] Starting php-fpm...`.

Quick checks:

```bash
# Website answers over HTTPS
curl -kI https://lbento.42.fr                 # expect: HTTP/1.1 200 OK

# Only TLS 1.2 / 1.3 are accepted
openssl s_client -connect lbento.42.fr:443 -tls1_2 </dev/null   # handshake succeeds
openssl s_client -connect lbento.42.fr:443 -tls1_1 </dev/null   # handshake fails

# Database is alive (same check as the healthcheck)
docker inspect --format '{{.State.Health.Status}}' mariadb   # expect: healthy

# Log in to the database as root (password: secrets/mdb_root_password.txt)
docker exec -it mariadb mariadb -u root -p -e "SHOW DATABASES;"

# Redis cache (bonus)
docker exec redis redis-cli ping                        # expect: PONG
docker exec wordpress wp redis status --allow-root      # expect: Status: Connected
```

### Common problems

| Symptom                                   | What to do                                                          |
|-------------------------------------------|---------------------------------------------------------------------|
| `make` prints `Missing ./secrets/xxx.txt` | Create the missing file in `secrets/` (see section 4) and run `make` again. |
| Browser cannot find `lbento.42.fr`        | Check that `/etc/hosts` has the line `127.0.0.1 lbento.42.fr`.      |
| `502 Bad Gateway`                         | WordPress is still starting. Wait a few seconds and check `make logs`. |
| A container keeps restarting              | Run `docker logs <name>` to see the error.                          |