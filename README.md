# certbot-cron-cloudflare

Simple Dockerfile for running certbot-dns-cloudflare with supercronic and
executing Docker commands based on renewals.

The image runs as `1000:1000` and keeps certbot's work and log directories in
`/tmp/certbot`, so `/etc/letsencrypt` is the only mount it needs to write to.

## Example `compose.yaml` with soju

```yaml
x-hardening: &hardening
  restart: unless-stopped
  user: "1000:1000" # see Permissions
  read_only: true
  cap_drop: [ALL]
  security_opt: [no-new-privileges:true]

services:
  soju:
    <<: *hardening
    container_name: soju # CERTBOT_DEPLOY signals it by name
    image: codeberg.org/emersion/soju
    restart: always # see Restart policy
    command: ["-config", "/etc/soju/config"]
    healthcheck:
      test: ["CMD", "sojuctl", "-config", "/etc/soju/config", "help"]
    tmpfs:
      - /run/soju:uid=1000,gid=1000,mode=0700
      - /tmp:mode=1777
    volumes:
      - ./data/soju/config:/etc/soju:ro
      - ./data/soju/db:/db
      - ./data/soju/uploads:/uploads
      - ./data/certbot/live:/tls/live:ro
      - ./data/certbot/archive:/tls/archive:ro
    ports:
      - 6697:6697
  socket-proxy:
    <<: *hardening
    image: lscr.io/linuxserver/socket-proxy
    user: "65534:65534"
    group_add: ["${DOCKER_GID}"] # stat -c %g /var/run/docker.sock
    tmpfs:
      - /run:mode=1777
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      ALLOW_RESTARTS: "1"
      EVENTS: "0"
  certbot:
    <<: *hardening
    build: https://github.com/misscatmint/certbot-cron-cloudflare.git
    depends_on:
      - soju
      - socket-proxy
    environment:
      CERTBOT_EMAIL: webmaster@example.com
      CERTBOT_ARGS: -d example.com
      CERTBOT_DEPLOY: docker kill --signal=HUP soju
      DOCKER_HOST: tcp://socket-proxy:2375
    tmpfs:
      - /tmp:mode=1777
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data/certbot:/etc/letsencrypt
```

```sh
mkdir -p data/soju/config data/soju/db data/soju/uploads \
    data/certbot/live data/certbot/archive
```

`data/certbot/cloudflare.ini`:

```ini
dns_cloudflare_api_token = ...
```

`data/soju/config/config`:

```
db sqlite3 /db/main.db
message-store db
file-upload fs /uploads/
listen unix+admin:///run/soju/admin
listen ircs://
tls /tls/live/example.com/fullchain.pem /tls/live/example.com/privkey.pem
hostname example.com
```

```sh
chmod 600 data/certbot/cloudflare.ini
sudo chown -R 1000:1000 data    # skip on rootless Docker, see Permissions
docker compose run --rm --no-deps certbot /issue.sh
docker compose up -d
```

Soju exits if its certificate files are missing, so the `run` gets the first
certificate before soju starts. `--no-deps` keeps it from starting soju
alongside.

Soju only gets the `live` and `archive` directories, so it can't read the
Cloudflare API token or the ACME account key. The soju image puts its admin
socket in `/` by default, which a non-root user can't write to, so the config
moves it to the `/run/soju` tmpfs.

Certbot uses the host's timezone for its renewal schedule through the
`/etc/localtime` mount.

## Socket proxy

Mounting `/var/run/docker.sock` into certbot would give it full control of the
Docker daemon, which is root-equivalent on the host. The socket proxy only
lets it stop, restart and kill containers, which is enough for
`CERTBOT_DEPLOY`. It has no published port, so only containers in this
project can reach it. Set `DOCKER_GID` in `.env` to the group that owns
`/var/run/docker.sock`.

## Permissions

Soju and certbot run as 1000:1000 and never as root, so they can't fix
ownership for you. Every directory you mount has to exist and be writable by
that user before the first start (the `mkdir` and `chown` in the
[example](#example-composeyaml-with-soju)). If Docker creates a missing one
itself, root owns it and the containers can't write to it. The socket proxy
runs as `nobody` with the socket's group added, so the socket is the only
thing it can reach.

- **Different owner:** set `user: "UID:GID"` in the anchor to the owner of
  your data directory, and give soju's `/run/soju` tmpfs the same `uid` and
  `gid`.
- **Rootless Docker:** set `user: "0:0"` in the anchor and on the socket
  proxy, drop the tmpfs `uid` and `gid` options and `group_add`, mount
  `$XDG_RUNTIME_DIR/docker.sock` instead of `/var/run/docker.sock`, and skip
  the `chown`. Root inside the container is your own user on the host, so it
  owns your files without needing any capabilities, and `cap_drop: [ALL]`
  still applies.
- **`userns-remap`:** add `userns_mode: host` to every service. Otherwise,
  chown your data directories to the remapped UID (the start of your
  subordinate UID range plus 1000), and keep `userns_mode: host` on the socket
  proxy, which needs the host's Docker group.

## Restart policy

Note that due to a bug in Docker, you may need to set the restart policy to
`always` instead of `unless-stopped` to have soju start up on system reboot.
This happens when using `docker kill` in `CERTBOT_DEPLOY`, which makes Docker
erroneously think the container was manually stopped, even for signals like
`SIGHUP`. For more information, see
[here](https://github.com/moby/moby/pull/53415).
