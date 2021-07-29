#!/bin/bash

ROOT_CA=${ROOT_CA:-$BALENA_ROOT_CA}

if test -n "${ROOT_CA}"; then
    echo "Installing self-signed balena root CA..."
    echo "${ROOT_CA}" | base64 -d > /usr/local/share/ca-certificates/balenaRootCA.crt
    update-ca-certificates
else
    echo "No self-signed balena root CA found, using defaults..."
fi
