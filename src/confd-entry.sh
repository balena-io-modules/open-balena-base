#!/usr/bin/env bash
# shellcheck disable=SC1091

set -xa

# Populate /etc/docker.env with all container environment variables.
# This file is updated by configure-balena.sh with zero-conf certificates
# and other dynamic values, and is sourced before running confd again.
for var in $(compgen -e); do
	printf '%q=%q\n' "${var}" "${!var}"
done > /etc/docker.env

# Run configure-balena to ensure the env is populated with dynamic cert values.
# This is necessary for zero-conf certificate generation.
/usr/bin/configure-balena.sh

# Load environment variables from /etc/docker.env that were populated by configure-balena.sh.
source /etc/docker.env

# Manually run confd once before main process init.
/usr/local/bin/confd \
  -onetime \
  -confdir=/usr/src/app/config/confd \
  -backend env

# If there is a config/env template, source it.
[[ -f /usr/src/app/config/env ]] && source /usr/src/app/config/env

exec "$@"
