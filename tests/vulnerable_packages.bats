#!/usr/bin/env bats

load '/usr/local/lib/node_modules/bats-support/load.bash'
load '/usr/local/lib/node_modules/bats-assert/load.bash'

# Fails if the installed version is older than the given fixed version.
assert_version_at_least() {
    local name="$1"
    local installed_version="$2"
    local fixed_version="$3"

    if ! dpkg --compare-versions "$installed_version" ge "$fixed_version"; then
        fail "$name $installed_version is vulnerable, expected >= $fixed_version"
    fi
}

# Skips if the Debian package is not installed, so a typo or a package rename
# shows up as "# skip" rather than a silent pass.
assert_deb_version_at_least() {
    local package="$1"
    local fixed_version="$2"
    local installed_version

    if ! installed_version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null); then
        skip "$package not installed"
    fi

    assert_version_at_least "$package" "$installed_version" "$fixed_version"
}

# CVE-2026-111497: Brotli decoder out-of-bounds write.
# libbrotli1 is pulled in by curl via libcurl4t64.
# The fixed version differs per Debian release, so any release without a known
# fix fails until a floor is added here.
# https://security-tracker.debian.org/tracker/CVE-2026-111497
@test "CVE-2026-111497: libbrotli1 is patched" {
    local codename fixed_version
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

    case "$codename" in
        bookworm) fixed_version="1.0.9-2+deb12u1" ;;
        trixie) fixed_version="1.1.0-2+deb13u1" ;;
        *) fail "No fixed libbrotli1 version known for Debian $codename" ;;
    esac

    assert_deb_version_at_least libbrotli1 "$fixed_version"
}

# Node.js bundles its own copy of brotli in node:zlib.
# https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
@test "CVE-2026-111497: Node.js bundled brotli is patched" {
    assert_version_at_least "Node.js" "$(node -p 'process.versions.node')" "26.12.1"
}
