#!/bin/bash

# If an envvar for a required host is not set, it is appended to the
# Docker envvar file. This does have the caveat that potentially all
# services end up with all hostname envvars, but they shouldn't be
# conflicting so are simply redundant.
# This *does* expect the `BALENA_TLD` envvar to be set to allow
# the setting of hosts

# List of host envvars used in services.
# TBD:
#  * Sentry DSNs
HOST_ENVVARS=(
    BALENA_API_HOST
    BALENA_UI_HOST
    BALENA_DELTA_HOST
    BALENA_REGISTRY2_HOST
    BALENA_DEVICE_URLS_BASE
    BALENA_GIT_HOST
    BALENA_IMAGE_MAKER_HOST
    BALENA_VPN_HOST
    BALENA_REGISTRY_HOST
    BALENA_TOKEN_AUTH_CERT_ISSUER
    BALENA_ADMIN_HOST
    BALENA_DELTA_S3_HOST
    BALENA_BUILDER_HOST
    BALENA_IMAGE_MAKER_S3_HOST
    BALENA_TOKEN_AUTH_REALM # This is slightly different, needs to be http://api.<uuid>.<tld>/auth/v1/token
    BALENA_TOKEN_AUTH_ISSUER
    BALENA_PROXY_HOST
    BALENA_FILES_HOST
    BALENA_IMAGE_MAKER_S3_HOST
    BALENA_SENTRY_DATABASE_HOST
    BALENA_REDIS_HOST
    BALENA_SENTRY_URL_HOST
)

HOST_VALUES=(
    api
    dashboard
    delta
    registry2
    devices
    git
    img
    vpn
    registry
    api
    admin
    s3
    builder
    s3
    api # This is slightly different, needs to be http://api.<uuid>.<tld>/auth/v1/token
    api
    devices
    files
    s3
    db
    redis
    sentry
)

# Go through the lists and fill in any missing envvars
for index in $(seq 1 ${#HOST_ENVVARS[*]}); do
    VARNAME=${HOST_ENVVARS[$index-1]}
    VARVALUE=${!VARNAME}
    if [[ -z "$VARVALUE" ]]; then
        VARVALUE=${HOST_VALUES[$index-1]}
        SUBDOMAIN="$VARVALUE.$RESIN_DEVICE_UUID.$BALENA_TLD"

        # Several vars require special formatting
        if [ "$VARNAME" == "BALENA_TOKEN_AUTH_REALM" ]; then
            SUBDOMAIN="https://$SUBDOMAIN/auth/v1/token"
        fi

        echo "$VARNAME=$SUBDOMAIN" >> /etc/docker.env
    fi
done
