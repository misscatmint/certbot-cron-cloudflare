FROM certbot/dns-cloudflare:latest

ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.51/supercronic-linux-amd64
ARG SUPERCRONIC_SHA256=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123
RUN apk add --no-cache curl docker-cli && \
    curl -fsSL -o /usr/local/bin/supercronic "$SUPERCRONIC_URL" && \
    echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c - && \
    chmod +x /usr/local/bin/supercronic

COPY --chmod=755 crontab deploy.sh entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/bin/supercronic", "/crontab"]
