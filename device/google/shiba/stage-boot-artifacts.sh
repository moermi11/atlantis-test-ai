#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-boot-artifacts
atlantis_load_profile "$DEFAULT_PROFILE"

ROOTFS_DIR=$(atlantis_path_from_repo "${ATLANTIS_ROOTFS_DIR:-}")
REPO_DIR=$(atlantis_path_from_repo "${ATLANTIS_REPO_DIR:-}")
COMPOSE_STAGE_DIR=$(atlantis_path_from_repo "${ATLANTIS_DEVICE_STAGE_DIR:-}")
BOOT_ARTIFACT_DIR=$(atlantis_path_from_repo "${ATLANTIS_BOOT_ARTIFACT_DIR:-}")
KERNEL_ARTIFACT=$(atlantis_path_from_repo "${ATLANTIS_KERNEL_ARTIFACT:-}")
INITRAMFS_ARTIFACT=$(atlantis_path_from_repo "${ATLANTIS_INITRAMFS_ARTIFACT:-}")

rm -rf "$BOOT_ARTIFACT_DIR"
mkdir -p \
    "$BOOT_ARTIFACT_DIR/metadata" \
    "$BOOT_ARTIFACT_DIR/manifests" \
    "$BOOT_ARTIFACT_DIR/unresolved"

ln -sfn "$COMPOSE_STAGE_DIR" "$BOOT_ARTIFACT_DIR/compose-stage"
ln -sfn "$ROOTFS_DIR" "$BOOT_ARTIFACT_DIR/rootfs"
ln -sfn "$REPO_DIR" "$BOOT_ARTIFACT_DIR/package-feed"
ln -sfn "$KERNEL_ARTIFACT" "$BOOT_ARTIFACT_DIR/kernel-artifact"
ln -sfn "$INITRAMFS_ARTIFACT" "$BOOT_ARTIFACT_DIR/initramfs-artifact"

cp "$PROFILE" "$BOOT_ARTIFACT_DIR/active-profile.env"

printf '%s\n' "$COMPOSE_STAGE_DIR" > "$BOOT_ARTIFACT_DIR/metadata/compose-stage.path"
printf '%s\n' "$ROOTFS_DIR" > "$BOOT_ARTIFACT_DIR/metadata/generic-rootfs.path"
printf '%s\n' "$REPO_DIR" > "$BOOT_ARTIFACT_DIR/metadata/package-feed.path"
printf '%s\n' "$KERNEL_ARTIFACT" > "$BOOT_ARTIFACT_DIR/metadata/kernel-artifact.path"
printf '%s\n' "$INITRAMFS_ARTIFACT" > "$BOOT_ARTIFACT_DIR/metadata/initramfs-artifact.path"
printf '%s\n' "${ATLANTIS_DEVICE_ID:-unset}" > "$BOOT_ARTIFACT_DIR/metadata/device-id.txt"
printf '%s\n' "${ATLANTIS_DEVICE_PACKAGE:-unset}" > "$BOOT_ARTIFACT_DIR/metadata/device-package-name.txt"

MANIFEST_ENV="$BOOT_ARTIFACT_DIR/manifests/boot-artifact-manifest.env"
: > "$MANIFEST_ENV"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_DEVICE_STAGE_DIR" "$COMPOSE_STAGE_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_BOOT_ARTIFACT_DIR" "$BOOT_ARTIFACT_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_ROOTFS_DIR" "$ROOTFS_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_REPO_DIR" "$REPO_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_KERNEL_ARTIFACT" "$KERNEL_ARTIFACT"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_INITRAMFS_ARTIFACT" "$INITRAMFS_ARTIFACT"
atlantis_write_kv "$MANIFEST_ENV" "BOOT_ARTIFACT_STAGE_STATE" "in progress"
atlantis_write_kv "$MANIFEST_ENV" "BOOT_ARTIFACT_STAGE_NOTE" "reviewable-staging-only"

cat > "$BOOT_ARTIFACT_DIR/manifests/boot-artifact-contract.txt" <<EOF
Atlantis shiba boot-artifact contract
====================================

Stage state: in progress
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Required staged inputs:
- generic rootfs artifact: $ROOTFS_DIR
- generated package feed artifact: $REPO_DIR
- shiba compose stage: $COMPOSE_STAGE_DIR
- kernel artifact input: $KERNEL_ARTIFACT
- initramfs artifact input: $INITRAMFS_ARTIFACT

Staged output:
- boot-artifact staging directory: $BOOT_ARTIFACT_DIR

Boundary notes:
- The generic rootfs artifact is userspace only.
- The generated package feed artifact is package distribution metadata plus .deb artifacts.
- The shiba compose stage is a userspace-oriented handoff directory.
- This boot-artifact stage only records and links explicit boot inputs for review.

Non-claims:
- This directory is not a fastboot package.
- This directory does not contain generated partition images.
- This directory does not prove Pixel 8 boots.
EOF

cat > "$BOOT_ARTIFACT_DIR/unresolved/placeholders.txt" <<'EOF'
Atlantis shiba boot-artifact unresolved items
============================================

- partition targets: placeholder only
- AVB/vbmeta handling: placeholder only
- slot strategy: placeholder only
- fastboot packaging: placeholder only
EOF

cat > "$BOOT_ARTIFACT_DIR/README.txt" <<EOF
Atlantis shiba boot-artifact staging directory
==============================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

This directory stages explicit boot-artifact inputs for review:
- compose stage: $COMPOSE_STAGE_DIR
- generic rootfs artifact: $ROOTFS_DIR
- generated package feed artifact: $REPO_DIR
- kernel artifact input: $KERNEL_ARTIFACT
- initramfs artifact input: $INITRAMFS_ARTIFACT

This stage exists to make the Sprint 2 handoff explicit.
It does not invoke fastboot.
It does not generate partition images.
It does not define partition targets, AVB/vbmeta handling, slot strategy, or fastboot packaging.
It does not claim the result is bootable or flashable.
EOF

echo "Atlantis shiba boot-artifact stage created at $BOOT_ARTIFACT_DIR"
echo "This staged output is reviewable metadata plus explicit artifact references only."
