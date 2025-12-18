FROM certbot/dns-cloudflare:latest
RUN apk update && apk add --no-cache docker-cli

COPY crontab /etc/crontabs/certbot
COPY deploy.sh /deploy.sh
RUN chmod +x /deploy.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["crond", "-f"]
