#!/usr/bin/env bats

load '/usr/local/lib/node_modules/bats-support/load.bash'
load '/usr/local/lib/node_modules/bats-assert/load.bash'

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
