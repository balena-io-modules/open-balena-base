#!/usr/bin/env bats

load '/opt/bats/node_modules/bats-support/load.bash'
load '/opt/bats/node_modules/bats-assert/load.bash'

CONTAINER_ENV=/run/s6/container_environment

# Prints the PID of the oldest process with the given name.
pid_of() {
    grep -lx "$1" /proc/[0-9]*/comm | sort -t/ -k3 -n | head -1 | cut -d/ -f3
}

# Prints one variable from the environment of a running process.
proc_env() {
    local pid="$1" name="$2"
    tr '\0' '\n' < "/proc/${pid}/environ" | sed -n "s/^${name}=//p"
}

# The no-init image has no s6, so the suite skips there, like the other suites.
# On the s6 image a missing fixture fails, so the suite cannot pass with zero assertions.
setup() {
    if [[ ! -f /etc/s6-overlay/scripts/s6-init ]]; then
        skip "/etc/s6-overlay/scripts/s6-init not found, skipping tests"
    fi
    assert_equal "$(cat "${CONTAINER_ENV}/DNS_TLD")" "example.test"
}

@test "generated var is in the s6 container environment" {
    run cat "${CONTAINER_ENV}/API_HOST"
    assert_output "api.example.test"
}

@test "preset container var is not overwritten by configure-balena" {
    run cat "${CONTAINER_ENV}/UI_HOST"
    assert_output "preset.example.test"
}

@test "with-contenv process sees generated var" {
    run /command/with-contenv printenv API_HOST
    assert_output "api.example.test"
}

# s6-supervise starts every longrun run script, so its env is what a plain run script inherits.
@test "plain run script does not see generated var" {
    run proc_env "$(pid_of s6-supervise)" API_HOST
    assert_success
    assert_output ""
}

@test "/etc/docker.env sources without error under set -e" {
    run bash -c 'set -e; set -a; source /etc/docker.env'
    assert_success
}

# Values that bash would expand or split if /etc/docker.env held them unquoted.
# shellcheck disable=SC2016
HOSTILE_VALUE='$(touch /tmp/pwned) `touch /tmp/pwned` it'"'"'s "quoted"'
BASE64_VALUE='dGVzdA+/Zm9vYmFy='

# Runs configure-balena.sh in the container env, with CONF and CERTS fixtures from the test tmpdir.
# The script rewrites /etc/docker.env, so back the file up for teardown.
run_configure_balena() {
    [[ -f "${BATS_TEST_TMPDIR}/docker.env.bak" ]] \
        || cp -p /etc/docker.env "${BATS_TEST_TMPDIR}/docker.env.bak"
    /command/with-contenv env \
        CONF="${BATS_TEST_TMPDIR}/conf.env" CERTS="${BATS_TEST_TMPDIR}/certs" \
        /etc/s6-overlay/scripts/configure-balena.sh
}

# Prints one variable after sourcing /etc/docker.env in a clean shell.
docker_env_value() {
    # shellcheck disable=SC2016
    env -i PATH="${PATH}" bash -c 'source /etc/docker.env && printf %s "${!1}"' _ "$1"
}

teardown() {
    rm -f /tmp/pwned
    [[ -f "${BATS_TEST_TMPDIR}/docker.env.bak" ]] || return 0
    cp -p "${BATS_TEST_TMPDIR}/docker.env.bak" /etc/docker.env
}

@test "CONF values stay literal in /etc/docker.env" {
    mkdir -p "${BATS_TEST_TMPDIR}/certs"
    printf 'TEST_HOSTILE=%s\nTEST_BASE64=%s\n' "${HOSTILE_VALUE}" "${BASE64_VALUE}" \
        > "${BATS_TEST_TMPDIR}/conf.env"
    run_configure_balena

    run docker_env_value TEST_HOSTILE
    assert_output "${HOSTILE_VALUE}"
    run docker_env_value TEST_BASE64
    assert_output "${BASE64_VALUE}"
    assert [ ! -e /tmp/pwned ]
}

@test "CONF file keeps raw KEY=VALUE lines" {
    mkdir -p "${BATS_TEST_TMPDIR}/certs"
    printf 'TEST_HOSTILE=%s\n' "${HOSTILE_VALUE}" > "${BATS_TEST_TMPDIR}/conf.env"
    run_configure_balena

    run grep -x "TEST_HOSTILE=${HOSTILE_VALUE}" "${BATS_TEST_TMPDIR}/conf.env"
    assert_success
}

@test "rerun writes each CONF var once" {
    mkdir -p "${BATS_TEST_TMPDIR}/certs"
    printf 'TEST_HOSTILE=%s\n' "${HOSTILE_VALUE}" > "${BATS_TEST_TMPDIR}/conf.env"
    run_configure_balena
    run_configure_balena

    run grep -c '^TEST_HOSTILE=' /etc/docker.env
    assert_output "1"
}

# replace_env_var copies the public key file as-is, so newlines reach the helper.
@test "replace_env_var values stay literal in /etc/docker.env" {
    mkdir -p "${BATS_TEST_TMPDIR}/certs/private"
    printf '%s\nssh-rsa AAAA second key\n' "${HOSTILE_VALUE}" \
        > "${BATS_TEST_TMPDIR}/certs/private/devices.example.test.rsa.key.pub"
    : > "${BATS_TEST_TMPDIR}/conf.env"
    run_configure_balena

    run docker_env_value PROXY_PUBLIC_KEYS
    assert_output "${HOSTILE_VALUE}"$'\n'"ssh-rsa AAAA second key"
    assert [ ! -e /tmp/pwned ]
}
