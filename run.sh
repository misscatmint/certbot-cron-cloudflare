#!/bin/sh
set -xeu
/issue.sh
/deploy.sh
exec /usr/local/bin/supercronic /crontab
