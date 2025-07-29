#!/usr/bin/env bash
# shellcheck disable=SC2209,SC2207,SC2048

set -a

DNS_TLD=${DNS_TLD:-$BALENA_TLD}

if [[ -n $BALENA_DEVICE_UUID ]]; then
	# prepend the device UUID if running on balenaOS
	TLD="${TLD:-${BALENA_DEVICE_UUID}.${DNS_TLD}}"
else
	TLD="${TLD:-${DNS_TLD}}"
fi

ROOT_CA=${ROOT_CA:-$BALENA_ROOT_CA}
CONF=${CONF:-/balena/${TLD}.env}
CERTS=${CERTS:-/certs}
HOSTS_CONFIG=${HOSTS_CONFIG:-ADMIN_HOST:admin,API_HOST:api,BUILDER_HOST:builder,DELTA_HOST:delta,DELTA_S3_HOST:s3,DEVICE_URLS_BASE:devices,FILES_HOST:files,GIT_HOST:git,GIT_HOSTNAME:git,IMAGE_MAKER_HOST:img,IMAGE_MAKER_S3_HOST:s3,PROXY_HOST:devices,REDIS_HOST:redis,REGISTRY2_HOST:registry2,REGISTRY_PROXY_HOST:registry-proxy,TOKEN_AUTH_CERT_ISSUER:api,REGISTRY2_TOKEN_AUTH_ISSUER:api,REGISTRY2_TOKEN_AUTH_REALM:api,UI_HOST:dashboard,VPN_HOST:cloudlink,WEBRESOURCES_S3_HOST:s3}
TOKENS_CONFIG=${TOKENS_CONFIG:-API_SERVICE_API_KEY:hex,AUTH_RESINOS_REGISTRY_CODE:hex,BUILDER_SERVICE_API_KEY:hex,COOKIE_SESSION_SECRET:hex,DELTA_SERVICE_API_KEY:hex,DIGITIZER_API_KEY:hex,GEOIP_LICENCE_KEY:hex,GEOIP_USER_ID:hex,GIT_API_KEY:hex,IMG_S3_ACCESS_KEY:hex,IMG_S3_SECRET_KEY:hex,JF_OAUTH_APP_SECRET:hex,JSON_WEB_TOKEN_SECRET:hex,MAPS_API_KEY:hex,MIXPANEL_TOKEN:hex,MONITOR_OAUTH_COOKIE_SECRET:hex,MONITOR_SECRET_TOKEN:hex,PROXY_SERVICE_API_KEY:hex,REGISTRY2_SECRETKEY:hex,TOKEN_AUTH_BUILDER_TOKEN:hex,VPN_GUEST_API_KEY:hex,VPN_SERVICE_API_KEY:hex,API_VPN_SERVICE_API_KEY:API_SERVICE_API_KEY,DELTA_API_KEY:DELTA_SERVICE_API_KEY,DELTA_S3_KEY:IMG_S3_ACCESS_KEY,DELTA_S3_SECRET:IMG_S3_SECRET_KEY,GIT_SERVICE_API_KEY:GIT_API_KEY,MDNS_API_TOKEN:PROXY_SERVICE_API_KEY,REGISTRY2_TOKEN:TOKEN_AUTH_BUILDER_TOKEN,S3_MINIO_ACCESS_KEY:IMG_S3_ACCESS_KEY,S3_MINIO_SECRET_KEY:IMG_S3_SECRET_KEY,S3_MINIO_ACCESS_KEY:REGISTRY2_S3_KEY,S3_MINIO_SECRET_KEY:REGISTRY2_S3_SECRET,WEBRESOURCES_S3_ACCESS_KEY:IMG_S3_ACCESS_KEY,WEBRESOURCES_S3_SECRET_KEY:IMG_S3_SECRET_KEY}

declare -A HOST_ENVVARS
hosts_config=($(echo "${HOSTS_CONFIG}" | tr ',' ' '))
for kv in ${hosts_config[*]}; do
	varname="$(echo "${kv}" | awk -F':' '{print $1}')"
	varval="$(echo "${kv}" | awk -F':' '{print $2}')"
	if [[ -n $varname ]] && [[ -n $varval ]]; then
		HOST_ENVVARS[${varname}]="${varval}"
	fi
done

declare -A API_KEYS
tokens_config=($(echo "${TOKENS_CONFIG}" | tr ',' ' '))
for kv in ${tokens_config[*]}; do
	varname="$(echo "${kv}" | awk -F':' '{print $1}')"
	varval="$(echo "${kv}" | awk -F':' '{print $2}')"
	if [[ -n $varname ]] && [[ -n $varval ]]; then
		# replace from runtime environment
		if [[ -n ${!varval} ]]; then
			API_KEYS[${varname}]="${!varval}"
		elif [[ -n ${!varname} ]]; then
			API_KEYS[${varname}]="${!varname}"

		# replace from global environment
		elif grep -qE "^${varname}=.*$" "${CONF}"; then
			varval="$(grep -E "^${varname}=.*$" "${CONF}" | sed -r 's/(^[^=]*)=(.*)$/\2/')"
			if [[ -n $varval ]]; then
				API_KEYS[${varname}]="${varval}"
			fi

		# generate
		elif [[ $varval =~ rand|random|hex ]]; then
			API_KEYS[${varname}]="$(openssl rand -hex 16)"

		# resolve from array
		else
			if [[ -n ${API_KEYS[${varval}]} ]]; then
				API_KEYS[${varname}]="${API_KEYS[${varval}]}"
			fi
		fi
	fi
done

function cleanup() {
   remove_update_lock
}
trap 'cleanup' EXIT

function set_update_lock {
	if [[ -d "$(dirname "${CONF}")" ]]; then
		lockfile "${CONF}.lock"
	fi
}

function check_update_lock() {
	if [[ -d "$(dirname "${CONF}")" ]]; then
		[[ -f "${CONF}.lock" ]] || return 0
		! test -f "${CONF}.lock"
	fi
}

function remove_update_lock() {
	rm -f "${CONF}.lock"
}

function upsert_ca_root {
	# (legacy) explicitly defined ROOT_CA
	if test -n "${ROOT_CA}"; then
		echo "Installing custom CA bundle..."
		echo "${ROOT_CA}" | base64 -d > /usr/local/share/ca-certificates/balenaRootCA.crt
	# dynamically issued by balena-ca
	elif [[ -e "${CERTS}/ca-bundle.pem" ]]; then
		# ... but only if using private certificates
		if [[ "$(readlink -f "${CERTS}/export/chain.pem")" =~ \/private\/ ]]; then
			cat < "${CERTS}/ca-bundle.pem" > /usr/local/share/ca-certificates/balenaRootCA.crt
			sed -i /^ROOT_CA=/d /etc/docker.env
			echo "ROOT_CA=$(cat < "${CERTS}/ca-bundle.pem" | openssl base64 -A)" >> /etc/docker.env
		# ... we are running public DNS/SSL, no need to expose private CA bundle(s)
		else
			echo 'Running LetsEncrypt/ACME/public SSL/DNS configuration.'
		fi
	else
		echo 'Custom CA bundle not found, nothing to do.'
	fi

	if [[ -e /usr/local/share/ca-certificates/balenaRootCA.crt ]]; then
		grep -q 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' /etc/docker.env \
		  || echo 'NODE_EXTRA_CA_CERTS=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env

		grep -q 'CURL_CA_BUNDLE=/etc/ssl/certs/balenaRootCA.pem' /etc/docker.env \
		  || echo 'CURL_CA_BUNDLE=/etc/ssl/certs/balenaRootCA.pem' >> /etc/docker.env

		update-ca-certificates
	fi
}

function upsert_api_key {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${tld}.key" ]]; then
		key="$(cat < "${CERTS}/private/api.${tld}.key" | openssl base64 -A)"
		# (TBC) rename/combine environment variables (JF/balenaCloud)
		replace_env_var TOKEN_AUTH_CERT_KEY "${key}"
		replace_env_var REGISTRY_TOKEN_AUTH_CERT_KEY "${key}"
	fi
}

function upsert_api_cert {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${tld}.pem" ]]; then
		local cert
		cert="$(cat < "${CERTS}/private/api.${tld}.pem" | openssl base64 -A)"
		replace_env_var TOKEN_AUTH_CERT_PUB "${cert}"
		replace_env_var API_TOKENAUTH_CRT "${cert}"
	fi
}

function upsert_api_kid {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/api.${tld}.kid" ]]; then
		keyid="$(cat < "${CERTS}/private/api.${tld}.kid" | openssl base64 -A)"
		# (TBC) rename/combine environment variables (JF/balenaCloud)
		replace_env_var TOKEN_AUTH_CERT_KID "${keyid}"
		replace_env_var REGISTRY_TOKEN_AUTH_CERT_KID "${keyid}"
	fi
}

function upsert_vpn_key {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/vpn.${tld}.key" ]]; then
		replace_env_var VPN_OPENVPN_SERVER_KEY \
		  "$(cat < "${CERTS}/private/vpn.${tld}.key" | openssl base64 -A)"
	fi
}

function upsert_vpn_cert {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/vpn.${tld}.pem" ]]; then
		local cert
		cert="$(cat < "${CERTS}/private/vpn.${tld}.pem" | openssl base64 -A)"
		replace_env_var VPN_OPENVPN_SERVER_CRT "${cert}"
		replace_env_var VPN_OPENVPN_CA_CRT "${cert}"
	fi
}

function upsert_vpn_dhparams {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -f "${CERTS}/private/dhparam.${tld}.pem" ]]; then
		replace_env_var VPN_OPENVPN_SERVER_DH \
		  "$(cat < "${CERTS}/private/dhparam.${tld}.pem" | openssl base64 -A)"
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
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	if [[ -d "${CERTS}/private" ]]; then
		local tmpkeys
		tmpkeys="$(mktemp)"

		local tmpubs
		tmpubs="$(mktemp)"

		# shellcheck disable=SC2043
		for algo in rsa; do
			key="${CERTS}/private/devices.${tld}.${algo}.key"
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

	local tld
	tld="${2}"
	[[ -n "${tld}" ]] || return

	if [[ -d "${CERTS}/private" ]]; then
		for ev in PROXY_SSH_KEYS_RSA \
		  PROXY_SSH_KEYS_ECDSA \
		  PROXY_SSH_KEYS_DSA \
		  PROXY_SSH_KEYS_ED25519; do
			algo="$(echo "${ev}" | awk '{split($0,arr,"_"); print arr[4]}' | tr '[:upper:]' '[:lower:]')"
			key="${CERTS}/private/${cn}.${tld}.${algo}.key"
			if [[ -f "${key}" ]]; then
				replace_env_var "${ev}" "$(cat < "${key}" | openssl base64 -A)"
			fi
		done
	fi
}

function upsert_git_ssh_keys_bundle {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

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
		  -czf - git."${tld}".* | openssl base64 -A)"
		replace_env_var GIT_SSHKEYS "${encoded}"
		popd || return
	fi
}

function upsert_all {
	local tld
	tld="${1}"
	[[ -n "${tld}" ]] || return

	upsert_api_key "${tld}"
	upsert_api_cert "${tld}"
	upsert_api_kid "${tld}"
	upsert_vpn_ca
	upsert_vpn_key "${tld}"
	upsert_vpn_cert "${tld}"
	upsert_vpn_dhparams "${tld}"
	upsert_devices_keys "${tld}"
	upsert_ssh_private_keys proxy "${tld}"
	upsert_git_ssh_keys_bundle "${tld}"
}

# lock to prevent global config corruption due to concurrent updates
until check_update_lock; do echo 'critical section locked, retrying...'; sleep $(((RANDOM%5)+5)); done
set_update_lock

# always run, as the function includes legacy ROOT_CA processing
upsert_ca_root

if [[ -n "${TLD}" ]]; then
	# inject *_HOST environment variables into local environment
	for VARNAME in "${!HOST_ENVVARS[@]}"; do
		VARVALUE=${!VARNAME}
		if [[ -z "$VARVALUE" ]]; then
			PREFIX="${HOST_ENVVARS[${VARNAME}]}"
			SUBDOMAIN="${PREFIX}.${TLD}"

			# several environment variables require special formatting
			if [ "$VARNAME" == "BALENA_TOKEN_AUTH_REALM" ] \
			  || [ "$VARNAME" == "REGISTRY2_TOKEN_AUTH_REALM" ]; then
				SUBDOMAIN="https://${SUBDOMAIN}/auth/v1/token"
			fi
			grep -Eq "^${VARNAME}=" "${CONF}" \
			  || echo "${VARNAME}=${SUBDOMAIN}" >> "${CONF}"
	  fi
	done

	# inject API keys into stack global environment
	for VARNAME in "${!API_KEYS[@]}"; do
		VARVALUE="${API_KEYS[${VARNAME}]}"
		if [[ -n $VARVALUE ]]; then
			grep -Eq "^${VARNAME}=" "${CONF}" || echo "${VARNAME}=${VARVALUE}" >> "${CONF}"
		fi
	done

	upsert_all "${TLD}"
fi

# add stack global environment to system local
if [[ -f "${CONF}" ]]; then
	cat < "${CONF}" | while IFS= read -r EV
	do
		VARNAME="$(echo "${EV}" | sed -r 's/(^[^=]*)=(.*)$/\1/')"
		VARVALUE="$(echo "${EV}" | sed -r 's/(^[^=]*)=(.*)$/\2/')"
		# prefer the local value if there is one
		if [[ -n $VARNAME ]] && [[ -n ${!VARNAME} ]]; then
			VARVALUE=${!VARNAME}
		fi
		if [[ -n $VARNAME ]] && [[ -n $VARVALUE ]]; then
			grep -Eq "^${VARNAME}=" /etc/docker.env || echo "${VARNAME}=${VARVALUE}" >> /etc/docker.env
		fi
	done
fi

# shellcheck disable=SC1091
source /etc/docker.env

/usr/local/bin/confd \
  -onetime \
  -confdir=/usr/src/app/config/confd \
  -backend env
