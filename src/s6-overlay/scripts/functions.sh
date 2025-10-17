# shellcheck shell=bash

# Process C-style escape sequences in a string.
# Handles \n, \t, \r, \a, \b, \f, \v, and backslash-escaped characters.
_process_escapes() {
    local input="$1" output="" i=0 c next_c
    while [[ $i -lt ${#input} ]]; do
        c="${input:$i:1}"
        if [[ "$c" == "\\" ]] && [[ $((i + 1)) -lt ${#input} ]]; then
            i=$((i + 1))
            next_c="${input:$i:1}"
            case "$next_c" in
                n) output="${output}"$'\n' ;;
                t) output="${output}"$'\t' ;;
                r) output="${output}"$'\r' ;;
                a) output="${output}"$'\a' ;;
                b) output="${output}"$'\b' ;;
                f) output="${output}"$'\f' ;;
                v) output="${output}"$'\v' ;;
                *) output="${output}${next_c}" ;;  # Backslash escapes any other character
            esac
        else
            output="${output}${c}"
        fi
        i=$((i + 1))
    done
    echo "${output}"
}

# Replicates systemd's EnvironmentFile behavior following POSIX shell quoting rules.
# Follows IEEE Std 1003.1-2017, sections 2.2.1-2.2.3 for escape sequence processing:
# - Single quotes: Everything is literal, backslashes have no special meaning
# - Double quotes: Backslashes escape the next character (C-style escapes)
# - Unquoted: Backslashes escape the next character (C-style escapes)
#
# References:
# - systemd EnvironmentFile escape behavior: https://github.com/systemd/systemd/issues/10659
# - systemd PR #11427: Follow shell syntax for escape in quotes
# - IEEE Std 1003.1-2017, sections 2.2.1-2.2.3
#
# Usage:
#   source /etc/s6-overlay/scripts/functions.sh
#   load_env_file /path/to/env/file
load_env_file() {
    local f="${1}" line key value

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comments and blank lines, parse KEY=VALUE
        [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]] || continue

        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # Handle quoting following POSIX rules
        if [[ "${value}" =~ ^\"(.*)\"$ ]]; then
            # Double quotes: process escape sequences
            value="$(_process_escapes "${BASH_REMATCH[1]}")"
        elif [[ "${value}" =~ ^\'(.*)\'$ ]]; then
            # Single quotes: literal, no escape processing
            value="${BASH_REMATCH[1]}"
        else
            # Unquoted: process escape sequences
            value="$(_process_escapes "${value}")"
        fi

        export "${key}=${value}"
    done < "${f}"
}

# https://skarnet.org/software/s6/s6-svstat.html
is_up() {
	local service="$1"
	local result
	result="$(s6-svstat -u "/run/service/${service}")"
	test "${result}" = "true"
}
