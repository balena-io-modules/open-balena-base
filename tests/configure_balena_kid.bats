#!/usr/bin/env bats

load '/opt/bats/node_modules/bats-support/load.bash'
load '/opt/bats/node_modules/bats-assert/load.bash'

# Token-auth key ID (kid) generation in configure-balena.sh (upsert_api_kid).
# The API signs tokens with this kid and the registry matches it, so both must
# derive it the same way from api.${TLD}.pem.

CONFIGURE_BALENA=/etc/s6-overlay/scripts/configure-balena.sh
FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
# Matches DNS_TLD in docker-compose.test.yml.
TEST_TLD=example.test

# Expected kids for the fixture certificates, computed with the original
# balena-io/cert-manager _keyid.js (v0.5.3, commit 6a888da2b7fb):
# https://github.com/balena-io/cert-manager/blob/6a888da2b7fbe5b173c2d42f82632dc8cfd9e26c/_keyid.js
RSA_KID=CKJE:EWBE:KV7P:ZFZF:LNXL:65XK:2O5S:ZOEW:SH7P:WHSH:DGRB:OTLP
EC_KID=4BGT:SFC4:DP3O:LO5Q:O4J7:NDGE:Y3OF:ECM7:C3VF:CEBG:U3FH:W2LY

setup() {
    if [[ ! -f "${CONFIGURE_BALENA}" ]]; then
        skip "${CONFIGURE_BALENA} not found, skipping tests"
    fi
    PRIVATE="${BATS_TEST_TMPDIR}/certs/private"
    mkdir -p "${PRIVATE}"
    : > "${BATS_TEST_TMPDIR}/conf.env"
}

# Installs a fixture as api.${TEST_TLD}.pem. Fixtures hold certificates only,
# so the tests also show the kid never needs the private key.
use_api_cert() {
    cp "${FIXTURES}/api.${TEST_TLD}.$1.pem" "${PRIVATE}/api.${TEST_TLD}.pem"
}

# Runs configure-balena.sh in the container env, with CONF and CERTS fixtures from the test tmpdir.
# Extra NAME=VALUE arguments are added to its environment.
# The script rewrites /etc/docker.env, so back the file up for teardown.
run_configure_balena() {
    [[ -f "${BATS_TEST_TMPDIR}/docker.env.bak" ]] \
        || cp -p /etc/docker.env "${BATS_TEST_TMPDIR}/docker.env.bak"
    /command/with-contenv env \
        CONF="${BATS_TEST_TMPDIR}/conf.env" CERTS="${BATS_TEST_TMPDIR}/certs" "$@" \
        "${CONFIGURE_BALENA}"
}

# Prints one variable after sourcing /etc/docker.env in a clean shell.
docker_env_value() {
    # shellcheck disable=SC2016
    env -i PATH="${PATH}" bash -c 'source /etc/docker.env && printf %s "${!1}"' _ "$1"
}

# Asserts both kid variables hold the given kid, base64-encoded without a newline.
assert_kid() {
    local expected
    expected="$(printf '%s' "$1" | base64 -w0)"
    run docker_env_value TOKEN_AUTH_CERT_KID
    assert_output "${expected}"
    run docker_env_value REGISTRY_TOKEN_AUTH_CERT_KID
    assert_output "${expected}"
}

# Asserts neither kid variable is set.
refute_kid() {
    run docker_env_value TOKEN_AUTH_CERT_KID
    assert_output ""
    run docker_env_value REGISTRY_TOKEN_AUTH_CERT_KID
    assert_output ""
}

teardown() {
    [[ -f "${BATS_TEST_TMPDIR}/docker.env.bak" ]] || return 0
    cp -p "${BATS_TEST_TMPDIR}/docker.env.bak" /etc/docker.env
}

@test "kid from an RSA certificate matches the original _keyid.js" {
    use_api_cert rsa
    run_configure_balena

    assert_kid "${RSA_KID}"
}

@test "kid from an EC certificate matches the original _keyid.js" {
    use_api_cert ec
    run_configure_balena

    assert_kid "${EC_KID}"
}

@test "kid from a certificate chain uses the first (leaf) certificate" {
    use_api_cert chain
    run_configure_balena

    assert_kid "${RSA_KID}"
}

@test "kid already set in the env is not overwritten" {
    use_api_cert rsa
    run_configure_balena TOKEN_AUTH_CERT_KID=preset

    # configure-balena.sh leaves a var that is already set out of /etc/docker.env.
    run docker_env_value TOKEN_AUTH_CERT_KID
    assert_output ""
    # A var that is not set is still generated.
    run docker_env_value REGISTRY_TOKEN_AUTH_CERT_KID
    assert_output "$(printf '%s' "${RSA_KID}" | base64 -w0)"
}

@test "existing api kid file takes precedence over the pem" {
    use_api_cert rsa
    printf 'FROM:KID:FILE' > "${PRIVATE}/api.${TEST_TLD}.kid"
    run_configure_balena

    assert_kid "FROM:KID:FILE"
}

# If openssl fails, hashing its empty output would give a valid-looking kid,
# so make sure a bad certificate cannot get that far.
@test "invalid api pem logs an error and sets no kid" {
    printf 'not a certificate\n' > "${PRIVATE}/api.${TEST_TLD}.pem"
    run run_configure_balena
    assert_output --partial "Failed to generate key ID from ${PRIVATE}/api.${TEST_TLD}.pem"

    refute_kid
}

# Components without an API certificate must not get kid errors in their logs.
@test "no api pem or kid sets no kid and logs no error" {
    run run_configure_balena
    refute_output --partial "Failed to generate key ID"

    refute_kid
}
