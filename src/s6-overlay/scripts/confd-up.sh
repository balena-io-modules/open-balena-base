#!/command/with-contenv bash
# shellcheck shell=bash

# Redirect all future stdout/stderr to s6-log
exec > >(exec s6-log p"confd[$$]:" 1 || true) 2>&1

# Populate /etc/docker.env with all container environment variables
for var in $(compgen -e); do
	printf '%q=%q\n' "${var}" "${!var}"
done > /etc/docker.env

exec /etc/s6-overlay/scripts/configure-balena.sh
