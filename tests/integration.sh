#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/foxly-motd-test.XXXXXXXX")
ROOT="$TEST_DIR/root"
trap 'rm -rf -- "$TEST_DIR"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}
assert_file() { [[ -f "$1" ]] || fail "Missing file: $1"; }
assert_contains() { grep -Fq "$2" "$1" || fail "$1 does not contain: $2"; }

printf 'Test: clean installation\n'
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --no-refresh --no-timers
assert_file "$ROOT/usr/local/sbin/foxly-motd"
assert_file "$ROOT/etc/update-motd.d/00-foxly-header"
assert_file "$ROOT/etc/update-motd.d/10-foxly-sysinfo"
assert_file "$ROOT/etc/default/foxly-motd"
assert_file "$ROOT/etc/systemd/system/foxly-motd-cache.timer"
assert_contains "$ROOT/var/lib/foxly-motd/version" dev

printf 'Test: status and preview\n'
FOXLY_MOTD_ROOT="$ROOT" "$ROOT/usr/local/sbin/foxly-motd" status > "$TEST_DIR/status"
assert_contains "$TEST_DIR/status" 'Installed version: dev'
sed -i.bak 's/^SHOW_DOCKER=.*/SHOW_DOCKER=no/; s/^COLOR_MODE=.*/COLOR_MODE=never/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
FOXLY_MOTD_ROOT="$ROOT" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/usr/local/sbin/foxly-motd" preview > "$TEST_DIR/preview"
assert_contains "$TEST_DIR/preview" Systeminformationen

printf 'Test: configuration preservation and backup\n'
printf '\nCUSTOM_SETTING=preserved\n' >> "$ROOT/etc/default/foxly-motd"
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --upgrade --no-refresh --no-timers
assert_contains "$ROOT/etc/default/foxly-motd" CUSTOM_SETTING=preserved
find "$ROOT/var/backups/foxly-motd" -type f -name '*.tar.gz' -print -quit | grep -q . || fail 'Upgrade backup missing'

printf 'Test: package cache generation\n'
MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/flock" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$MOCK_BIN/apt-get" << 'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" -s upgrade "* ]]; then
    cat <<'OUT'
Inst openssl [1.0] (1.1 Debian-Security:stable-security [amd64])
Inst curl [1.0] (1.1 Debian:stable [amd64])
Inst linux-image [1.0] (1.1 Debian-Security:stable-security [amd64])
OUT
fi
EOF
chmod +x "$MOCK_BIN/flock" "$MOCK_BIN/apt-get"
PATH="$MOCK_BIN:$PATH" FOXLY_MOTD_CACHE_DIR="$TEST_DIR/cache" \
    FOXLY_MOTD_CACHE_LOCK="$TEST_DIR/cache.lock" "$PROJECT_DIR/libexec/foxly-motd-cache"
assert_contains "$TEST_DIR/cache/packages" updates=3
assert_contains "$TEST_DIR/cache/packages" security=2

printf 'Test: uninstall retains configuration and backups\n'
FOXLY_MOTD_ROOT="$ROOT" "$ROOT/usr/local/sbin/foxly-motd" uninstall
[[ ! -e "$ROOT/usr/local/sbin/foxly-motd" ]] || fail 'CLI was not removed'
assert_file "$ROOT/etc/default/foxly-motd"
find "$ROOT/var/backups/foxly-motd" -type f -name '*.tar.gz' -print -quit | grep -q . || fail 'Backups were removed'

printf 'All integration tests passed.\n'
