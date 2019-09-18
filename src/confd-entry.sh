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

exec $@
