#!/usr/bin/env bats

load '/usr/local/lib/node_modules/bats-support/load.bash'
load '/usr/local/lib/node_modules/bats-assert/load.bash'

setup() {
    if [[ ! -f /etc/s6-overlay/scripts/functions.sh ]]; then
        skip "/etc/s6-overlay/scripts/functions.sh not found, skipping tests"
    fi
    
    # Source the functions under test
    # shellcheck disable=SC1091
    source /etc/s6-overlay/scripts/functions.sh

    # Load test environment file
    load_env_file /usr/src/app/tests/fixtures/test.env
}

@test "UNQUOTED: processes escape sequences (backslash-semicolon becomes semicolon)" {
    assert_equal "$UNQUOTED" "balena-images;balena-delta;balena-pine-web-resources"
}

@test "DOUBLE_QUOTED: preserves literal backslashes (systemd behavior, NOT POSIX)" {
    assert_equal "$DOUBLE_QUOTED" 'balena-images\;balena-delta\;balena-pine-web-resources'
}

@test "SINGLE_QUOTED: preserves literal backslashes (no escape processing)" {
    assert_equal "$SINGLE_QUOTED" 'balena-images\;balena-delta\;balena-pine-web-resources'
}

@test "UNQUOTED_SPACE: preserves spaces in unquoted values" {
    assert_equal "$UNQUOTED_SPACE" "value with space"
}

@test "DOUBLE_WITH_TAB: preserves literal backslash-t (systemd behavior, NOT POSIX)" {
    assert_equal "$DOUBLE_WITH_TAB" 'value\twith\ttab'
}

@test "SINGLE_WITH_TAB: preserves literal backslash-t (no processing)" {
    assert_equal "$SINGLE_WITH_TAB" 'value\twith\ttab'
}

@test "DOUBLE_WITH_NEWLINE: preserves literal backslash-n (systemd behavior, NOT POSIX)" {
    assert_equal "$DOUBLE_WITH_NEWLINE" 'line1\nline2'
}

@test "DOUBLE_BACKSLASH: processes escaped backslash at end of value" {
    assert_equal "$DOUBLE_BACKSLASH" 'value\'
}

@test "VALUE_WITH_EQUALS: preserves equals sign in middle of value" {
    assert_equal "$VALUE_WITH_EQUALS" "key=value"
}

@test "EQUALS_AT_END: preserves equals sign at end of value" {
    assert_equal "$EQUALS_AT_END" "ends with="
}

@test "MULTIPLE_EQUALS: preserves multiple equals signs in value" {
    assert_equal "$MULTIPLE_EQUALS" "foo=bar=baz"
}

@test "BASE64_LIKE: preserves base64-style value with trailing equals" {
    assert_equal "$BASE64_LIKE" "dGVzdA=="
}
