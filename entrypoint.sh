#!/bin/sh
set -xeu
certbot certonly --dns-cloudflare \
--dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
--dns-cloudflare-propagation-seconds 15 \
--deploy-hook /deploy.sh \
--email "$CERTBOT_EMAIL" --agree-tos --no-eff-email --keep-until-expiring \
$CERTBOT_ARGS
/deploy.sh
exec "$@"
