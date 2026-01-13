# certbot-cron-cloudflare

Simple Dockerfile for running certbot-dns-cloudflare with crond and executing
Docker commands based on renewals.

## Example `compose.yaml` with soju

```yaml
services:
  soju:
    container_name: soju
    image: codeberg.org/emersion/soju
    restart: unless-stopped
    ports:
      - "6697:6697"
    volumes:
      - ./soju/config:/soju-config:ro
      - ./soju/db:/db
      - ./soju/uploads:/uploads
      - ./certbot:/tls:ro
  certbot:
    container_name: certbot
    build:
      context: ~/src/certbot-cron-cloudflare
      dockerfile: Dockerfile
    environment:
      TZ: America/Chicago
      CERTBOT_EMAIL: webmaster@example.com
      CERTBOT_ARGS: -d example.com
      CERTBOT_DEPLOY: docker kill --signal=HUP soju
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./certbot:/etc/letsencrypt
```

`certbot/cloudflare.ini`:

```ini
dns_cloudflare_api_token = ...
```

`soju/config`:

```
db sqlite3 /db/main.db
message-store db
file-upload fs /uploads/
listen unix+admin://
listen ircs://
tls /tls/live/example.com/fullchain.pem /tls/live/example.com/privkey.pem
hostname example.com
```
