FROM certbot/dns-cloudflare:latest
RUN apk update && apk add --no-cache docker-cli

COPY --chmod=755 deploy.sh entrypoint.sh /
COPY crontab /etc/crontabs/certbot

ENTRYPOINT ["/entrypoint.sh"]
CMD ["crond", "-f"]
