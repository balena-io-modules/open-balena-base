#!/usr/bin/env bash

# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -x

USE_CONFD=${USE_CONFD:-$BALENA_USE_CONFD}

if [[ $USE_CONFD -eq 1 ]]; then
  /usr/local/bin/confd \
    -onetime \
    -confdir=/usr/src/app/config/confd \
    -backend env

  set -a; [ -f /usr/src/app/config/env ] && source /usr/src/app/config/env; set +a
fi

/usr/bin/configure-balena-host-envvars.sh

/usr/bin/configure-balena-root-ca.sh

set -a; [ -f /etc/docker.env ] && source /etc/docker.env; set +a

exec "$@"
