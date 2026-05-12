#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

. "$SCRIPT_DIR/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$SCRIPT_DIR/preflight.sh" rootfs
atlantis_load_profile "$DEFAULT_PROFILE"

PROFILE_NAME=${PROFILE_NAME:-${ATLANTIS_PROFILE_NAME:-development-bookworm-arm64}}
SUITE=${SUITE:-${ATLANTIS_SUITE:-bookworm}}
ARCH=${ARCH:-${ATLANTIS_ARCH:-arm64}}
MMDEBSTRAP_MODE=${MMDEBSTRAP_MODE:-auto}
MMDEBSTRAP_VARIANT=${MMDEBSTRAP_VARIANT:-${ATLANTIS_MMDEBSTRAP_VARIANT:-minbase}}
MIRROR=${MIRROR:-${ATLANTIS_MIRROR:-https://deb.debian.org/debian}}
SECURITY_MIRROR=${SECURITY_MIRROR:-${ATLANTIS_SECURITY_MIRROR:-http://security.debian.org/debian-security}}
ROOTFS_DIR=${ROOTFS_DIR:-"$(atlantis_path_from_repo "${ATLANTIS_ROOTFS_DIR:-out/rootfs/$SUITE-$ARCH}")"}
REPO_DIR=${REPO_DIR:-"$(atlantis_path_from_repo "${ATLANTIS_REPO_DIR:-out/repo}")"}
PACKAGE_LISTS=${PACKAGE_LISTS:-${ATLANTIS_PACKAGE_LISTS:-}}
ATLANTIS_PACKAGES=${ATLANTIS_PACKAGES:-${ATLANTIS_GENERIC_PACKAGES:-atlantis-base,atlantis-branding,atlantis-shell}}
ATLANTIS_EXTRA_PACKAGES=${ATLANTIS_EXTRA_PACKAGES:-}

join_package_file() {
    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            if (length(out) > 0) {
                out = out "," $0
            } else {
                out = $0
            }
        }
        END { print out }
    ' "$1"
}

append_csv() {
    left=$1
    right=$2

    if [ -z "$left" ]; then
        printf '%s' "$right"
    elif [ -z "$right" ]; then
        printf '%s' "$left"
    else
        printf '%s,%s' "$left" "$right"
    fi
}

append_package_file() {
    file_path=$1

    if [ ! -f "$REPO_ROOT/$file_path" ]; then
        echo "Package list not found: $file_path" >&2
        exit 1
    fi

    join_package_file "$REPO_ROOT/$file_path"
}

if [ -z "$PACKAGE_LISTS" ]; then
    echo "Atlantis profile must define ATLANTIS_PACKAGE_LISTS." >&2
    exit 1
fi

INCLUDE_PACKAGES=""
for package_list in $PACKAGE_LISTS; do
    INCLUDE_PACKAGES=$(append_csv "$INCLUDE_PACKAGES" "$(append_package_file "$package_list")")
done

INCLUDE_PACKAGES=$(append_csv "$INCLUDE_PACKAGES" "$ATLANTIS_PACKAGES")
INCLUDE_PACKAGES=$(append_csv "$INCLUDE_PACKAGES" "$ATLANTIS_EXTRA_PACKAGES")

SOURCES_FILE="$TMP_DIR/sources.list"
{
    printf 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] %s %s main\n' "$MIRROR" "$SUITE"
    printf 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] %s %s-updates main\n' "$MIRROR" "$SUITE"
    printf 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] %s %s-security main\n' "$SECURITY_MIRROR" "$SUITE"
} > "$SOURCES_FILE"

if [ -d "$REPO_DIR" ] && find "$REPO_DIR" -maxdepth 1 -name '*.deb' -print -quit | grep . >/dev/null 2>&1; then
    ln -s "$REPO_DIR" "$TMP_DIR/repo"
    printf 'deb [trusted=yes] file:%s ./\n' "$TMP_DIR/repo" >> "$SOURCES_FILE"
fi

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

mmdebstrap \
    --mode="$MMDEBSTRAP_MODE" \
    --variant="$MMDEBSTRAP_VARIANT" \
    --architectures="$ARCH" \
    --components=main \
    --format=directory \
    --include="$INCLUDE_PACKAGES" \
    --aptopt='Apt::Install-Recommends "false"' \
    --aptopt='Acquire::Languages "none"' \
    --customize-hook="$SCRIPT_DIR/hooks/10-cleanup-apt.sh \$1" \
    "$SUITE" \
    "$ROOTFS_DIR" \
    "$SOURCES_FILE"

echo "Atlantis rootfs created at $ROOTFS_DIR"
echo "Atlantis rootfs profile: $PROFILE_NAME ($PROFILE)"
