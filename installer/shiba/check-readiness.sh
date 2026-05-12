#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-readiness
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
COMMAND_PLAN_SUMMARY_FILE="$COMMAND_PLAN_DIR/metadata/command-plan-summary.env"
EVIDENCE_SUMMARY_FILE="$EVIDENCE_BUNDLE_DIR/metadata/evidence-summary.env"

# shellcheck disable=SC1090
. "$PARTITION_DECISIONS_FILE"
# shellcheck disable=SC1090
. "$AVB_DECISIONS_FILE"
# shellcheck disable=SC1090
. "$SLOT_DECISIONS_FILE"
# shellcheck disable=SC1090
. "$PROVENANCE_DECISIONS_FILE"
# shellcheck disable=SC1090
. "$DECISION_REVIEW_STATUS_FILE"
# shellcheck disable=SC1090
. "$COMMAND_PLAN_SUMMARY_FILE"

PARTITION_FIELDS="ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET ATLANTIS_SHIBA_PARTITION_TARGET_NOTES"
AVB_FIELDS="ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE ATLANTIS_SHIBA_AVB_VBMETA_TARGET ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT ATLANTIS_SHIBA_AVB_POLICY_NOTES"
SLOT_FIELDS="ATLANTIS_SHIBA_SLOT_EVIDENCE ATLANTIS_SHIBA_SLOT_READ_METHOD ATLANTIS_SHIBA_SLOT_TARGET_POLICY ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY ATLANTIS_SHIBA_SLOT_NOTES"
PROVENANCE_FIELDS="ATLANTIS_SHIBA_KERNEL_PROVENANCE ATLANTIS_SHIBA_INITRAMFS_PROVENANCE ATLANTIS_SHIBA_FIRMWARE_PROVENANCE ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE ATLANTIS_SHIBA_BOOT_INPUT_NOTES"

field_current_value() {
    field_name=$1
    eval "printf '%s' \"\${$field_name-}\""
}

domain_is_unresolved() {
    field_list=$1

    for field_name in $field_list; do
        if atlantis_value_is_unresolved "$(field_current_value "$field_name")"; then
            return 0
        fi
    done

    return 1
}

reference_value() {
    metadata_file=$1
    atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/$metadata_file"
}

rm -rf "$READINESS_DIR"
mkdir -p \
    "$READINESS_DIR/metadata" \
    "$READINESS_DIR/checklists" \
    "$READINESS_DIR/blockers" \
    "$READINESS_DIR/notes" \
    "$READINESS_DIR/bundle/decisions"

ln -sfn "$INSTALLER_PREP_DIR" "$READINESS_DIR/installer-preparation"
ln -sfn "$COMMAND_PLAN_DIR" "$READINESS_DIR/command-plan"
ln -sfn "$FLASHING_DECISION_DIR" "$READINESS_DIR/flashing-decisions"
ln -sfn "$DECISION_REVIEW_DIR" "$READINESS_DIR/decision-review"
if [ -d "$EVIDENCE_BUNDLE_DIR" ]; then
    ln -sfn "$EVIDENCE_BUNDLE_DIR" "$READINESS_DIR/evidence-bundle"
fi

cp "$PROFILE" "$READINESS_DIR/active-profile.env"
cp "$PARTITION_DECISIONS_FILE" "$READINESS_DIR/bundle/decisions/"
cp "$AVB_DECISIONS_FILE" "$READINESS_DIR/bundle/decisions/"
cp "$SLOT_DECISIONS_FILE" "$READINESS_DIR/bundle/decisions/"
cp "$PROVENANCE_DECISIONS_FILE" "$READINESS_DIR/bundle/decisions/"
cp "$DECISION_REVIEW_STATUS_FILE" "$READINESS_DIR/bundle/decisions/"
cp "$COMMAND_PLAN_SUMMARY_FILE" "$READINESS_DIR/metadata/"

BOOT_ARTIFACT_REF=$(reference_value "boot-artifact-stage.path")
COMPOSE_STAGE_REF=$(reference_value "compose-stage.path")
ROOTFS_REF=$(reference_value "generic-rootfs.path")
PACKAGE_FEED_REF=$(reference_value "package-feed.path")
KERNEL_REF=$(reference_value "kernel-artifact.path")
INITRAMFS_REF=$(reference_value "initramfs-artifact.path")

MISSING_REFERENCES_FILE="$READINESS_DIR/blockers/missing-referenced-paths.txt"
ALL_BLOCKERS_FILE="$READINESS_DIR/blockers/all-blockers.txt"
: > "$MISSING_REFERENCES_FILE"
: > "$ALL_BLOCKERS_FILE"
missing_reference_count=0

record_missing_reference() {
    label=$1
    path_value=$2
    if [ -n "$path_value" ] && [ -e "$path_value" ]; then
        return 0
    fi

    missing_reference_count=$((missing_reference_count + 1))
    printf '%s\n' "- $label: $path_value" >> "$MISSING_REFERENCES_FILE"
    printf '%s\n' "- missing reference [$label]: $path_value" >> "$ALL_BLOCKERS_FILE"
    return 1
}

record_missing_reference "boot-artifact stage" "$BOOT_ARTIFACT_REF"
record_missing_reference "compose stage" "$COMPOSE_STAGE_REF"
record_missing_reference "generic rootfs" "$ROOTFS_REF"
record_missing_reference "package feed" "$PACKAGE_FEED_REF"
record_missing_reference "kernel artifact" "$KERNEL_REF"
record_missing_reference "initramfs artifact" "$INITRAMFS_REF"

partition_targets_unresolved="no"
avb_policy_unresolved="no"
slot_strategy_unresolved="no"
provenance_unresolved="no"

if domain_is_unresolved "$PARTITION_FIELDS"; then
    partition_targets_unresolved="yes"
fi
if domain_is_unresolved "$AVB_FIELDS"; then
    avb_policy_unresolved="yes"
fi
if domain_is_unresolved "$SLOT_FIELDS"; then
    slot_strategy_unresolved="yes"
fi
if domain_is_unresolved "$PROVENANCE_FIELDS"; then
    provenance_unresolved="yes"
fi

evidence_bundle_present="no"
evidence_result="missing"
if [ -f "$EVIDENCE_SUMMARY_FILE" ]; then
    evidence_bundle_present="yes"
    evidence_result=$(atlantis_value_from_env_file "$EVIDENCE_SUMMARY_FILE" "EVIDENCE_RESULT")
    if [ -z "$evidence_result" ]; then
        evidence_result="missing"
    fi
fi

decision_review_present="no"
decision_review_applied="no"
if [ -d "$DECISION_REVIEW_DIR" ] && [ -f "$DECISION_REVIEW_DIR/active-profile.env" ]; then
    decision_review_present="yes"
fi
if [ -f "$DECISION_REVIEW_DIR/metadata/decision-apply-summary.env" ]; then
    decision_review_applied="yes"
fi

command_plan_result=${COMMAND_PLAN_RESULT:-blocked}
command_plan_blocker_count=${COMMAND_PLAN_BLOCKER_COUNT:-0}

if [ "$command_plan_result" != "reviewable" ] || [ "$missing_reference_count" -gt 0 ]; then
    readiness_classification="blocked"
elif [ "$evidence_bundle_present" != "yes" ] || [ "$decision_review_present" != "yes" ] || [ "$decision_review_applied" != "yes" ] || [ "$evidence_result" != "evidence-captured-successfully" ]; then
    readiness_classification="review-ready"
else
    readiness_classification="session-ready"
fi

if [ -f "$COMMAND_PLAN_DIR/blockers/all-blockers.txt" ]; then
    cat "$COMMAND_PLAN_DIR/blockers/all-blockers.txt" >> "$ALL_BLOCKERS_FILE"
fi

SUMMARY_ENV="$READINESS_DIR/metadata/readiness-summary.env"
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
atlantis_write_kv "$SUMMARY_ENV" "READINESS_CLASSIFICATION" "$readiness_classification"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_RESULT" "$command_plan_result"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_BLOCKER_COUNT" "$command_plan_blocker_count"
atlantis_write_kv "$SUMMARY_ENV" "MISSING_REFERENCED_PATH_COUNT" "$missing_reference_count"
atlantis_write_kv "$SUMMARY_ENV" "EVIDENCE_BUNDLE_PRESENT" "$evidence_bundle_present"
atlantis_write_kv "$SUMMARY_ENV" "EVIDENCE_RESULT" "$evidence_result"
atlantis_write_kv "$SUMMARY_ENV" "DECISION_REVIEW_PRESENT" "$decision_review_present"
atlantis_write_kv "$SUMMARY_ENV" "DECISION_REVIEW_APPLIED" "$decision_review_applied"
atlantis_write_kv "$SUMMARY_ENV" "PARTITION_TARGETS_UNRESOLVED" "$partition_targets_unresolved"
atlantis_write_kv "$SUMMARY_ENV" "AVB_POLICY_UNRESOLVED" "$avb_policy_unresolved"
atlantis_write_kv "$SUMMARY_ENV" "SLOT_STRATEGY_UNRESOLVED" "$slot_strategy_unresolved"
atlantis_write_kv "$SUMMARY_ENV" "BOOT_INPUT_PROVENANCE_UNRESOLVED" "$provenance_unresolved"
atlantis_write_kv "$SUMMARY_ENV" "FLASHING_REMAINS_BLOCKED" "$( [ "$readiness_classification" = "blocked" ] && printf yes || printf no )"

cat > "$READINESS_DIR/notes/readiness-contract.txt" <<EOF
Atlantis shiba readiness-check contract
======================================

Readiness classification: $readiness_classification
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Consumed inputs:
- command-plan / execution-bundle directory: $COMMAND_PLAN_DIR
- live structured decision files: $FLASHING_DECISION_DIR
- live review-status file: $DECISION_REVIEW_STATUS_FILE
- installer-preparation directory: $INSTALLER_PREP_DIR
- evidence bundle directory when present: $EVIDENCE_BUNDLE_DIR
- decision-review directory when present: $DECISION_REVIEW_DIR

Boundary notes:
- Readiness is a safety boundary only.
- It does not invoke fastboot.
- It does not invoke adb.
- It does not flash any partition.
- It does not claim Pixel 8 boots.
- It does not claim flashing is safe or implemented.
EOF

cat > "$READINESS_DIR/checklists/operator-session-checklist.txt" <<EOF
Atlantis shiba operator session checklist
=========================================

Current readiness classification: $readiness_classification
Active profile: $PROFILE_NAME
Profile file: $PROFILE
Future session-bundle directory: $SESSION_BUNDLE_DIR

Explicit confirmations:
- profile is active: yes
- kernel artifact being referenced: $KERNEL_REF
- initramfs artifact being referenced: $INITRAMFS_REF
- partition targets still unresolved: $partition_targets_unresolved
- AVB/vbmeta policy still unresolved: $avb_policy_unresolved
- slot strategy still unresolved: $slot_strategy_unresolved
- boot-input provenance still unresolved: $provenance_unresolved
- command-plan result: $command_plan_result
- evidence bundle present: $evidence_bundle_present
- decision review present: $decision_review_present
- decision review applied summary present: $decision_review_applied
- flashing remains blocked: $( [ "$readiness_classification" = "blocked" ] && printf yes || printf no )

Referenced paths:
- boot-artifact stage: $BOOT_ARTIFACT_REF
- compose stage: $COMPOSE_STAGE_REF
- generic rootfs: $ROOTFS_REF
- package feed: $PACKAGE_FEED_REF
- kernel artifact: $KERNEL_REF
- initramfs artifact: $INITRAMFS_REF

Operator reminder:
- this checklist does not perform a hardware session
- this checklist does not generate real flashing commands
- this checklist does not claim Pixel 8 boots
EOF

cat > "$READINESS_DIR/README.txt" <<EOF
Atlantis shiba readiness-check directory
=======================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Readiness classification: $readiness_classification

This directory explains whether the current repo state is still blocked, review-ready, or session-ready for a future manual hardware session.
It consumes the command-plan output, the live decision files, the live review-status file, and installer or evidence context when present.
It is a safety boundary only.
It does not invoke fastboot.
It does not invoke adb.
It does not flash anything.
It does not claim Pixel 8 boots.
EOF

echo "Atlantis shiba readiness output created at $READINESS_DIR"
echo "Readiness classification: $readiness_classification"
