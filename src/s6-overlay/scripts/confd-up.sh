#!/command/with-contenv bash
# shellcheck shell=bash

# Populate /etc/docker.env with all container environment variables
for var in $(compgen -e); do
	printf '%q=%q\n' "${var}" "${!var}"
done > /etc/docker.env

exec /etc/s6-overlay/scripts/configure-balena.sh
