# shellcheck shell=bash

# Loads environment variables from a file using systemd's EnvironmentFile format.
# Uses xenv which wraps systemd v256's actual parser for exact compatibility.
#
# This was chosen to maintain compatibility when migrating from systemd to s6-overlay.
# systemd's behavior differs from POSIX shell quoting (IEEE Std 1003.1-2017):
# - Single quotes: Everything is literal, backslashes have no special meaning
# - Double quotes: Everything is literal, NO escape processing (diverges from POSIX)
# - Unquoted: Backslashes escape the next character (C-style escapes)
#
# References:
# - xenv tool: https://github.com/michurin/systemd-env-file
# - systemd v256 parser: https://github.com/systemd/systemd/blob/v256/src/basic/env-file.c
# - systemd EnvironmentFile behavior: https://github.com/systemd/systemd/issues/10659
#
# Usage:
#   source /etc/s6-overlay/scripts/functions.sh
#   load_env_file /path/to/env/file
load_env_file() {
    local f="${1}" line key value

    # Use xenv to parse the file with systemd's parser, then export variables
    # We validate variable names to prevent code injection via malicious env files
    while IFS= read -r line; do
        # Split on first = only
        key="${line%%=*}"
        value="${line#*=}"

        # Only process valid variable names (letters, numbers, underscore; must start with letter/underscore)
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        # Directly export the variable without eval to avoid command injection risk
        export "${key}=${value}"
    done < <(XENV="${f}" xenv env)
}

# https://skarnet.org/software/s6/s6-svstat.html
is_up() {
	local service="$1"
	local result
	result="$(s6-svstat -u "/run/service/${service}")"
	test "${result}" = "true"
}
