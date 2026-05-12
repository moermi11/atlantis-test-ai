#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-evidence
atlantis_load_profile "$DEFAULT_PROFILE"

INSTALLER_PREP_DIR=$(atlantis_path_from_repo "${ATLANTIS_INSTALLER_PREP_DIR:-}")
FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
COMMAND_PLAN_DIR=$(atlantis_path_from_repo "${ATLANTIS_COMMAND_PLAN_DIR:-}")
EVIDENCE_BUNDLE_DIR=$(atlantis_path_from_repo "${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}")
DECISION_REVIEW_DIR=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_DIR:-}")

PARTITION_DECISIONS_FILE="$FLASHING_DECISION_DIR/partition-targets.env"
AVB_DECISIONS_FILE="$FLASHING_DECISION_DIR/avb-vbmeta-policy.env"
SLOT_DECISIONS_FILE="$FLASHING_DECISION_DIR/slot-strategy.env"
PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_DIR/boot-input-provenance.env"

INSTALLER_KERNEL_ARTIFACT=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/kernel-artifact.path")
INSTALLER_INITRAMFS_ARTIFACT=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/initramfs-artifact.path")
INSTALLER_BOOT_ARTIFACT_DIR=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/boot-artifact-stage.path")

rm -rf "$EVIDENCE_BUNDLE_DIR"
mkdir -p \
    "$EVIDENCE_BUNDLE_DIR/metadata" \
    "$EVIDENCE_BUNDLE_DIR/commands" \
    "$EVIDENCE_BUNDLE_DIR/probes" \
    "$EVIDENCE_BUNDLE_DIR/suggestions" \
    "$EVIDENCE_BUNDLE_DIR/notes" \
    "$EVIDENCE_BUNDLE_DIR/unresolved"

ln -sfn "$INSTALLER_PREP_DIR" "$EVIDENCE_BUNDLE_DIR/installer-preparation"
ln -sfn "$FLASHING_DECISION_DIR" "$EVIDENCE_BUNDLE_DIR/flashing-decisions"

cp "$PROFILE" "$EVIDENCE_BUNDLE_DIR/active-profile.env"

ATTEMPTED_COMMANDS_FILE="$EVIDENCE_BUNDLE_DIR/commands/attempted-probe-commands.txt"
ATTEMPTED_COUNT=0
CAPTURED_COUNT=0

record_attempted_command() {
    command_string=$1
    ATTEMPTED_COUNT=$((ATTEMPTED_COUNT + 1))
    printf '%s\n' "$command_string" >> "$ATTEMPTED_COMMANDS_FILE"
}

capture_probe() {
    probe_name=$1
    command_string=$2
    output_file="$EVIDENCE_BUNDLE_DIR/probes/$probe_name.txt"

    record_attempted_command "$command_string"
    if sh -c "$command_string" > "$output_file" 2>&1; then
        CAPTURED_COUNT=$((CAPTURED_COUNT + 1))
        return 0
    fi

    return 1
}

FASTBOOT_AVAILABLE="no"
ADB_AVAILABLE="no"

if atlantis_command_available fastboot; then
    FASTBOOT_AVAILABLE="yes"
fi

if atlantis_command_available adb; then
    ADB_AVAILABLE="yes"
fi

FASTBOOT_DEVICE_DETECTED="no"
ADB_DEVICE_DETECTED="no"
ADB_DEVICE_READY="no"

if [ "$FASTBOOT_AVAILABLE" = "yes" ]; then
    capture_probe "fastboot-devices" "fastboot devices" || true
    if [ -f "$EVIDENCE_BUNDLE_DIR/probes/fastboot-devices.txt" ] && awk 'NF >= 2 && $2 == "fastboot" { found=1 } END { exit(found ? 0 : 1) }' "$EVIDENCE_BUNDLE_DIR/probes/fastboot-devices.txt"; then
        FASTBOOT_DEVICE_DETECTED="yes"
        capture_probe "fastboot-getvar-product" "fastboot getvar product" || true
        capture_probe "fastboot-getvar-current-slot" "fastboot getvar current-slot" || true
        capture_probe "fastboot-getvar-slot-count" "fastboot getvar slot-count" || true
        capture_probe "fastboot-getvar-unlocked" "fastboot getvar unlocked" || true
        capture_probe "fastboot-getvar-secure" "fastboot getvar secure" || true
    fi
fi

if [ "$ADB_AVAILABLE" = "yes" ]; then
    capture_probe "adb-devices-l" "adb devices -l" || true
    if [ -f "$EVIDENCE_BUNDLE_DIR/probes/adb-devices-l.txt" ] && awk 'NF >= 2 && $1 != "List" { found=1 } END { exit(found ? 0 : 1) }' "$EVIDENCE_BUNDLE_DIR/probes/adb-devices-l.txt"; then
        ADB_DEVICE_DETECTED="yes"
    fi
    if [ -f "$EVIDENCE_BUNDLE_DIR/probes/adb-devices-l.txt" ] && awk 'NF >= 2 && $1 != "List" && $2 == "device" { found=1 } END { exit(found ? 0 : 1) }' "$EVIDENCE_BUNDLE_DIR/probes/adb-devices-l.txt"; then
        ADB_DEVICE_READY="yes"
        capture_probe "adb-shell-getprop-device" "adb shell getprop ro.product.device" || true
        capture_probe "adb-shell-getprop-slot-suffix" "adb shell getprop ro.boot.slot_suffix" || true
        capture_probe "adb-shell-getprop-verifiedbootstate" "adb shell getprop ro.boot.verifiedbootstate" || true
        capture_probe "adb-shell-getprop-vbmeta-device-state" "adb shell getprop ro.boot.vbmeta.device_state" || true
        capture_probe "adb-shell-getprop-flash-locked" "adb shell getprop ro.boot.flash.locked" || true
        capture_probe "adb-shell-cat-proc-cmdline" "adb shell cat /proc/cmdline" || true
    fi
fi

PARTITION_EVIDENCE="UNRESOLVED"
PARTITION_BOOT_TARGET="UNRESOLVED"
PARTITION_INITRAMFS_TARGET="UNRESOLVED"
PARTITION_ROOTFS_HANDOFF_TARGET="UNRESOLVED"
PARTITION_NOTES="UNRESOLVED"

if [ "$FASTBOOT_DEVICE_DETECTED" = "yes" ] || [ "$ADB_DEVICE_READY" = "yes" ]; then
    PARTITION_EVIDENCE="$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-product.txt;$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-current-slot.txt;$EVIDENCE_BUNDLE_DIR/probes/adb-shell-cat-proc-cmdline.txt"
    PARTITION_NOTES="Read-only probe evidence captured, but partition target roles remain unresolved pending device-specific mapping review."
fi

AVB_EVIDENCE="UNRESOLVED"
AVB_VBMETA_TARGET="UNRESOLVED"
AVB_VERIFICATION_APPROACH="UNRESOLVED"
AVB_WRITE_REQUIREMENT="UNRESOLVED"
AVB_NOTES="UNRESOLVED"

if [ "$FASTBOOT_DEVICE_DETECTED" = "yes" ] || [ "$ADB_DEVICE_READY" = "yes" ]; then
    AVB_EVIDENCE="$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-unlocked.txt;$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-secure.txt;$EVIDENCE_BUNDLE_DIR/probes/adb-shell-getprop-verifiedbootstate.txt;$EVIDENCE_BUNDLE_DIR/probes/adb-shell-getprop-vbmeta-device-state.txt;$EVIDENCE_BUNDLE_DIR/probes/adb-shell-getprop-flash-locked.txt"
    AVB_NOTES="Read-only boot-state evidence captured, but vbmeta target and verification policy remain unresolved pending review."
fi

SLOT_EVIDENCE="UNRESOLVED"
SLOT_READ_METHOD="UNRESOLVED"
SLOT_TARGET_POLICY="UNRESOLVED"
SLOT_FALLBACK_POLICY="UNRESOLVED"
SLOT_NOTES="UNRESOLVED"

if [ "$FASTBOOT_DEVICE_DETECTED" = "yes" ]; then
    SLOT_EVIDENCE="$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-current-slot.txt;$EVIDENCE_BUNDLE_DIR/probes/fastboot-getvar-slot-count.txt"
    SLOT_READ_METHOD="fastboot getvar current-slot"
    SLOT_NOTES="Fastboot slot interrogation evidence captured, but slot target and fallback policies remain unresolved."
elif [ "$ADB_DEVICE_READY" = "yes" ]; then
    SLOT_EVIDENCE="$EVIDENCE_BUNDLE_DIR/probes/adb-shell-getprop-slot-suffix.txt"
    SLOT_READ_METHOD="adb shell getprop ro.boot.slot_suffix"
    SLOT_NOTES="ADB slot evidence captured, but slot target and fallback policies remain unresolved."
fi

BOOT_INPUT_PROVENANCE_EVIDENCE="$INSTALLER_PREP_DIR/metadata/kernel-artifact.path;$INSTALLER_PREP_DIR/metadata/initramfs-artifact.path;$INSTALLER_BOOT_ARTIFACT_DIR/manifests/boot-artifact-manifest.env"
KERNEL_PROVENANCE="$INSTALLER_KERNEL_ARTIFACT"
INITRAMFS_PROVENANCE="$INSTALLER_INITRAMFS_ARTIFACT"
FIRMWARE_PROVENANCE="UNRESOLVED"
BOOT_INPUT_NOTES="Installer-preparation metadata confirms current staged kernel and initramfs artifact references; firmware provenance remains unresolved."

cat > "$EVIDENCE_BUNDLE_DIR/suggestions/partition-targets.suggested.env" <<EOF
# Suggested review companion for installer/shiba/decisions/partition-targets.env
# Generated from the read-only shiba evidence bundle. Do not treat as final without review.

ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE='$(atlantis_escape_squote "$PARTITION_EVIDENCE")'
ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET='$(atlantis_escape_squote "$PARTITION_BOOT_TARGET")'
ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET='$(atlantis_escape_squote "$PARTITION_INITRAMFS_TARGET")'
ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET='$(atlantis_escape_squote "$PARTITION_ROOTFS_HANDOFF_TARGET")'
ATLANTIS_SHIBA_PARTITION_TARGET_NOTES='$(atlantis_escape_squote "$PARTITION_NOTES")'
EOF

cat > "$EVIDENCE_BUNDLE_DIR/suggestions/avb-vbmeta-policy.suggested.env" <<EOF
# Suggested review companion for installer/shiba/decisions/avb-vbmeta-policy.env
# Generated from the read-only shiba evidence bundle. Do not treat as final without review.

ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE='$(atlantis_escape_squote "$AVB_EVIDENCE")'
ATLANTIS_SHIBA_AVB_VBMETA_TARGET='$(atlantis_escape_squote "$AVB_VBMETA_TARGET")'
ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH='$(atlantis_escape_squote "$AVB_VERIFICATION_APPROACH")'
ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT='$(atlantis_escape_squote "$AVB_WRITE_REQUIREMENT")'
ATLANTIS_SHIBA_AVB_POLICY_NOTES='$(atlantis_escape_squote "$AVB_NOTES")'
EOF

cat > "$EVIDENCE_BUNDLE_DIR/suggestions/slot-strategy.suggested.env" <<EOF
# Suggested review companion for installer/shiba/decisions/slot-strategy.env
# Generated from the read-only shiba evidence bundle. Do not treat as final without review.

ATLANTIS_SHIBA_SLOT_EVIDENCE='$(atlantis_escape_squote "$SLOT_EVIDENCE")'
ATLANTIS_SHIBA_SLOT_READ_METHOD='$(atlantis_escape_squote "$SLOT_READ_METHOD")'
ATLANTIS_SHIBA_SLOT_TARGET_POLICY='$(atlantis_escape_squote "$SLOT_TARGET_POLICY")'
ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY='$(atlantis_escape_squote "$SLOT_FALLBACK_POLICY")'
ATLANTIS_SHIBA_SLOT_NOTES='$(atlantis_escape_squote "$SLOT_NOTES")'
EOF

cat > "$EVIDENCE_BUNDLE_DIR/suggestions/boot-input-provenance.suggested.env" <<EOF
# Suggested review companion for installer/shiba/decisions/boot-input-provenance.env
# Generated from the read-only shiba evidence bundle. Do not treat as final without review.

ATLANTIS_SHIBA_KERNEL_PROVENANCE='$(atlantis_escape_squote "$KERNEL_PROVENANCE")'
ATLANTIS_SHIBA_INITRAMFS_PROVENANCE='$(atlantis_escape_squote "$INITRAMFS_PROVENANCE")'
ATLANTIS_SHIBA_FIRMWARE_PROVENANCE='$(atlantis_escape_squote "$FIRMWARE_PROVENANCE")'
ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE='$(atlantis_escape_squote "$BOOT_INPUT_PROVENANCE_EVIDENCE")'
ATLANTIS_SHIBA_BOOT_INPUT_NOTES='$(atlantis_escape_squote "$BOOT_INPUT_NOTES")'
EOF

decision_area_count=0
resolved_evidence_area_count=0

count_area() {
    decision_area_count=$((decision_area_count + 1))
    if ! atlantis_value_is_unresolved "$1"; then
        resolved_evidence_area_count=$((resolved_evidence_area_count + 1))
    fi
}

count_area "$PARTITION_EVIDENCE"
count_area "$AVB_EVIDENCE"
count_area "$SLOT_EVIDENCE"
count_area "$BOOT_INPUT_PROVENANCE_EVIDENCE"

if [ "$FASTBOOT_AVAILABLE" = "no" ] && [ "$ADB_AVAILABLE" = "no" ]; then
    EVIDENCE_RESULT="host-tools-missing"
elif [ "$FASTBOOT_DEVICE_DETECTED" = "no" ] && [ "$ADB_DEVICE_DETECTED" = "no" ]; then
    EVIDENCE_RESULT="no-device-detected"
elif [ "$resolved_evidence_area_count" -lt "$decision_area_count" ]; then
    EVIDENCE_RESULT="evidence-still-incomplete"
else
    EVIDENCE_RESULT="evidence-captured-successfully"
fi

FILES_CAPTURED_FILE="$EVIDENCE_BUNDLE_DIR/metadata/files-captured.txt"
find "$EVIDENCE_BUNDLE_DIR/probes" -maxdepth 1 -type f | sort > "$FILES_CAPTURED_FILE"

printf '%s\n' "$INSTALLER_PREP_DIR" > "$EVIDENCE_BUNDLE_DIR/metadata/installer-preparation.path"
printf '%s\n' "$FLASHING_DECISION_DIR" > "$EVIDENCE_BUNDLE_DIR/metadata/flashing-decision-dir.path"
printf '%s\n' "$DECISION_REVIEW_DIR" > "$EVIDENCE_BUNDLE_DIR/metadata/decision-review-dir.path"
printf '%s\n' "$COMMAND_PLAN_DIR" > "$EVIDENCE_BUNDLE_DIR/metadata/command-plan-dir.path"
printf '%s\n' "${ATLANTIS_DEVICE_ID:-unset}" > "$EVIDENCE_BUNDLE_DIR/metadata/device-id.txt"

SUMMARY_ENV="$EVIDENCE_BUNDLE_DIR/metadata/evidence-summary.env"
: > "$SUMMARY_ENV"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_DIR" "$DECISION_REVIEW_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_EVIDENCE_BUNDLE_DIR" "$EVIDENCE_BUNDLE_DIR"
atlantis_write_kv "$SUMMARY_ENV" "HOST_TOOL_FASTBOOT_AVAILABLE" "$FASTBOOT_AVAILABLE"
atlantis_write_kv "$SUMMARY_ENV" "HOST_TOOL_ADB_AVAILABLE" "$ADB_AVAILABLE"
atlantis_write_kv "$SUMMARY_ENV" "FASTBOOT_DEVICE_DETECTED" "$FASTBOOT_DEVICE_DETECTED"
atlantis_write_kv "$SUMMARY_ENV" "ADB_DEVICE_DETECTED" "$ADB_DEVICE_DETECTED"
atlantis_write_kv "$SUMMARY_ENV" "ADB_DEVICE_READY" "$ADB_DEVICE_READY"
atlantis_write_kv "$SUMMARY_ENV" "EVIDENCE_RESULT" "$EVIDENCE_RESULT"
atlantis_write_kv "$SUMMARY_ENV" "ATTEMPTED_PROBE_COMMAND_COUNT" "$ATTEMPTED_COUNT"
atlantis_write_kv "$SUMMARY_ENV" "CAPTURED_PROBE_FILE_COUNT" "$CAPTURED_COUNT"
atlantis_write_kv "$SUMMARY_ENV" "DECISION_AREAS_WITH_EVIDENCE" "$resolved_evidence_area_count"
atlantis_write_kv "$SUMMARY_ENV" "DECISION_AREAS_TOTAL" "$decision_area_count"

cat > "$EVIDENCE_BUNDLE_DIR/notes/evidence-contract.txt" <<EOF
Atlantis shiba evidence-bundle contract
======================================

Evidence result: $EVIDENCE_RESULT
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Boundary notes:
- Structured flashing-decision files remain the source of truth for flashing decisions.
- This evidence bundle is a review boundary only.
- The command-plan / execution-bundle directory remains a separate review boundary at: $COMMAND_PLAN_DIR
- A future real flashing flow remains separate planned work.

Non-claims:
- This stage does not invoke destructive fastboot commands.
- This stage does not reboot, unlock, erase, or flash anything.
- This stage does not modify device-side state.
- This stage does not prove Pixel 8 boots.
EOF

cat > "$EVIDENCE_BUNDLE_DIR/notes/decision-mapping.txt" <<EOF
Atlantis shiba evidence-to-decision mapping
==========================================

Decision file inputs reviewed:
- $PARTITION_DECISIONS_FILE
- $AVB_DECISIONS_FILE
- $SLOT_DECISIONS_FILE
- $PROVENANCE_DECISIONS_FILE

Suggested review companions generated:
- $EVIDENCE_BUNDLE_DIR/suggestions/partition-targets.suggested.env
- $EVIDENCE_BUNDLE_DIR/suggestions/avb-vbmeta-policy.suggested.env
- $EVIDENCE_BUNDLE_DIR/suggestions/slot-strategy.suggested.env
- $EVIDENCE_BUNDLE_DIR/suggestions/boot-input-provenance.suggested.env

Next review step:
- sh ./installer/shiba/review-decisions.sh

What may now be informed:
- partition mapping evidence: $PARTITION_EVIDENCE
- AVB/vbmeta policy evidence: $AVB_EVIDENCE
- slot strategy evidence: $SLOT_EVIDENCE
- boot-input provenance evidence: $BOOT_INPUT_PROVENANCE_EVIDENCE

What remains unresolved unless direct evidence supports it:
- final partition targets
- final vbmeta target and verification approach
- final slot target and fallback policy
- firmware provenance
EOF

cat > "$EVIDENCE_BUNDLE_DIR/unresolved/blockers.txt" <<EOF
Atlantis shiba evidence bundle unresolved blockers
=================================================

- partition target roles remain unresolved without device-specific mapping evidence
- AVB/vbmeta target and write policy remain unresolved without stronger device evidence
- slot target and fallback policy remain unresolved even if slot read evidence exists
- firmware provenance remains unresolved
- evidence capture still does not prove Pixel 8 boots
EOF

cat > "$EVIDENCE_BUNDLE_DIR/README.txt" <<EOF
Atlantis shiba evidence bundle
==============================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Evidence result: $EVIDENCE_RESULT

This directory captures read-only host and device evidence only:
- host tool availability for fastboot and adb
- read-only device detection and interrogation attempts
- review companion suggestions for the structured flashing-decision files

This stage does not reboot the device.
This stage does not unlock the device.
This stage does not erase anything.
This stage does not write anything to partitions.
This stage does not claim Pixel 8 boots.
EOF

echo "Atlantis shiba evidence bundle created at $EVIDENCE_BUNDLE_DIR"
echo "Evidence result: $EVIDENCE_RESULT"
