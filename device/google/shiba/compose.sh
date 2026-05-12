#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-compose

atlantis_load_profile "$DEFAULT_PROFILE"

ROOTFS_DIR=$(atlantis_path_from_repo "${ATLANTIS_ROOTFS_DIR:-}")
REPO_DIR=$(atlantis_path_from_repo "${ATLANTIS_REPO_DIR:-}")
STAGE_DIR=$(atlantis_path_from_repo "${ATLANTIS_DEVICE_STAGE_DIR:-}")
DEVICE_PACKAGE_SOURCE_DIR=$(atlantis_path_from_repo "${ATLANTIS_DEVICE_PACKAGE_SOURCE_DIR:-}")
DEVICE_PACKAGE=${ATLANTIS_DEVICE_PACKAGE:-}
KERNEL_ARTIFACT=${ATLANTIS_KERNEL_ARTIFACT:-}
INITRAMFS_ARTIFACT=${ATLANTIS_INITRAMFS_ARTIFACT:-}

find_device_package_deb() {
    if [ -z "$DEVICE_PACKAGE" ]; then
        return 1
    fi

    find "$REPO_DIR" -maxdepth 1 -type f -name "${DEVICE_PACKAGE}_*.deb" -print -quit
}

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/metadata" "$STAGE_DIR/placeholders"

ln -sfn "$ROOTFS_DIR" "$STAGE_DIR/rootfs"
ln -sfn "$REPO_DIR" "$STAGE_DIR/package-feed"

cp "$PROFILE" "$STAGE_DIR/active-profile.env"

printf '%s\n' "$ROOTFS_DIR" > "$STAGE_DIR/metadata/generic-rootfs.path"
printf '%s\n' "$REPO_DIR" > "$STAGE_DIR/metadata/package-feed.path"
printf '%s\n' "$DEVICE_PACKAGE_SOURCE_DIR" > "$STAGE_DIR/metadata/device-package-source.path"
printf '%s\n' "${DEVICE_PACKAGE:-unset}" > "$STAGE_DIR/metadata/device-package-name.txt"

DEVICE_PACKAGE_DEB=$(find_device_package_deb || true)
if [ -n "$DEVICE_PACKAGE_DEB" ]; then
    printf '%s\n' "$DEVICE_PACKAGE_DEB" > "$STAGE_DIR/metadata/device-package-feed-artifact.path"
    printf '%s\n' "present" > "$STAGE_DIR/metadata/device-package-feed-artifact.state"
else
    printf '%s\n' "missing" > "$STAGE_DIR/metadata/device-package-feed-artifact.state"
fi

if [ -n "$KERNEL_ARTIFACT" ]; then
    printf '%s\n' "$(atlantis_path_from_repo "$KERNEL_ARTIFACT")" > "$STAGE_DIR/metadata/kernel-artifact.path"
else
    printf '%s\n' "placeholder" > "$STAGE_DIR/placeholders/kernel-artifact.state"
fi

if [ -n "$INITRAMFS_ARTIFACT" ]; then
    printf '%s\n' "$(atlantis_path_from_repo "$INITRAMFS_ARTIFACT")" > "$STAGE_DIR/metadata/initramfs-artifact.path"
else
    printf '%s\n' "placeholder" > "$STAGE_DIR/placeholders/initramfs-artifact.state"
fi

cat > "$STAGE_DIR/README.txt" <<EOF
Atlantis shiba compose stage
============================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

This staged directory references existing Atlantis build artifacts:
- generic rootfs: $ROOTFS_DIR
- local package feed: $REPO_DIR
- device package boundary: ${DEVICE_PACKAGE:-unset}

This stage is not a flashing bundle.
This stage is not a bootable Pixel 8 artifact.
Kernel and initramfs inputs remain placeholders until explicit artifact paths exist.
EOF

echo "Atlantis shiba compose stage created at $STAGE_DIR"
echo "This staged output is reviewable metadata plus artifact references only."
