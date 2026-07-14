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
assert_matches() { grep -Eq "$2" "$1" || fail "$1 does not match: $2"; }

printf 'Test: clean installation\n'
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --language de --no-refresh --no-timers
assert_file "$ROOT/usr/local/sbin/foxly-motd"
assert_file "$ROOT/etc/update-motd.d/00-foxly-header"
assert_file "$ROOT/etc/update-motd.d/10-foxly-sysinfo"
assert_file "$ROOT/etc/default/foxly-motd"
assert_file "$ROOT/etc/systemd/system/foxly-motd-cache.timer"
assert_contains "$ROOT/var/lib/foxly-motd/version" dev
assert_contains "$ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=de
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --no-refresh --no-timers
assert_contains "$ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=de

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

printf 'Test: English and automatic language selection\n'
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=en/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
FOXLY_MOTD_ROOT="$ROOT" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/usr/local/sbin/foxly-motd" preview > "$TEST_DIR/preview-en"
assert_contains "$TEST_DIR/preview-en" 'System information at'
assert_contains "$TEST_DIR/preview-en" 'Operating system'
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=auto/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
LC_ALL=de_DE.UTF-8 LANG=de_DE.UTF-8 FOXLY_MOTD_ROOT="$ROOT" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/usr/local/sbin/foxly-motd" preview > "$TEST_DIR/preview-auto-de"
assert_contains "$TEST_DIR/preview-auto-de" Systeminformationen

printf 'Test: fixed dashboard columns, multiple IPs, and memory usage\n'
LAYOUT_BIN="$TEST_DIR/layout-bin"
mkdir -p "$LAYOUT_BIN"
cat > "$LAYOUT_BIN/ip" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-o link show' ]]; then
    printf '1: lo: <LOOPBACK>\n2: eth0: <UP>\n3: eth1: <UP>\n'
elif [[ "$*" == *'dev eth0'* ]]; then
    printf '2: eth0 inet 192.0.2.10/24 scope global eth0\n'
elif [[ "$*" == *'dev eth1'* ]]; then
    printf '3: eth1 inet 198.51.100.20/24 scope global eth1\n'
fi
EOF
chmod +x "$LAYOUT_BIN/ip"
cat > "$TEST_DIR/meminfo" << 'EOF'
MemTotal:        1000 kB
MemFree:          100 kB
MemAvailable:     400 kB
Buffers:           50 kB
Cached:           200 kB
SwapTotal:        200 kB
SwapFree:         150 kB
EOF
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=de/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
PATH="$LAYOUT_BIN:$PATH" \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    SSH_CONNECTION='203.0.113.5 12345 192.0.2.10 22' \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout"
assert_contains "$TEST_DIR/layout" 'eth0: 192.0.2.10'
assert_contains "$TEST_DIR/layout" 'eth1: 198.51.100.20'
assert_matches "$TEST_DIR/layout" '^RAM benutzt: +60,0%'
assert_matches "$TEST_DIR/layout" 'Swap benutzt: +25,0%'
assert_matches "$TEST_DIR/layout" 'Remote Host: +203.0.113.5'
right_column=$(awk '/Systemlaufzeit:/ {print index($0, "Systemlaufzeit:")}' "$TEST_DIR/layout")
user_column=$(awk '/Aktueller Nutzer:/ {print index($0, "Aktueller Nutzer:")}' "$TEST_DIR/layout")
remote_column=$(awk '/Remote Host:/ {print index($0, "Remote Host:")}' "$TEST_DIR/layout")
[[ "$right_column" == 52 ]] || fail "Systemlaufzeit starts in column $right_column instead of 52"
[[ "$user_column" == "$right_column" ]] || fail 'Aktueller Nutzer is not aligned with the right column'
[[ "$remote_column" == "$right_column" ]] || fail 'Remote Host is not aligned with Aktueller Nutzer'
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=auto/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"

printf 'Test: configuration preservation and backup\n'
printf '\nCUSTOM_SETTING=preserved\n' >> "$ROOT/etc/default/foxly-motd"
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --upgrade --no-refresh --no-timers
assert_contains "$ROOT/etc/default/foxly-motd" CUSTOM_SETTING=preserved
assert_contains "$ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=auto
find "$ROOT/var/backups/foxly-motd" -type f -name '*.tar.gz' -print -quit | grep -q . || fail 'Upgrade backup missing'

printf 'Test: recognized legacy migration\n'
LEGACY_ROOT="$TEST_DIR/legacy-root"
mkdir -p "$LEGACY_ROOT/etc/update-motd.d"
cat > "$LEGACY_ROOT/etc/update-motd.d/00-header" << 'EOF'
#!/bin/sh
# 00-header
figlet -f slant "$(hostname)" | /usr/local/bin/lolcat -f
EOF
cat > "$LEGACY_ROOT/etc/update-motd.d/10-sysinfo" << 'EOF'
#!/bin/bash
de_uptime() { :; }
SHOW_CONTAINER_SUMMARY=1
printf 'Systeminformationen am %s\n' "$(date)"
EOF
chmod +x "$LEGACY_ROOT/etc/update-motd.d/00-header" "$LEGACY_ROOT/etc/update-motd.d/10-sysinfo"
FOXLY_MOTD_ROOT="$LEGACY_ROOT" bash "$PROJECT_DIR/install.sh" --language en --no-refresh --no-timers
[[ ! -e "$LEGACY_ROOT/etc/update-motd.d/00-header" ]] || fail 'Legacy header was not migrated'
[[ ! -e "$LEGACY_ROOT/etc/update-motd.d/10-sysinfo" ]] || fail 'Legacy sysinfo was not migrated'
assert_file "$LEGACY_ROOT/var/lib/foxly-motd/legacy-migration"
assert_contains "$LEGACY_ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=en
legacy_archive=$(find "$LEGACY_ROOT/var/backups/foxly-motd" -name 'legacy-*.tar.gz' -print -quit)
[[ -n "$legacy_archive" ]] || fail 'Legacy backup missing'
tar -tzf "$legacy_archive" | grep -q 'etc/update-motd.d/00-header' || fail 'Legacy header missing from backup'

printf 'Test: unrelated legacy filename is preserved\n'
FOREIGN_ROOT="$TEST_DIR/foreign-root"
mkdir -p "$FOREIGN_ROOT/etc/update-motd.d"
printf '#!/bin/sh\nprintf "Vendor MOTD\\n"\n' > "$FOREIGN_ROOT/etc/update-motd.d/00-header"
chmod +x "$FOREIGN_ROOT/etc/update-motd.d/00-header"
FOXLY_MOTD_ROOT="$FOREIGN_ROOT" bash "$PROJECT_DIR/install.sh" --language en --no-refresh --no-timers 2> "$TEST_DIR/foreign-warning"
assert_file "$FOREIGN_ROOT/etc/update-motd.d/00-header"
assert_contains "$TEST_DIR/foreign-warning" 'not recognized as Foxly MOTD'
FOXLY_MOTD_ROOT="$FOREIGN_ROOT" bash "$PROJECT_DIR/install.sh" --upgrade --migrate-legacy force --no-refresh --no-timers
[[ ! -e "$FOREIGN_ROOT/etc/update-motd.d/00-header" ]] || fail 'Forced legacy migration did not remove reviewed file'
find "$FOREIGN_ROOT/var/backups/foxly-motd" -name 'legacy-*.tar.gz' -print -quit | grep -q . || fail 'Forced migration backup missing'

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
