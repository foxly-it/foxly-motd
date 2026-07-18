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
assert_not_contains() { grep -Fq "$2" "$1" && fail "$1 unexpectedly contains: $2" || return 0; }

printf 'Test: clean installation\n'
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --language de --no-refresh --no-timers
assert_file "$ROOT/usr/local/sbin/foxly-motd"
assert_file "$ROOT/etc/update-motd.d/00-foxly-header"
assert_file "$ROOT/etc/update-motd.d/10-foxly-sysinfo"
assert_file "$ROOT/etc/default/foxly-motd"
assert_file "$ROOT/etc/systemd/system/foxly-motd-cache.timer"
assert_contains "$ROOT/var/lib/foxly-motd/version" dev
assert_contains "$ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=de
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_NETWORK_DETAILS=yes
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_NETWORK=yes
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_RESOURCES=yes
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_SESSION=yes
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_SYSTEM_HEALTH=yes
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_PACKAGE_NAMES=no
assert_contains "$ROOT/etc/default/foxly-motd" PACKAGE_NAME_LIMIT=5
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_FRAME=yes
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
cat > "$LAYOUT_BIN/resolvectl" << 'EOF'
#!/usr/bin/env bash
printf 'Global: 10.100.0.1 1.1.1.1\nLink 2 (eth0): 10.100.0.1\n'
EOF
cat > "$LAYOUT_BIN/systemctl" << 'EOF'
#!/usr/bin/env bash
printf 'broken.service loaded failed failed\nother.service loaded failed failed\n'
EOF
cat > "$LAYOUT_BIN/docker" << 'EOF'
#!/usr/bin/env bash
printf 'running\tUp 2 hours (healthy)\nrunning\tUp 2 hours (unhealthy)\nrestarting\tRestarting (1) 2 seconds ago\nexited\tExited (0) 1 hour ago\n'
EOF
cat > "$LAYOUT_BIN/timeout" << 'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
chmod +x "$LAYOUT_BIN/ip" "$LAYOUT_BIN/resolvectl" "$LAYOUT_BIN/systemctl" "$LAYOUT_BIN/docker" "$LAYOUT_BIN/timeout"
cat > "$TEST_DIR/meminfo" << 'EOF'
MemTotal:        1000 kB
MemFree:          100 kB
MemAvailable:     400 kB
Buffers:           50 kB
Cached:           200 kB
SwapTotal:        200 kB
SwapFree:         150 kB
EOF
touch "$TEST_DIR/reboot-required"
mkdir -p "$ROOT/var/cache/foxly-motd"
cat > "$ROOT/var/cache/foxly-motd/packages" << 'EOF'
generated=2026-07-17 12:00:00
updates=3
security=0
packages=curl, openssl, linux-image
EOF
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=de/; s/^SHOW_DOCKER=.*/SHOW_DOCKER=yes/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
PATH="$LAYOUT_BIN:$PATH" \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_REBOOT_REQUIRED_FILE="$TEST_DIR/reboot-required" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    SSH_CONNECTION='203.0.113.5 12345 192.0.2.10 22' \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout"
assert_contains "$TEST_DIR/layout" 'eth0: 192.0.2.10/24'
assert_contains "$TEST_DIR/layout" 'eth1: 198.51.100.20/24'
assert_contains "$TEST_DIR/layout" 'DNS-Server: 10.100.0.1'
assert_contains "$TEST_DIR/layout" '1.1.1.1'
assert_matches "$TEST_DIR/layout" 'RAM benutzt: +60,0%'
assert_matches "$TEST_DIR/layout" 'Swap benutzt: +25,0%'
assert_matches "$TEST_DIR/layout" 'Remote Host: +203.0.113.5'
assert_contains "$TEST_DIR/layout" '🌐 [ NETZWERK ]'
assert_contains "$TEST_DIR/layout" '📊 [ RESSOURCEN ]'
assert_contains "$TEST_DIR/layout" '👤 [ SITZUNG ]'
assert_contains "$TEST_DIR/layout" '⚙️ [ SYSTEMSTATUS ]'
assert_contains "$TEST_DIR/layout" '📦 [ PAKET-UPDATES ]'
assert_matches "$TEST_DIR/layout" 'Systemd-Dienste: +2 fehlgeschlagen'
assert_matches "$TEST_DIR/layout" 'Neustart nötig: +Ja'
assert_contains "$TEST_DIR/layout" '3 Paket-Updates verfügbar,'
assert_contains "$TEST_DIR/layout" 'davon 0 Sicherheitsupdates.'
assert_contains "$TEST_DIR/layout" '🐳 Docker-Container'
assert_matches "$TEST_DIR/layout" 'aktiv: +2'
assert_matches "$TEST_DIR/layout" 'gestoppt: +1'
assert_matches "$TEST_DIR/layout" 'fehlerhaft: +1'
assert_matches "$TEST_DIR/layout" 'Neustart: +1'
assert_matches "$TEST_DIR/layout" '^╭─+╮$'
assert_matches "$TEST_DIR/layout" '^╰─+╯$'
assert_matches "$TEST_DIR/layout" '^│ Systeminformationen am .+ +│$'
blank_box_rows=$(grep -Ec '^│ +│$' "$TEST_DIR/layout")
((blank_box_rows >= 1)) || fail 'Expected a separator between dashboard rows'
resources_column=$(LC_ALL=C awk '/RESSOURCEN/ {sub(/^│ /, ""); print index($0, "📊")}' "$TEST_DIR/layout")
session_column=$(LC_ALL=C awk '/SITZUNG/ {sub(/^│ /, ""); print index($0, "👤")}' "$TEST_DIR/layout")
[[ "$resources_column" == 41 ]] || fail "Resources starts in inner byte column $resources_column instead of 41"
[[ "$session_column" == 81 ]] || fail "Session starts in inner byte column $session_column instead of 81"
network_line=$(grep -nF '[ NETZWERK ]' "$TEST_DIR/layout" | cut -d: -f1)
resources_line=$(grep -nF '[ RESSOURCEN ]' "$TEST_DIR/layout" | cut -d: -f1)
session_line=$(grep -nF '[ SITZUNG ]' "$TEST_DIR/layout" | cut -d: -f1)
health_line=$(grep -nF '[ SYSTEMSTATUS ]' "$TEST_DIR/layout" | cut -d: -f1)
packages_line=$(grep -nF '[ PAKET-UPDATES ]' "$TEST_DIR/layout" | cut -d: -f1)
docker_line=$(grep -nF '🐳 Docker-Container' "$TEST_DIR/layout" | cut -d: -f1)
((network_line == resources_line && resources_line == session_line && session_line < health_line && health_line == packages_line && packages_line == docker_line)) ||
    fail 'Dashboard groups are not arranged as a three-column grid'
docker_column=$(LC_ALL=C awk '/Docker-Container/ {sub(/^│ /, ""); print index($0, "🐳")}' "$TEST_DIR/layout")
[[ "$docker_column" == 83 ]] || fail "Docker starts in inner byte column $docker_column instead of 83"
network_detail_line=$(grep -nF 'IP-Adresse(n):' "$TEST_DIR/layout" | cut -d: -f1)
uptime_line=$(grep -nF 'Systemlaufzeit:' "$TEST_DIR/layout" | cut -d: -f1)
current_user_line=$(grep -nF 'Aktueller Nutzer:' "$TEST_DIR/layout" | cut -d: -f1)
((network_detail_line == network_line + 2)) || fail 'Missing vertical gap below dashboard headings'
((current_user_line == uptime_line + 1)) || fail 'Unexpected blank row between session details'

printf 'Test: zero-value Docker states are hidden\n'
cat > "$LAYOUT_BIN/docker" << 'EOF'
#!/usr/bin/env bash
for ((i = 0; i < 17; i++)); do
    printf 'running\tUp 2 hours (healthy)\n'
done
EOF
chmod +x "$LAYOUT_BIN/docker"
PATH="$LAYOUT_BIN:$PATH" \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_REBOOT_REQUIRED_FILE="$TEST_DIR/reboot-required" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout-docker-filtered"
assert_matches "$TEST_DIR/layout-docker-filtered" 'aktiv: +17'
assert_not_contains "$TEST_DIR/layout-docker-filtered" 'gestoppt:'
assert_not_contains "$TEST_DIR/layout-docker-filtered" 'fehlerhaft:'
assert_not_contains "$TEST_DIR/layout-docker-filtered" 'Neustart:'

printf 'Test: PAM and login-session remote host fallbacks\n'
env -u SSH_CONNECTION -u SSH_CLIENT \
    PATH="$LAYOUT_BIN:$PATH" \
    PAM_RHOST='198.51.100.42' \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_REBOOT_REQUIRED_FILE="$TEST_DIR/reboot-required" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout-pam"
assert_matches "$TEST_DIR/layout-pam" 'Remote Host: +198.51.100.42'

cat > "$LAYOUT_BIN/who" << 'EOF'
#!/usr/bin/env bash
printf 'foxly pts/0 2026-07-16 12:00 (203.0.113.77)\n'
EOF
chmod +x "$LAYOUT_BIN/who"
env -u SSH_CONNECTION -u SSH_CLIENT -u PAM_RHOST \
    PATH="$LAYOUT_BIN:$PATH" \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_REBOOT_REQUIRED_FILE="$TEST_DIR/reboot-required" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout-who"
assert_matches "$TEST_DIR/layout-who" 'Remote Host: +203.0.113.77'

printf 'Test: modular groups, package names, and frameless output\n'
sed -i.bak \
    's/^SHOW_NETWORK=.*/SHOW_NETWORK=no/; s/^SHOW_SESSION=.*/SHOW_SESSION=no/; s/^SHOW_FRAME=.*/SHOW_FRAME=no/; s/^SHOW_PACKAGE_NAMES=.*/SHOW_PACKAGE_NAMES=yes/; s/^PACKAGE_NAME_LIMIT=.*/PACKAGE_NAME_LIMIT=2/' \
    "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
PATH="$LAYOUT_BIN:$PATH" \
    FOXLY_MOTD_MEMINFO_FILE="$TEST_DIR/meminfo" \
    FOXLY_MOTD_REBOOT_REQUIRED_FILE="$TEST_DIR/reboot-required" \
    FOXLY_MOTD_CONFIG_FILE="$ROOT/etc/default/foxly-motd" \
    FOXLY_MOTD_CACHE_FILE="$ROOT/var/cache/foxly-motd/packages" \
    FOXLY_MOTD_STATE_DIR="$ROOT/var/lib/foxly-motd" \
    "$ROOT/etc/update-motd.d/10-foxly-sysinfo" > "$TEST_DIR/layout-modular"
assert_not_contains "$TEST_DIR/layout-modular" '[ NETZWERK ]'
assert_not_contains "$TEST_DIR/layout-modular" '[ SITZUNG ]'
assert_not_contains "$TEST_DIR/layout-modular" '╭'
assert_contains "$TEST_DIR/layout-modular" 'curl · openssl'
assert_contains "$TEST_DIR/layout-modular" 'und 1 weitere'
sed -i.bak \
    's/^SHOW_NETWORK=.*/SHOW_NETWORK=yes/; s/^SHOW_SESSION=.*/SHOW_SESSION=yes/; s/^SHOW_FRAME=.*/SHOW_FRAME=yes/; s/^SHOW_PACKAGE_NAMES=.*/SHOW_PACKAGE_NAMES=no/; s/^PACKAGE_NAME_LIMIT=.*/PACKAGE_NAME_LIMIT=5/' \
    "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
sed -i.bak 's/^MOTD_LANGUAGE=.*/MOTD_LANGUAGE=auto/' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"

printf 'Test: configuration preservation and backup\n'
printf '\nCUSTOM_SETTING=preserved\n' >> "$ROOT/etc/default/foxly-motd"
sed -i.bak 's/^SHOW_FRAME=.*/SHOW_FRAME=no/; /^SHOW_PACKAGE_NAMES=/d; /^PACKAGE_NAME_LIMIT=/d' "$ROOT/etc/default/foxly-motd"
rm -f "$ROOT/etc/default/foxly-motd.bak"
FOXLY_MOTD_ROOT="$ROOT" bash "$PROJECT_DIR/install.sh" --upgrade --no-refresh --no-timers
assert_contains "$ROOT/etc/default/foxly-motd" CUSTOM_SETTING=preserved
assert_contains "$ROOT/etc/default/foxly-motd" MOTD_LANGUAGE=auto
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_FRAME=no
assert_contains "$ROOT/etc/default/foxly-motd" SHOW_PACKAGE_NAMES=no
assert_contains "$ROOT/etc/default/foxly-motd" PACKAGE_NAME_LIMIT=5
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
