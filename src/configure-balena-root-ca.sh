#!/bin/bash
if test -n "${BALENA_ROOT_CA}"; then
    echo "Installing self-signed balena root CA..."
    echo "${BALENA_ROOT_CA}" | base64 -d > /usr/local/share/ca-certificates/balenaRootCA.crt
    update-ca-certificates
else
    echo "No self-signed balena root CA found, using defaults..."
fi
