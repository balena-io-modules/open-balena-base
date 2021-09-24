#!/usr/bin/env bash
# shellcheck disable=SC1091

set -xa

[[ -f /usr/bin/configure-balena.sh ]] && /usr/bin/configure-balena.sh
[[ -f /etc/docker.env ]] && source /etc/docker.env
[[ -f /usr/src/app/config/env ]] && source /usr/src/app/config/env

exec "$@"
