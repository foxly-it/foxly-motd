#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${FOXLY_MOTD_REPO:-foxly-it/foxly-motd}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"
TMP_DIR=""

cleanup() { [[ -z "$TMP_DIR" || ! -d "$TMP_DIR" ]] || rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT
fail() { printf 'ERROR: %s\n' "$*" >&2; }

for command_name in curl tar sha256sum awk sed; do
    command -v "$command_name" > /dev/null 2>&1 || {
        fail "Missing required command: $command_name"
        exit 1
    }
done
if ((EUID != 0)); then
    fail "Run this installer as root"
    exit 1
fi

tag=$(curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 60 "$GITHUB_API/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
version=${tag#v}
[[ -n "$version" ]] || {
    fail "Could not determine the latest release"
    exit 1
}

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/foxly-motd-installer.XXXXXXXX")
chmod 0700 "$TMP_DIR"
asset="foxly-motd-${version}.tar.gz"
base="https://github.com/$REPO/releases/download/$tag"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 180 --output "$TMP_DIR/$asset" "$base/$asset"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 60 --output "$TMP_DIR/checksums.txt" "$base/checksums.txt"
expected=$(awk -v name="$asset" '$2 == name || $2 == "*" name || $2 == "./" name {print $1; exit}' "$TMP_DIR/checksums.txt")
actual=$(sha256sum "$TMP_DIR/$asset" | awk '{print $1}')
[[ "$expected" =~ ^[[:xdigit:]]{64}$ && "$actual" == "$expected" ]] || {
    fail "SHA-256 verification failed"
    exit 1
}
while IFS= read -r entry; do
    clean=${entry#./}
    case "$clean" in /* | ../* | */../* | */..)
        fail "Unsafe archive path: $entry"
        exit 1
        ;;
    esac
done < <(tar -tzf "$TMP_DIR/$asset")
mkdir "$TMP_DIR/release"
tar -xzf "$TMP_DIR/$asset" -C "$TMP_DIR/release" --no-same-owner --no-same-permissions
bash "$TMP_DIR/release/install.sh" "$@"
