#!/usr/bin/env bats

load '/usr/local/lib/node_modules/bats-support/load.bash'
load '/usr/local/lib/node_modules/bats-assert/load.bash'

setup() {
    if ! command -v xenv >/dev/null 2>&1; then
        skip "xenv command not found, skipping systemd comparison tests"
    fi
    
    export TEST_ENV="/usr/src/app/tests/fixtures/test.env"
    export SYSTEMD_REFERENCE="/usr/src/app/tests/fixtures/systemd-env.txt"
}

# Helper to get all variables from xenv
get_xenv_env() {
    XENV="$TEST_ENV" xenv env
}

# Helper to extract a specific variable value from env output
get_var_from_env() {
    local env_output="$1"
    local var_name="$2"
    echo "$env_output" | grep "^${var_name}=" | cut -d= -f2-
}

# Helper to get variable from systemd reference file
get_systemd_var() {
    local var_name="$1"
    grep "^${var_name}=" "$SYSTEMD_REFERENCE" | cut -d= -f2-
}

@test "systemd vs xenv: UNQUOTED values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "UNQUOTED")
    xenv_value=$(get_var_from_env "$xenv_env" "UNQUOTED")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: DOUBLE_QUOTED values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "DOUBLE_QUOTED")
    xenv_value=$(get_var_from_env "$xenv_env" "DOUBLE_QUOTED")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: SINGLE_QUOTED values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "SINGLE_QUOTED")
    xenv_value=$(get_var_from_env "$xenv_env" "SINGLE_QUOTED")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: UNQUOTED_SPACE values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "UNQUOTED_SPACE")
    xenv_value=$(get_var_from_env "$xenv_env" "UNQUOTED_SPACE")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: DOUBLE_WITH_TAB values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "DOUBLE_WITH_TAB")
    xenv_value=$(get_var_from_env "$xenv_env" "DOUBLE_WITH_TAB")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: SINGLE_WITH_TAB values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "SINGLE_WITH_TAB")
    xenv_value=$(get_var_from_env "$xenv_env" "SINGLE_WITH_TAB")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: DOUBLE_WITH_NEWLINE values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "DOUBLE_WITH_NEWLINE")
    xenv_value=$(get_var_from_env "$xenv_env" "DOUBLE_WITH_NEWLINE")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: DOUBLE_BACKSLASH values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "DOUBLE_BACKSLASH")
    xenv_value=$(get_var_from_env "$xenv_env" "DOUBLE_BACKSLASH")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: VALUE_WITH_EQUALS values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "VALUE_WITH_EQUALS")
    xenv_value=$(get_var_from_env "$xenv_env" "VALUE_WITH_EQUALS")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: EQUALS_AT_END values match (trailing equals test)" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "EQUALS_AT_END")
    xenv_value=$(get_var_from_env "$xenv_env" "EQUALS_AT_END")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: MULTIPLE_EQUALS values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "MULTIPLE_EQUALS")
    xenv_value=$(get_var_from_env "$xenv_env" "MULTIPLE_EQUALS")

    assert_equal "$xenv_value" "$systemd_value"
}

@test "systemd vs xenv: BASE64_LIKE values match" {
    xenv_env=$(get_xenv_env)

    systemd_value=$(get_systemd_var "BASE64_LIKE")
    xenv_value=$(get_var_from_env "$xenv_env" "BASE64_LIKE")

    assert_equal "$xenv_value" "$systemd_value"
}
