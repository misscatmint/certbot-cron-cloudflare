#!/bin/sh
certbot certonly --dns-cloudflare \
--dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
--dns-cloudflare-propagation-seconds 15 \
--deploy-hook /deploy.sh \
--email "$CERTBOT_EMAIL" --agree-tos --no-eff-email --force-renewal \
$CERTBOT_ARGS
exec "$@"
