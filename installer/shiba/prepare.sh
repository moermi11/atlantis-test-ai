#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-installer-prep
atlantis_load_profile "$DEFAULT_PROFILE"

BOOT_ARTIFACT_DIR=$(atlantis_path_from_repo "${ATLANTIS_BOOT_ARTIFACT_DIR:-}")
INSTALLER_PREP_DIR=$(atlantis_path_from_repo "${ATLANTIS_INSTALLER_PREP_DIR:-}")
KERNEL_ARTIFACT=$(atlantis_path_from_repo "${ATLANTIS_KERNEL_ARTIFACT:-}")
INITRAMFS_ARTIFACT=$(atlantis_path_from_repo "${ATLANTIS_INITRAMFS_ARTIFACT:-}")
FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
COMMAND_PLAN_DIR=$(atlantis_path_from_repo "${ATLANTIS_COMMAND_PLAN_DIR:-}")
DECISION_REVIEW_DIR=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_DIR:-}")

BOOT_KERNEL_ARTIFACT=$(atlantis_read_first_line "$BOOT_ARTIFACT_DIR/metadata/kernel-artifact.path")
BOOT_INITRAMFS_ARTIFACT=$(atlantis_read_first_line "$BOOT_ARTIFACT_DIR/metadata/initramfs-artifact.path")
BOOT_ROOTFS_DIR=$(atlantis_read_first_line "$BOOT_ARTIFACT_DIR/metadata/generic-rootfs.path")
BOOT_REPO_DIR=$(atlantis_read_first_line "$BOOT_ARTIFACT_DIR/metadata/package-feed.path")
BOOT_COMPOSE_STAGE_DIR=$(atlantis_read_first_line "$BOOT_ARTIFACT_DIR/metadata/compose-stage.path")

[ "$BOOT_KERNEL_ARTIFACT" = "$KERNEL_ARTIFACT" ] || atlantis_die "Boot-artifact staged kernel does not match ATLANTIS_KERNEL_ARTIFACT."
[ "$BOOT_INITRAMFS_ARTIFACT" = "$INITRAMFS_ARTIFACT" ] || atlantis_die "Boot-artifact staged initramfs does not match ATLANTIS_INITRAMFS_ARTIFACT."

rm -rf "$INSTALLER_PREP_DIR"
mkdir -p \
    "$INSTALLER_PREP_DIR/metadata" \
    "$INSTALLER_PREP_DIR/manifests" \
    "$INSTALLER_PREP_DIR/plans" \
    "$INSTALLER_PREP_DIR/unresolved"

ln -sfn "$BOOT_ARTIFACT_DIR" "$INSTALLER_PREP_DIR/boot-artifact-stage"
ln -sfn "$BOOT_COMPOSE_STAGE_DIR" "$INSTALLER_PREP_DIR/compose-stage"
ln -sfn "$BOOT_ROOTFS_DIR" "$INSTALLER_PREP_DIR/rootfs"
ln -sfn "$BOOT_REPO_DIR" "$INSTALLER_PREP_DIR/package-feed"
ln -sfn "$KERNEL_ARTIFACT" "$INSTALLER_PREP_DIR/kernel-artifact"
ln -sfn "$INITRAMFS_ARTIFACT" "$INSTALLER_PREP_DIR/initramfs-artifact"
ln -sfn "$FLASHING_DECISION_DIR" "$INSTALLER_PREP_DIR/flashing-decisions"

cp "$PROFILE" "$INSTALLER_PREP_DIR/active-profile.env"

printf '%s\n' "$BOOT_ARTIFACT_DIR" > "$INSTALLER_PREP_DIR/metadata/boot-artifact-stage.path"
printf '%s\n' "$BOOT_COMPOSE_STAGE_DIR" > "$INSTALLER_PREP_DIR/metadata/compose-stage.path"
printf '%s\n' "$BOOT_ROOTFS_DIR" > "$INSTALLER_PREP_DIR/metadata/generic-rootfs.path"
printf '%s\n' "$BOOT_REPO_DIR" > "$INSTALLER_PREP_DIR/metadata/package-feed.path"
printf '%s\n' "$KERNEL_ARTIFACT" > "$INSTALLER_PREP_DIR/metadata/kernel-artifact.path"
printf '%s\n' "$INITRAMFS_ARTIFACT" > "$INSTALLER_PREP_DIR/metadata/initramfs-artifact.path"
printf '%s\n' "${ATLANTIS_DEVICE_ID:-unset}" > "$INSTALLER_PREP_DIR/metadata/device-id.txt"
printf '%s\n' "$FLASHING_DECISION_DIR" > "$INSTALLER_PREP_DIR/metadata/flashing-decision-dir.path"
printf '%s\n' "$DECISION_REVIEW_DIR" > "$INSTALLER_PREP_DIR/metadata/decision-review-dir.path"
printf '%s\n' "$COMMAND_PLAN_DIR" > "$INSTALLER_PREP_DIR/metadata/command-plan-dir.path"

MANIFEST_ENV="$INSTALLER_PREP_DIR/manifests/installer-prep-manifest.env"
: > "$MANIFEST_ENV"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_BOOT_ARTIFACT_DIR" "$BOOT_ARTIFACT_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_KERNEL_ARTIFACT" "$KERNEL_ARTIFACT"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_INITRAMFS_ARTIFACT" "$INITRAMFS_ARTIFACT"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_DECISION_REVIEW_DIR" "$DECISION_REVIEW_DIR"
atlantis_write_kv "$MANIFEST_ENV" "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
atlantis_write_kv "$MANIFEST_ENV" "INSTALLER_PREP_STATE" "in progress"
atlantis_write_kv "$MANIFEST_ENV" "INSTALLER_PREP_NOTE" "reviewable-handoff-only"

cat > "$INSTALLER_PREP_DIR/manifests/installer-prep-contract.txt" <<EOF
Atlantis shiba installer-preparation contract
============================================

Stage state: in progress
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Consumed input:
- staged shiba boot-artifact directory: $BOOT_ARTIFACT_DIR

Produced output:
- installer-preparation directory: $INSTALLER_PREP_DIR

Boundary notes:
- The staged shiba boot-artifact directory is a boot-input handoff boundary.
- The installer-preparation output is a reviewable host-side preparation boundary.
- Structured flashing decisions live separately under: $FLASHING_DECISION_DIR
- A future guarded command-plan stage writes to: $COMMAND_PLAN_DIR
- A future fastboot command sequence is planned work and is not executed here.
- A future real flashing flow remains separate and unresolved.

Non-claims:
- This stage does not invoke fastboot.
- This stage does not flash any partition.
- This stage does not generate partition images.
- This stage does not claim Pixel 8 boots.
EOF

cat > "$INSTALLER_PREP_DIR/manifests/device-assumptions.txt" <<EOF
Atlantis shiba installer-preparation decision handoff
=====================================================

- device id: ${ATLANTIS_DEVICE_ID:-unset}
- bootloader unlock state for development use: assumed, not verified by this script
- stock recovery path retained for rollback: assumed, not verified by this script
- host command availability checked only: fastboot and adb
- partition-target mapping file: $FLASHING_DECISION_DIR/partition-targets.env
- AVB/vbmeta policy file: $FLASHING_DECISION_DIR/avb-vbmeta-policy.env
- slot strategy file: $FLASHING_DECISION_DIR/slot-strategy.env
- firmware and boot-input provenance file: $FLASHING_DECISION_DIR/boot-input-provenance.env
- next review steps:
  - sh ./installer/shiba/collect-evidence.sh
  - sh ./installer/shiba/review-decisions.sh
  - sh ./installer/shiba/generate-command-plan.sh
EOF

cat > "$INSTALLER_PREP_DIR/plans/flashing-plan.txt" <<EOF
Atlantis shiba flashing review plan
==================================

Plan state: in progress
Purpose: hand off installer-preparation inputs into the guarded command-plan stage only

Profile:
- $PROFILE_NAME

Future flashing inputs to review:
- staged boot-artifact directory: $BOOT_ARTIFACT_DIR
- staged compose directory: $BOOT_COMPOSE_STAGE_DIR
- generic rootfs artifact: $BOOT_ROOTFS_DIR
- generated package feed artifact: $BOOT_REPO_DIR
- kernel artifact input: $KERNEL_ARTIFACT
- initramfs artifact input: $INITRAMFS_ARTIFACT
- structured flashing-decision directory: $FLASHING_DECISION_DIR
- future decision-review output directory: $DECISION_REVIEW_DIR
- future command-plan output directory: $COMMAND_PLAN_DIR

Next review boundary:
- capture read-only evidence before reviewing live decision files
- run the guarded decision-review step before the guarded command-plan generator
- keep partition targets, AVB/vbmeta handling, slot strategy, and provenance in the decision files instead of free-form placeholder text here

Explicit non-claims:
- no fastboot command was run
- no flashing command sequence was generated here
- no device-side state was changed
- no claim is made that the resulting inputs are bootable or flashable
EOF

cat > "$INSTALLER_PREP_DIR/unresolved/decision-layer.txt" <<EOF
Atlantis shiba installer-preparation unresolved decision handoff
===============================================================

Structured flashing decisions remain the source of truth for unresolved flashing items:
- $FLASHING_DECISION_DIR/partition-targets.env
- $FLASHING_DECISION_DIR/avb-vbmeta-policy.env
- $FLASHING_DECISION_DIR/slot-strategy.env
- $FLASHING_DECISION_DIR/boot-input-provenance.env

This installer-preparation stage does not resolve those items itself.
EOF

cat > "$INSTALLER_PREP_DIR/README.txt" <<EOF
Atlantis shiba installer-preparation directory
=============================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

This directory prepares flashing review inputs only:
- staged boot-artifact directory: $BOOT_ARTIFACT_DIR
- staged compose directory: $BOOT_COMPOSE_STAGE_DIR
- generic rootfs artifact: $BOOT_ROOTFS_DIR
- generated package feed artifact: $BOOT_REPO_DIR
- kernel artifact input: $KERNEL_ARTIFACT
- initramfs artifact input: $INITRAMFS_ARTIFACT
- structured flashing-decision directory: $FLASHING_DECISION_DIR
- future decision-review output directory: $DECISION_REVIEW_DIR
- future command-plan output directory: $COMMAND_PLAN_DIR

This stage exists to make host-side flashing review explicit.
It does not invoke fastboot.
It does not flash any partition.
It does not resolve partition targets, AVB/vbmeta handling, slot strategy, firmware provenance, or rollback-safe sequencing.
It does not claim the result is bootable or flashable.
EOF

echo "Atlantis shiba installer-preparation output created at $INSTALLER_PREP_DIR"
echo "This staged output is reviewable metadata plus a flashing review plan only."
