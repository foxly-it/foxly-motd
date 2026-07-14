#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${FOXLY_MOTD_ROOT:-}"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ACTION=install
REFRESH=true
ENABLE_TIMERS=true

usage() {
    cat << 'EOF'
Usage: install.sh [OPTIONS]

Options:
  --upgrade       Upgrade an existing installation and preserve configuration
  --no-refresh    Do not refresh the package cache after installation
  --no-timers     Install timer units without enabling them
  -h, --help      Show this help
EOF
}

while (($#)); do
    case "$1" in
        --upgrade) ACTION=upgrade ;;
        --no-refresh) REFRESH=false ;;
        --no-timers) ENABLE_TIMERS=false ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: Unknown option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

if [[ -z "$ROOT" && $EUID -ne 0 ]]; then
    printf 'ERROR: Run this installer as root.\n' >&2
    exit 1
fi

required=(
    bin/foxly-motd
    motd/00-foxly-header
    motd/10-foxly-sysinfo
    libexec/foxly-motd-cache
    systemd/foxly-motd-cache.service
    systemd/foxly-motd-cache.timer
    systemd/foxly-motd-update.service
    systemd/foxly-motd-update.timer
    config/foxly-motd
    VERSION
)
for file in "${required[@]}"; do
    [[ -f "$SCRIPT_DIR/$file" ]] || {
        printf 'ERROR: Installation source missing: %s\n' "$file" >&2
        exit 1
    }
done

version=$(head -n 1 "$SCRIPT_DIR/VERSION")
[[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+|dev)$ ]] || {
    printf 'ERROR: Invalid VERSION file.\n' >&2
    exit 1
}

bash -n "$SCRIPT_DIR/bin/foxly-motd" "$SCRIPT_DIR/motd/00-foxly-header" \
    "$SCRIPT_DIR/motd/10-foxly-sysinfo" "$SCRIPT_DIR/libexec/foxly-motd-cache"

install_dependencies() {
    [[ -z "$ROOT" ]] || return 0
    local command_name package missing=() packages=()
    local -A requirements=(
        [figlet]=figlet
        [flock]=util-linux
        [free]=procps
        [ip]=iproute2
        [nproc]=coreutils
        [curl]=curl
        [sha256sum]=coreutils
        [tar]=tar
        [timeout]=coreutils
    )
    for command_name in "${!requirements[@]}"; do
        command -v "$command_name" > /dev/null 2>&1 || missing+=("$command_name")
    done
    ((${#missing[@]})) || return 0
    command -v apt-get > /dev/null 2>&1 || {
        printf 'ERROR: Missing commands: %s. Automatic installation requires Debian or Ubuntu.\n' "${missing[*]}" >&2
        return 1
    }
    for command_name in "${missing[@]}"; do
        package=${requirements[$command_name]}
        [[ " ${packages[*]} " == *" $package "* ]] || packages+=("$package")
    done
    printf 'Installing required packages: %s\n' "${packages[*]}"
    apt-get update -qq
    apt-get install -y -qq "${packages[@]}"
    if ! command -v lolcat > /dev/null 2>&1; then
        apt-get install -y -qq lolcat || printf 'WARNING: lolcat is unavailable; plain colors will be used.\n' >&2
    fi
}

install_dependencies

backup_existing() {
    local stamp old_version list=() path rel archive
    [[ -x "${ROOT}/usr/local/sbin/foxly-motd" ]] || return 0
    stamp=$(date +%Y%m%d-%H%M%S)
    old_version=$(head -n 1 "${ROOT}/var/lib/foxly-motd/version" 2> /dev/null || printf unknown)
    mkdir -p "${ROOT}/var/backups/foxly-motd"
    for path in \
        /usr/local/sbin/foxly-motd \
        /usr/local/lib/foxly-motd/cache \
        /usr/local/lib/foxly-motd/install.sh \
        /etc/update-motd.d/00-foxly-header \
        /etc/update-motd.d/10-foxly-sysinfo \
        /etc/systemd/system/foxly-motd-cache.service \
        /etc/systemd/system/foxly-motd-cache.timer \
        /etc/systemd/system/foxly-motd-update.service \
        /etc/systemd/system/foxly-motd-update.timer \
        /var/lib/foxly-motd/version; do
        [[ -e "${ROOT}$path" ]] || continue
        rel=${path#/}
        list+=("$rel")
    done
    ((${#list[@]})) || return 0
    archive="${ROOT}/var/backups/foxly-motd/${stamp}-${old_version}.tar.gz"
    tar -czf "$archive" -C "${ROOT:-/}" "${list[@]}"
    printf 'Backup created: %s\n' "$archive"
}

[[ "$ACTION" == upgrade ]] && backup_existing

install -d -m 0755 "${ROOT}/usr/local/sbin" "${ROOT}/usr/local/lib/foxly-motd" \
    "${ROOT}/etc/update-motd.d" "${ROOT}/etc/default" \
    "${ROOT}/etc/systemd/system" "${ROOT}/var/lib/foxly-motd" \
    "${ROOT}/var/cache/foxly-motd" "${ROOT}/var/backups/foxly-motd"
install -m 0755 "$SCRIPT_DIR/bin/foxly-motd" "${ROOT}/usr/local/sbin/foxly-motd"
install -m 0755 "$SCRIPT_DIR/libexec/foxly-motd-cache" "${ROOT}/usr/local/lib/foxly-motd/cache"
install -m 0755 "$SCRIPT_DIR/install.sh" "${ROOT}/usr/local/lib/foxly-motd/install.sh"
install -m 0755 "$SCRIPT_DIR/motd/00-foxly-header" "${ROOT}/etc/update-motd.d/00-foxly-header"
install -m 0755 "$SCRIPT_DIR/motd/10-foxly-sysinfo" "${ROOT}/etc/update-motd.d/10-foxly-sysinfo"
install -m 0644 "$SCRIPT_DIR/systemd/foxly-motd-cache.service" "${ROOT}/etc/systemd/system/foxly-motd-cache.service"
install -m 0644 "$SCRIPT_DIR/systemd/foxly-motd-cache.timer" "${ROOT}/etc/systemd/system/foxly-motd-cache.timer"
install -m 0644 "$SCRIPT_DIR/systemd/foxly-motd-update.service" "${ROOT}/etc/systemd/system/foxly-motd-update.service"
install -m 0644 "$SCRIPT_DIR/systemd/foxly-motd-update.timer" "${ROOT}/etc/systemd/system/foxly-motd-update.timer"
printf '%s\n' "$version" > "${ROOT}/var/lib/foxly-motd/version"

if [[ ! -f "${ROOT}/etc/default/foxly-motd" ]]; then
    install -m 0644 "$SCRIPT_DIR/config/foxly-motd" "${ROOT}/etc/default/foxly-motd"
fi

if [[ -z "$ROOT" ]] && command -v systemctl > /dev/null 2>&1; then
    systemctl daemon-reload
    if $ENABLE_TIMERS; then
        systemctl enable --now foxly-motd-cache.timer foxly-motd-update.timer
    fi
    if $REFRESH; then
        systemctl start foxly-motd-cache.service ||
            printf 'WARNING: Initial cache refresh failed; the timer will retry later.\n' >&2
    fi
fi

printf 'Foxly MOTD %s installed. Preview: foxly-motd preview\n' "$version"
