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
declare -A HOST_ENVVARS

export BALENA_TLD=${BALENA_TLD:-${DNS_TLD}}

# (TBC) deprecate when all BALENA_ references are removed
HOST_ENVVARS[BALENA_ADMIN_HOST]=admin
HOST_ENVVARS[BALENA_API_HOST]=api
HOST_ENVVARS[BALENA_BUILDER_HOST]=builder
HOST_ENVVARS[BALENA_DELTA_HOST]=delta
HOST_ENVVARS[BALENA_DELTA_S3_HOST]=s3
HOST_ENVVARS[BALENA_DEVICE_URLS_BASE]=devices
HOST_ENVVARS[BALENA_FILES_HOST]=files
HOST_ENVVARS[BALENA_GIT_HOST]=git
HOST_ENVVARS[BALENA_GIT_HOSTNAME]=git
HOST_ENVVARS[BALENA_IMAGE_MAKER_HOST]=img
HOST_ENVVARS[BALENA_IMAGE_MAKER_S3_HOST]=s3
HOST_ENVVARS[BALENA_IMAGE_MAKER_S3_HOST]=s3
HOST_ENVVARS[BALENA_MONITOR_HOST]=monitor
HOST_ENVVARS[BALENA_PROXY_HOST]=devices
HOST_ENVVARS[BALENA_REDIS_HOST]=redis
HOST_ENVVARS[BALENA_REGISTRY_HOST]=registry
HOST_ENVVARS[BALENA_REGISTRY2_HOST]=registry2
HOST_ENVVARS[BALENA_SENTRY_DATABASE_HOST]=db
HOST_ENVVARS[BALENA_SENTRY_URL_HOST]=sentry
HOST_ENVVARS[BALENA_TOKEN_AUTH_CERT_ISSUER]=api
HOST_ENVVARS[BALENA_TOKEN_AUTH_ISSUER]=api
HOST_ENVVARS[BALENA_TOKEN_AUTH_REALM]=api # This is slightly different, needs to be http://api.<uuid>.<tld>/auth/v1/token
HOST_ENVVARS[BALENA_UI_HOST]=dashboard
HOST_ENVVARS[BALENA_VPN_HOST]=vpn

# hostnames wthout BALENA_ prefix
HOST_ENVVARS[ADMIN_HOST]=admin
HOST_ENVVARS[API_HOST]=api
HOST_ENVVARS[BUILDER_HOST]=builder
HOST_ENVVARS[DELTA_HOST]=delta
HOST_ENVVARS[DELTA_S3_HOST]=s3
HOST_ENVVARS[DEVICE_URLS_BASE]=devices
HOST_ENVVARS[FILES_HOST]=files
HOST_ENVVARS[GIT_HOST]=git
HOST_ENVVARS[GIT_HOSTNAME]=git
HOST_ENVVARS[IMAGE_MAKER_HOST]=img
HOST_ENVVARS[IMAGE_MAKER_S3_HOST]=s3
HOST_ENVVARS[IMAGE_MAKER_S3_HOST]=s3
HOST_ENVVARS[MONITOR_HOST]=monitor
HOST_ENVVARS[PROXY_HOST]=devices
HOST_ENVVARS[REDIS_HOST]=redis
HOST_ENVVARS[REGISTRY_HOST]=registry
HOST_ENVVARS[REGISTRY2_HOST]=registry2
HOST_ENVVARS[SENTRY_DATABASE_HOST]=db
HOST_ENVVARS[SENTRY_URL_HOST]=sentry
HOST_ENVVARS[TOKEN_AUTH_CERT_ISSUER]=api
HOST_ENVVARS[REGISTRY2_TOKEN_AUTH_ISSUER]=api
HOST_ENVVARS[REGISTRY2_TOKEN_AUTH_REALM]=api # This is slightly different, needs to be http://api.<uuid>.<tld>/auth/v1/token
HOST_ENVVARS[UI_HOST]=dashboard
HOST_ENVVARS[VPN_HOST]=vpn

# Go through the lists and fill in any missing envvars
if [[ -n "$BALENA_TLD" ]]; then
  for VARNAME in "${!HOST_ENVVARS[@]}"; do
      VARVALUE=${!VARNAME}
      if [[ -z "$VARVALUE" ]]; then
          PREFIX="${HOST_ENVVARS[$VARNAME]}"
          # Only use BALENA_DEVICE_UUID if it actually exists, else just use the
          # full passed in TLD
          DEVICE=""
          if [[ ! -z "$BALENA_DEVICE_UUID" ]]; then
              DEVICE="$BALENA_DEVICE_UUID."
          fi
          SUBDOMAIN="$PREFIX.$DEVICE$BALENA_TLD"

          # Several vars require special formatting
          if [ "$VARNAME" == "BALENA_TOKEN_AUTH_REALM" ] \
            || [ "$VARNAME" == "REGISTRY2_TOKEN_AUTH_REALM" ]; then
              SUBDOMAIN="https://$SUBDOMAIN/auth/v1/token"
          fi

          echo "$VARNAME=$SUBDOMAIN" >> /etc/docker.env
      fi
  done
fi
