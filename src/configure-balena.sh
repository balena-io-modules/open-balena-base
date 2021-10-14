#!/usr/bin/env bash
# shellcheck disable=SC2209

set -a

DNS_TLD=${DNS_TLD:-$BALENA_TLD}
ROOT_CA=${ROOT_CA:-$BALENA_ROOT_CA}
CONF=${CONF:-/balena/${DNS_TLD}.env}
CERTS=${CERTS:-/certs}

# all known hostnames
declare -A HOST_ENVVARS
HOST_ENVVARS[ALERTMANAGER_HOST]=alertmanager
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
HOST_ENVVARS[LOKI_HOST]=loki
HOST_ENVVARS[MONITOR_HOST]=monitor
HOST_ENVVARS[PROXY_HOST]=devices
HOST_ENVVARS[REDIS_HOST]=redis
HOST_ENVVARS[REGISTRY_HOST]=registry
HOST_ENVVARS[REGISTRY2_HOST]=registry2
HOST_ENVVARS[SENTRY_DATABASE_HOST]=db
HOST_ENVVARS[SENTRY_REDIS_HOST]=redis
HOST_ENVVARS[SENTRY_URL_HOST]=sentry
HOST_ENVVARS[TOKEN_AUTH_CERT_ISSUER]=api
HOST_ENVVARS[REGISTRY2_TOKEN_AUTH_ISSUER]=api
HOST_ENVVARS[REGISTRY2_TOKEN_AUTH_REALM]=api # This is slightly different, needs to be http://api.<uuid>.<tld>/auth/v1/token
HOST_ENVVARS[UI_HOST]=dashboard
HOST_ENVVARS[VPN_HOST]=vpn

# Sentry DSNs
declare -A SENTRY_ENVVARS
SENTRY_ENVVARS[API_DSN]=2
SENTRY_ENVVARS[BUILDER_DSN]=3
SENTRY_ENVVARS[DELTA_DSN]=4
SENTRY_ENVVARS[BUILDER_DSN]=5
SENTRY_ENVVARS[IMG_DSN]=6
SENTRY_ENVVARS[PROXY_DSN]=7
SENTRY_ENVVARS[UI_DSN]=8
SENTRY_ENVVARS[VPN_DSN]=9

# API keys
declare -A API_KEYS
API_KEYS[API_SERVICE_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[AUTH_RESINOS_REGISTRY_CODE]="$(openssl rand -hex 16)"
API_KEYS[BUILDER_SERVICE_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[COOKIE_SESSION_SECRET]="$(openssl rand -hex 16)"
API_KEYS[DELTA_SERVICE_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[DIGITIZER_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[GEOIP_LICENCE_KEY]="$(openssl rand -hex 16)"
API_KEYS[GEOIP_USER_ID]="$(openssl rand -hex 16)"
API_KEYS[GIT_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[IMG_S3_ACCESS_KEY]="$(openssl rand -hex 16)"
API_KEYS[IMG_S3_SECRET_KEY]="$(openssl rand -hex 16)"
API_KEYS[JF_OAUTH_APP_SECRET]="$(openssl rand -hex 16)"
API_KEYS[JSON_WEB_TOKEN_SECRET]="$(openssl rand -hex 16)"
API_KEYS[MAPS_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[MIXPANEL_TOKEN]="$(openssl rand -hex 16)"
API_KEYS[MONITOR_OAUTH_COOKIE_SECRET]="$(openssl rand -hex 16)"
API_KEYS[MONITOR_SECRET_TOKEN]="$(openssl rand -hex 16)"
API_KEYS[PROXY_SERVICE_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[REGISTRY2_SECRETKEY]="$(openssl rand -hex 16)"
API_KEYS[SENTRY_ADMIN_APIKEY]="$(openssl rand -hex 16)"
API_KEYS[SENTRY_SECRET_KEY]="$(openssl rand -hex 16)"
API_KEYS[TOKEN_AUTH_BUILDER_TOKEN]="$(openssl rand -hex 16)"
API_KEYS[VPN_GUEST_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[VPN_SERVICE_API_KEY]="$(openssl rand -hex 16)"
API_KEYS[API_VPN_SERVICE_API_KEY]="${API_KEYS[API_SERVICE_API_KEY]}"
API_KEYS[DELTA_API_KEY]="${API_KEYS[DELTA_SERVICE_API_KEY]}"
API_KEYS[DELTA_S3_KEY]="${API_KEYS[IMG_S3_ACCESS_KEY]}"
API_KEYS[DELTA_S3_SECRET]="${API_KEYS[IMG_S3_SECRET_KEY]}"
API_KEYS[GIT_SERVICE_API_KEY]="${API_KEYS[GIT_API_KEY]}"
API_KEYS[MDNS_API_TOKEN]="${API_KEYS[PROXY_SERVICE_API_KEY]}"
API_KEYS[REGISTRY2_TOKEN]="${API_KEYS[TOKEN_AUTH_BUILDER_TOKEN]}"
API_KEYS[S3_MINIO_ACCESS_KEY]="${API_KEYS[IMG_S3_ACCESS_KEY]}"
API_KEYS[S3_MINIO_SECRET_KEY]="${API_KEYS[IMG_S3_SECRET_KEY]}"

function upsert_ca_root {
	if test -n "${ROOT_CA}"; then
		echo "Installing custom CA bundle..."
		echo "${ROOT_CA}" | base64 -d > /usr/local/share/ca-certificates/balenaRootCA.crt
	elif [[ -e "${CERTS}/ca-bundle.pem" ]]; then
		cat < "${CERTS}/ca-bundle.pem" > /usr/local/share/ca-certificates/balenaRootCA.crt
		sed -i /^ROOT_CA=/d /etc/docker.env
		echo "ROOT_CA=$(cat < "${CERTS}/ca-bundle.pem" | openssl base64 -A)" >> /etc/docker.env
	else
		echo "Custom CA bundle not found, nothing to do."
	fi

	if [[ -e /usr/local/share/ca-certificates/balenaRootCA.crt ]]; then
		grep -q 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' /etc/docker.env \
		  || echo 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env

		update-ca-certificates
	fi
}

function upsert_api_key {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.key" ]]; then
		replace_env_var TOKEN_AUTH_CERT_KEY \
		  "$(cat < "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.key" | openssl base64 -A)"
	fi
}

function upsert_api_cert {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.pem" ]]; then
		local cert
		cert="$(cat < "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.pem" | openssl base64 -A)"
		replace_env_var TOKEN_AUTH_CERT_PUB "${cert}"
		replace_env_var API_TOKENAUTH_CRT "${cert}"
	fi
}

function upsert_api_kid {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.kid" ]]; then
		replace_env_var TOKEN_AUTH_CERT_KID \
		  "$(cat < "${CERTS}/private/api.${balena_device_uuid}.${dns_tld}.kid" | openssl base64 -A)"
	fi
}

function upsert_vpn_key {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/vpn.${balena_device_uuid}.${dns_tld}.key" ]]; then
		replace_env_var VPN_OPENVPN_SERVER_KEY \
		  "$(cat < "${CERTS}/private/vpn.${balena_device_uuid}.${dns_tld}.key" | openssl base64 -A)"
	fi
}

function upsert_vpn_cert {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/vpn.${balena_device_uuid}.${dns_tld}.pem" ]]; then
		local cert
		cert="$(cat < "${CERTS}/private/vpn.${balena_device_uuid}.${dns_tld}.pem" | openssl base64 -A)"
		replace_env_var VPN_OPENVPN_SERVER_CRT "${cert}"
		replace_env_var VPN_OPENVPN_CA_CRT "${cert}"
	fi
}

function upsert_vpn_dhparams {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -f "${CERTS}/private/dhparam.${balena_device_uuid}.${dns_tld}.pem" ]]; then
		replace_env_var VPN_OPENVPN_SERVER_DH \
		  "$(cat < "${CERTS}/private/dhparam.${balena_device_uuid}.${dns_tld}.pem" | openssl base64 -A)"
	fi
}

function upsert_vpn_ca {
	if [[ -e "${CERTS}/ca-bundle.pem" ]]; then
		replace_env_var DEVICE_CONFIG_OPENVPN_CA \
		  "$(cat < "${CERTS}/ca-bundle.pem" | openssl base64 -A)"
	fi
}

function replace_env_var {
	local ev
	ev="${1}"
	[[ -n "${ev}" ]] || return

	local value
	value="${2// /\\ }"

	[[ -n "${value}" ]] || return

	local varname
	varname="$(echo "${ev}" | awk -F'=' '{print $1}')"
	local varvalue
	varvalue="${!varname}"

	if [[ -z "$varvalue" ]]; then
		sed -i "/^${varname}=/d" /etc/docker.env
		echo "${varname}=${value}" >> /etc/docker.env
	fi
}

function upsert_devices_keys {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -d "${CERTS}/private" ]]; then
		local tmpkeys
		tmpkeys="$(mktemp)"

		local tmpubs
		tmpubs="$(mktemp)"

		# shellcheck disable=SC2043
		for algo in rsa; do
			key="${CERTS}/private/devices.${balena_device_uuid}.${dns_tld}.${algo}.key"
			if [[ -f "${key}" ]]; then
				cat < "${key}" >> "${tmpkeys}"
			fi

			if [[ -f "${key}.pub" ]]; then
				cat < "${key}.pub" >> "${tmpubs}"
			fi
		done

		if [[ -f "${tmpkeys}" ]]; then
			replace_env_var PROXY_SERVICE_DEVICE_KEY \
			  "$(cat < "${tmpkeys}" | openssl base64 -A)"
		fi

		if [[ -f "${tmpubs}" ]]; then
			replace_env_var DEVICE_CONFIG_SSH_AUTHORIZED_KEYS "$(cat < "${tmpubs}")"
		fi

		rm -f "${tmpkeys}" "${tmpubs}"
	fi
}

function upsert_ssh_private_keys {
	local cn
	cn="${1}"
	[[ -n "${cn}" ]] || return

	local balena_device_uuid
	balena_device_uuid="${2}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${3}"
	[[ -n "${dns_tld}" ]] || return

	if [[ -d "${CERTS}/private" ]]; then
		for ev in PROXY_SSH_KEYS_RSA \
		  PROXY_SSH_KEYS_ECDSA \
		  PROXY_SSH_KEYS_DSA \
		  PROXY_SSH_KEYS_ED25519; do
			algo="$(echo "${ev}" | awk '{split($0,arr,"_"); print arr[4]}' | tr '[:upper:]' '[:lower:]')"
			key="${CERTS}/private/${cn}.${balena_device_uuid}.${dns_tld}.${algo}.key"
			if [[ -f "${key}" ]]; then
				replace_env_var "${ev}" "$(cat < "${key}" | openssl base64 -A)"
			fi
		done
	fi
}

function upsert_git_ssh_keys_bundle {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	if [ -d "${CERTS}/private" ]; then
		pushd "${CERTS}/private" || return
		local encoded
		encoded="$(tar --transform "s|.*\.rsa\.key|id_rsa|" \
		  --transform "s|.*\.rsa\.key.pub|id_rsa\.pub|" \
		  --transform "s|.*\.dsa\.key|id_dsa|" \
		  --transform "s|.*\.dsa\.key\.pub|id_dsa\.pub|" \
		  --transform "s|.*\.ecdsa\.key|id_ecdsa|" \
		  --transform "s|.*\.ecdsa\.key\.pub|id_ecdsa\.pub|" \
		  --transform "s|.*\.ed25519\.key|id_ed25519|" \
		  --transform "s|.*\.ed25519\.key\.pub|id_ed25519\.pub|" \
		  -czf - git."${balena_device_uuid}.${dns_tld}".* | openssl base64 -A)"
		replace_env_var GIT_SSHKEYS "${encoded}"
		popd || return
	fi
}

function upsert_all {
	local balena_device_uuid
	balena_device_uuid="${1}"
	[[ -n "${balena_device_uuid}" ]] || return

	local dns_tld
	dns_tld="${2}"
	[[ -n "${dns_tld}" ]] || return

	upsert_api_key "${balena_device_uuid}" "${dns_tld}"
	upsert_api_cert "${balena_device_uuid}" "${dns_tld}"
	upsert_api_kid "${balena_device_uuid}" "${dns_tld}"
	upsert_vpn_ca
	upsert_vpn_key "${balena_device_uuid}" "${dns_tld}"
	upsert_vpn_cert "${balena_device_uuid}" "${dns_tld}"
	upsert_vpn_dhparams "${balena_device_uuid}" "${dns_tld}"
	upsert_devices_keys "${balena_device_uuid}" "${dns_tld}"
	upsert_ssh_private_keys proxy "${balena_device_uuid}" "${dns_tld}"
	upsert_git_ssh_keys_bundle "${balena_device_uuid}" "${dns_tld}"
}

# always run, as the function includes legacy ROOT_CA processing
upsert_ca_root

if [[ -n "${DNS_TLD}" ]]; then
	# inject *_HOST environment variables into local environment
	for VARNAME in "${!HOST_ENVVARS[@]}"; do
		VARVALUE=${!VARNAME}
		if [[ -z "$VARVALUE" ]]; then
			PREFIX="${HOST_ENVVARS[${VARNAME}]}"
			# only prepend BALENA_DEVICE_UUID if running on balenaOS
			DEVICE=""
			if [[ -n "${BALENA_DEVICE_UUID}" ]]; then
				DEVICE="${BALENA_DEVICE_UUID}."
			fi
			SUBDOMAIN="${PREFIX}.${DEVICE}${DNS_TLD}"

			# several environment variables require special formatting
			if [ "$VARNAME" == "BALENA_TOKEN_AUTH_REALM" ] \
			  || [ "$VARNAME" == "REGISTRY2_TOKEN_AUTH_REALM" ]; then
				SUBDOMAIN="https://${SUBDOMAIN}/auth/v1/token"
			fi
			echo "${VARNAME}=${SUBDOMAIN}" >> /etc/docker.env
	  fi
	done

	# inject Sentry environment variables into stack global environment
	for VARNAME in "${!SENTRY_ENVVARS[@]}"; do
		VARVALUE=${!VARNAME}
		if [[ -z "$VARVALUE" ]]; then
			SUFFIX="${SENTRY_ENVVARS[${VARNAME}]}"
			DEVICE=""
			if [[ -n "${BALENA_DEVICE_UUID}" ]]; then
				DEVICE="${BALENA_DEVICE_UUID}."
			fi
			DSN="https://$(openssl rand -hex 16):$(openssl rand -hex 16)@sentry.${DEVICE}${DNS_TLD}/${SUFFIX}"
			grep -q "${VARNAME}" "${CONF}" || echo "${VARNAME}=${DSN}" >> "${CONF}"
		fi
	done

	# inject API keys into stack global environment
	for VARNAME in "${!API_KEYS[@]}"; do
		VARVALUE=${!VARNAME}
		if [[ -z "$VARVALUE" ]]; then
			grep -Eq "^${VARNAME}=" "${CONF}" \
			  || echo "${VARNAME}=${API_KEYS[${VARNAME}]}" >> "${CONF}"
		fi
	done

	# if running on balenaOS, generate keys/certs another way
	if [[ -n "${BALENA_DEVICE_UUID}" ]]; then
		upsert_all "${BALENA_DEVICE_UUID}" "${DNS_TLD}"
	fi
fi

# add stack global environment to system local
if [[ -f "${CONF}" ]]; then
	cat < "${CONF}" | while IFS= read -r EV
	do
		VARNAME="$(echo "${EV}" | awk -F'=' '{print $1}')"
		VARVALUE=${!VARNAME}
		if [[ -z "$VARVALUE" ]]; then
			grep -Eq "^${VARNAME}=" /etc/docker.env || echo "${EV}" >> /etc/docker.env
		fi
	done
fi

# shellcheck disable=SC1091
source /etc/docker.env

/usr/local/bin/confd \
  -onetime \
  -confdir=/usr/src/app/config/confd \
  -backend env
