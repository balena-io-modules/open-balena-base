#!/usr/bin/env bash

ROOT_CA=${ROOT_CA:-$BALENA_ROOT_CA}

if test -n "${ROOT_CA}"; then
    echo "Installing self-signed balena root CA..."
    echo "${ROOT_CA}" | base64 -d > /usr/local/share/ca-certificates/balenaRootCA.crt
    echo 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env
    update-ca-certificates
elif [[ -f /certs/ca-bundle.pem ]]; then
	echo "Installing self-signed CA bundle..."
	cat < /certs/ca-bundle.pem > /usr/local/share/ca-certificates/balenaRootCA.crt
	grep -q NODE_EXTRA_CA_CERTS /etc/docker.env \
	  || echo 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env
	update-ca-certificates
else
    echo "No self-signed balena root CA found, using defaults..."
fi

# set up a watcher to notify system when certificate bundle is updated
# (TBC) non-systemd variant is not supported with a watcher
if [[ -d /certs ]]; then
	(while true; do
		inotifywait -r -e create -e modify /certs
		echo "(up)serting self-signed CA bundle..."
		[[ -f /certs/ca-bundle.pem ]] \
		  && cat < /certs/ca-bundle.pem > /usr/local/share/ca-certificates/balenaRootCA.crt
		grep -q NODE_EXTRA_CA_CERTS /etc/docker.env \
		  || echo 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env
		update-ca-certificates
		which systemctl && systemctl restart confd.service
		sleep 1s;
	done) &
fi
