# shellcheck shell=bash

# Replicates systemd's EnvironmentFile behavior of treating everything after '=' as the complete value.
# Usage:
#   source /etc/s6-overlay/scripts/functions.sh 
#   load_env_file /path/to/env/file
load_env_file() {
    local f="${1}" l k v
    while IFS= read -r l || [[ -n "${l}" ]]; do
        [[ "${l}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]] || continue
        k="${BASH_REMATCH[1]}" v="${BASH_REMATCH[2]}"
        if [[ "${v}" =~ ^\"(.*)\"$ ]]; then
            v="${BASH_REMATCH[1]}"
        elif [[ "${v}" =~ ^\'(.*)\'$ ]]; then
            v="${BASH_REMATCH[1]}"
        fi
        export "${k}=${v}"
    done < "${f}" 2>/dev/null
}

# https://skarnet.org/software/s6/s6-svstat.html
is_up() {
	local service="$1"
	local result
	result="$(s6-svstat -u "/run/service/${service}")"
	test "${result}" = "true"
}
