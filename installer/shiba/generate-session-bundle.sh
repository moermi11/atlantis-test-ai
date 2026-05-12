#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-session-bundle
atlantis_load_profile "$DEFAULT_PROFILE"

INSTALLER_PREP_DIR=$(atlantis_path_from_repo "${ATLANTIS_INSTALLER_PREP_DIR:-}")
FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
COMMAND_PLAN_DIR=$(atlantis_path_from_repo "${ATLANTIS_COMMAND_PLAN_DIR:-}")
DECISION_REVIEW_STATUS_FILE=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}")
EVIDENCE_BUNDLE_DIR=$(atlantis_path_from_repo "${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}")
DECISION_REVIEW_DIR=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_DIR:-}")
READINESS_DIR=$(atlantis_path_from_repo "${ATLANTIS_READINESS_DIR:-}")
SESSION_BUNDLE_DIR=$(atlantis_path_from_repo "${ATLANTIS_SESSION_BUNDLE_DIR:-}")

PARTITION_DECISIONS_FILE="$FLASHING_DECISION_DIR/partition-targets.env"
AVB_DECISIONS_FILE="$FLASHING_DECISION_DIR/avb-vbmeta-policy.env"
SLOT_DECISIONS_FILE="$FLASHING_DECISION_DIR/slot-strategy.env"
PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_DIR/boot-input-provenance.env"
READINESS_SUMMARY_FILE="$READINESS_DIR/metadata/readiness-summary.env"
COMMAND_PLAN_SUMMARY_FILE="$COMMAND_PLAN_DIR/metadata/command-plan-summary.env"

# shellcheck disable=SC1090
. "$READINESS_SUMMARY_FILE"
# shellcheck disable=SC1090
. "$COMMAND_PLAN_SUMMARY_FILE"

BOOT_ARTIFACT_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/boot-artifact-stage.path")
COMPOSE_STAGE_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/compose-stage.path")
ROOTFS_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/generic-rootfs.path")
PACKAGE_FEED_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/package-feed.path")
KERNEL_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/kernel-artifact.path")
INITRAMFS_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/initramfs-artifact.path")

rm -rf "$SESSION_BUNDLE_DIR"
mkdir -p \
    "$SESSION_BUNDLE_DIR/metadata" \
    "$SESSION_BUNDLE_DIR/checklists" \
    "$SESSION_BUNDLE_DIR/blockers" \
    "$SESSION_BUNDLE_DIR/notes" \
    "$SESSION_BUNDLE_DIR/bundle/decisions"

ln -sfn "$INSTALLER_PREP_DIR" "$SESSION_BUNDLE_DIR/installer-preparation"
ln -sfn "$COMMAND_PLAN_DIR" "$SESSION_BUNDLE_DIR/command-plan"
ln -sfn "$FLASHING_DECISION_DIR" "$SESSION_BUNDLE_DIR/flashing-decisions"
ln -sfn "$READINESS_DIR" "$SESSION_BUNDLE_DIR/readiness"
ln -sfn "$DECISION_REVIEW_DIR" "$SESSION_BUNDLE_DIR/decision-review"
if [ -d "$EVIDENCE_BUNDLE_DIR" ]; then
    ln -sfn "$EVIDENCE_BUNDLE_DIR" "$SESSION_BUNDLE_DIR/evidence-bundle"
fi

cp "$PROFILE" "$SESSION_BUNDLE_DIR/active-profile.env"
cp "$PARTITION_DECISIONS_FILE" "$SESSION_BUNDLE_DIR/bundle/decisions/"
cp "$AVB_DECISIONS_FILE" "$SESSION_BUNDLE_DIR/bundle/decisions/"
cp "$SLOT_DECISIONS_FILE" "$SESSION_BUNDLE_DIR/bundle/decisions/"
cp "$PROVENANCE_DECISIONS_FILE" "$SESSION_BUNDLE_DIR/bundle/decisions/"
cp "$DECISION_REVIEW_STATUS_FILE" "$SESSION_BUNDLE_DIR/bundle/decisions/"
cp "$READINESS_SUMMARY_FILE" "$SESSION_BUNDLE_DIR/metadata/"
cp "$COMMAND_PLAN_SUMMARY_FILE" "$SESSION_BUNDLE_DIR/metadata/"

if [ -f "$READINESS_DIR/blockers/all-blockers.txt" ]; then
    cp "$READINESS_DIR/blockers/all-blockers.txt" "$SESSION_BUNDLE_DIR/blockers/"
fi
if [ -f "$READINESS_DIR/blockers/missing-referenced-paths.txt" ]; then
    cp "$READINESS_DIR/blockers/missing-referenced-paths.txt" "$SESSION_BUNDLE_DIR/blockers/"
fi
if [ -f "$COMMAND_PLAN_DIR/blockers/all-blockers.txt" ]; then
    cp "$COMMAND_PLAN_DIR/blockers/all-blockers.txt" "$SESSION_BUNDLE_DIR/blockers/command-plan-all-blockers.txt"
fi

SUMMARY_ENV="$SESSION_BUNDLE_DIR/metadata/session-bundle-summary.env"
: > "$SUMMARY_ENV"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_EVIDENCE_BUNDLE_DIR" "$EVIDENCE_BUNDLE_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_DIR" "$DECISION_REVIEW_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_READINESS_DIR" "$READINESS_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_SESSION_BUNDLE_DIR" "$SESSION_BUNDLE_DIR"
atlantis_write_kv "$SUMMARY_ENV" "SESSION_BUNDLE_CLASSIFICATION" "${READINESS_CLASSIFICATION:-blocked}"
atlantis_write_kv "$SUMMARY_ENV" "SESSION_BUNDLE_COMMAND_PLAN_RESULT" "${COMMAND_PLAN_RESULT:-blocked}"
atlantis_write_kv "$SUMMARY_ENV" "SESSION_BUNDLE_BLOCKER_COUNT" "${COMMAND_PLAN_BLOCKER_COUNT:-0}"

cat > "$SESSION_BUNDLE_DIR/metadata/key-input-artifact-paths.txt" <<EOF
Atlantis shiba key input artifact paths
======================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

- boot-artifact stage: $BOOT_ARTIFACT_REF
- compose stage: $COMPOSE_STAGE_REF
- generic rootfs: $ROOTFS_REF
- package feed: $PACKAGE_FEED_REF
- kernel artifact: $KERNEL_REF
- initramfs artifact: $INITRAMFS_REF
- live decision directory: $FLASHING_DECISION_DIR
- live review-status file: $DECISION_REVIEW_STATUS_FILE
- command-plan directory: $COMMAND_PLAN_DIR
- readiness directory: $READINESS_DIR
- evidence bundle directory: $EVIDENCE_BUNDLE_DIR
- decision-review directory: $DECISION_REVIEW_DIR
EOF

cat > "$SESSION_BUNDLE_DIR/checklists/operator-session-checklist.txt" <<EOF
Atlantis shiba operator session checklist
=========================================

Session bundle classification: ${READINESS_CLASSIFICATION:-blocked}
Active profile: $PROFILE_NAME
Profile file: $PROFILE

Manual confirmation points:
- profile still matches the intended shiba session: yes/no
- kernel artifact reference currently points to: $KERNEL_REF
- initramfs artifact reference currently points to: $INITRAMFS_REF
- boot-artifact stage currently points to: $BOOT_ARTIFACT_REF
- generic rootfs currently points to: $ROOTFS_REF
- package feed currently points to: $PACKAGE_FEED_REF
- partition targets still unresolved: ${PARTITION_TARGETS_UNRESOLVED:-yes}
- AVB/vbmeta policy still unresolved: ${AVB_POLICY_UNRESOLVED:-yes}
- slot strategy still unresolved: ${SLOT_STRATEGY_UNRESOLVED:-yes}
- boot-input provenance still unresolved: ${BOOT_INPUT_PROVENANCE_UNRESOLVED:-yes}
- decision review summary present: ${DECISION_REVIEW_PRESENT:-no}
- decision apply summary present: ${DECISION_REVIEW_APPLIED:-no}
- evidence bundle result: ${EVIDENCE_RESULT:-missing}
- command-plan result: ${COMMAND_PLAN_RESULT:-blocked}
- flashing remains blocked: ${FLASHING_REMAINS_BLOCKED:-yes}

Operator reminder:
- this session bundle does not perform the session
- this session bundle does not generate real flashing commands
- this session bundle does not claim Pixel 8 boots
EOF

cat > "$SESSION_BUNDLE_DIR/notes/non-claims.txt" <<EOF
Atlantis shiba session-bundle non-claims
=======================================

- This bundle is a preparation boundary only.
- This bundle is not a fastboot execution bundle.
- This bundle does not invoke fastboot.
- This bundle does not invoke adb.
- This bundle does not reboot, erase, or flash anything.
- This bundle does not imply flashing is safe or implemented.
- This bundle does not claim Pixel 8 boots.
EOF

cat > "$SESSION_BUNDLE_DIR/notes/session-bundle-contract.txt" <<EOF
Atlantis shiba operator-session bundle contract
==============================================

Session bundle classification: ${READINESS_CLASSIFICATION:-blocked}
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Consumed inputs:
- readiness-check directory: $READINESS_DIR
- command-plan / execution-bundle directory: $COMMAND_PLAN_DIR
- live decision files: $FLASHING_DECISION_DIR
- live review-status file: $DECISION_REVIEW_STATUS_FILE
- installer-preparation directory: $INSTALLER_PREP_DIR
- evidence bundle directory when present: $EVIDENCE_BUNDLE_DIR
- decision-review directory when present: $DECISION_REVIEW_DIR

Produced output:
- operator-session bundle directory: $SESSION_BUNDLE_DIR

Boundary notes:
- Readiness-check is a safety boundary only.
- This session bundle is a preparation boundary only.
- Neither boundary implies Pixel 8 boots.
- Neither boundary implies flashing is safe or implemented.
EOF

cat > "$SESSION_BUNDLE_DIR/README.txt" <<EOF
Atlantis shiba operator-session bundle
=====================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Session bundle classification: ${READINESS_CLASSIFICATION:-blocked}

This directory exists to make a future manual hardware session easy to inspect and archive.
It contains the live decision files, the live review-status file, the command-plan summary, the readiness summary, explicit blockers, and an operator checklist.
It does not perform a flashing session.
It does not generate fake success states.
It does not claim Pixel 8 boots.
EOF

echo "Atlantis shiba operator-session bundle created at $SESSION_BUNDLE_DIR"
echo "Session bundle classification: ${READINESS_CLASSIFICATION:-blocked}"
