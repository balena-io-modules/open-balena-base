#!/usr/bin/env bash

if [[ "$BALENA_USE_CONFD" = "1" ]]; then
  # When this environment variable is set, we need to pull configuration from etcd.
  # The image is expected to have an environment file template located in /etc/confd,
  # and this template should be configured to rencer the actual file to /balena/env.
  /usr/local/bin/confd -onetime -node http://172.17.42.1:4001 || exit 1
  set -a
  source /balena/env || exit 1
  set +a
fi

# Set some typical missing env variables (like BALENA_API_HOST) deriving them from BALENA_TLD.
# Used in BoB.
/usr/bin/configure-balena-host-envvars.sh

set -a
# It's an optional step, ok to fail.
source /etc/docker.env 2>/dev/null && echo "info: Missing typical variables are set using BALENA_TLD"
set +a

if [[ "$CONFD_BACKEND" = "ENV" ]]; then
  /usr/local/bin/confd -onetime -confdir=/usr/src/app/config/confd -backend env || exit 1
  set -a
  source /usr/src/app/config/env >/dev/null && echo "info: Sourcing /usr/src/app/config/env"
  set +a
fi

exec $@
