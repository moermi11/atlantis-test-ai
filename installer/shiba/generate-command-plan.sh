#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-command-plan
atlantis_load_profile "$DEFAULT_PROFILE"

INSTALLER_PREP_DIR=$(atlantis_path_from_repo "${ATLANTIS_INSTALLER_PREP_DIR:-}")
FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
COMMAND_PLAN_DIR=$(atlantis_path_from_repo "${ATLANTIS_COMMAND_PLAN_DIR:-}")
DECISION_REVIEW_STATUS_FILE=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}")
DECISION_REVIEW_DIR=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_DIR:-}")

PARTITION_DECISIONS_FILE="$FLASHING_DECISION_DIR/partition-targets.env"
AVB_DECISIONS_FILE="$FLASHING_DECISION_DIR/avb-vbmeta-policy.env"
SLOT_DECISIONS_FILE="$FLASHING_DECISION_DIR/slot-strategy.env"
PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_DIR/boot-input-provenance.env"

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

PARTITION_FIELDS="ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET ATLANTIS_SHIBA_PARTITION_TARGET_NOTES"
AVB_FIELDS="ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE ATLANTIS_SHIBA_AVB_VBMETA_TARGET ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT ATLANTIS_SHIBA_AVB_POLICY_NOTES"
SLOT_FIELDS="ATLANTIS_SHIBA_SLOT_EVIDENCE ATLANTIS_SHIBA_SLOT_READ_METHOD ATLANTIS_SHIBA_SLOT_TARGET_POLICY ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY ATLANTIS_SHIBA_SLOT_NOTES"
PROVENANCE_FIELDS="ATLANTIS_SHIBA_KERNEL_PROVENANCE ATLANTIS_SHIBA_INITRAMFS_PROVENANCE ATLANTIS_SHIBA_FIRMWARE_PROVENANCE ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE ATLANTIS_SHIBA_BOOT_INPUT_NOTES"
ALL_FIELDS="$PARTITION_FIELDS $AVB_FIELDS $SLOT_FIELDS $PROVENANCE_FIELDS"

rm -rf "$COMMAND_PLAN_DIR"
mkdir -p \
    "$COMMAND_PLAN_DIR/metadata" \
    "$COMMAND_PLAN_DIR/plans" \
    "$COMMAND_PLAN_DIR/blockers" \
    "$COMMAND_PLAN_DIR/bundle/decisions"

ln -sfn "$INSTALLER_PREP_DIR" "$COMMAND_PLAN_DIR/installer-preparation"
ln -sfn "$FLASHING_DECISION_DIR" "$COMMAND_PLAN_DIR/flashing-decisions"
ln -sfn "$DECISION_REVIEW_DIR" "$COMMAND_PLAN_DIR/decision-review"

cp "$PROFILE" "$COMMAND_PLAN_DIR/active-profile.env"
cp "$PARTITION_DECISIONS_FILE" "$COMMAND_PLAN_DIR/bundle/decisions/"
cp "$AVB_DECISIONS_FILE" "$COMMAND_PLAN_DIR/bundle/decisions/"
cp "$SLOT_DECISIONS_FILE" "$COMMAND_PLAN_DIR/bundle/decisions/"
cp "$PROVENANCE_DECISIONS_FILE" "$COMMAND_PLAN_DIR/bundle/decisions/"
cp "$DECISION_REVIEW_STATUS_FILE" "$COMMAND_PLAN_DIR/bundle/decisions/"

printf '%s\n' "$INSTALLER_PREP_DIR" > "$COMMAND_PLAN_DIR/metadata/installer-preparation.path"
printf '%s\n' "$FLASHING_DECISION_DIR" > "$COMMAND_PLAN_DIR/metadata/flashing-decision-dir.path"
printf '%s\n' "$DECISION_REVIEW_STATUS_FILE" > "$COMMAND_PLAN_DIR/metadata/decision-review-status.path"
printf '%s\n' "$DECISION_REVIEW_DIR" > "$COMMAND_PLAN_DIR/metadata/decision-review-dir.path"
printf '%s\n' "$PARTITION_DECISIONS_FILE" > "$COMMAND_PLAN_DIR/metadata/partition-decisions.path"
printf '%s\n' "$AVB_DECISIONS_FILE" > "$COMMAND_PLAN_DIR/metadata/avb-decisions.path"
printf '%s\n' "$SLOT_DECISIONS_FILE" > "$COMMAND_PLAN_DIR/metadata/slot-decisions.path"
printf '%s\n' "$PROVENANCE_DECISIONS_FILE" > "$COMMAND_PLAN_DIR/metadata/boot-input-provenance.path"

ALL_BLOCKERS_FILE="$COMMAND_PLAN_DIR/blockers/all-blockers.txt"
UNRESOLVED_BLOCKERS_FILE="$COMMAND_PLAN_DIR/blockers/unresolved-fields.txt"
DEFERRED_BLOCKERS_FILE="$COMMAND_PLAN_DIR/blockers/evidence-backed-deferred-fields.txt"
UNREVIEWED_BLOCKERS_FILE="$COMMAND_PLAN_DIR/blockers/unreviewed-or-unapplied-fields.txt"
REJECTED_BLOCKERS_FILE="$COMMAND_PLAN_DIR/blockers/rejected-or-insufficient-fields.txt"
FIELD_STATUS_FILE="$COMMAND_PLAN_DIR/metadata/field-status.tsv"

: > "$ALL_BLOCKERS_FILE"
: > "$UNRESOLVED_BLOCKERS_FILE"
: > "$DEFERRED_BLOCKERS_FILE"
: > "$UNREVIEWED_BLOCKERS_FILE"
: > "$REJECTED_BLOCKERS_FILE"
printf 'field\tclassification\treview_state\treview_decision\tsuggested_by_evidence\tvalue\n' > "$FIELD_STATUS_FILE"

blocker_count=0
unresolved_count=0
deferred_count=0
unreviewed_count=0
rejected_count=0
applied_count=0

get_value() {
    variable_name=$1
    atlantis_value_from_env_file "$2" "$variable_name"
}

field_current_value() {
    field_name=$1
    eval "printf '%s' \"\${$field_name-}\""
}

field_status_value() {
    field_name=$1
    suffix=$2
    eval "printf '%s' \"\${${field_name}_${suffix}-}\""
}

record_field_status() {
    field_name=$1
    classification=$2
    review_state=$3
    review_decision=$4
    suggested_by_evidence=$5
    field_value=$6

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$field_name" "$classification" "$review_state" "$review_decision" "$suggested_by_evidence" "$field_value" >> "$FIELD_STATUS_FILE"
}

record_blocker() {
    field_name=$1
    classification=$2
    review_state=$3
    review_decision=$4
    field_value=$5

    blocker_count=$((blocker_count + 1))
    printf '%s\n' "- $field_name [$classification] value=$field_value review_state=$review_state review_decision=$review_decision" >> "$ALL_BLOCKERS_FILE"

    case "$classification" in
        unresolved)
            unresolved_count=$((unresolved_count + 1))
            printf '%s\n' "- $field_name" >> "$UNRESOLVED_BLOCKERS_FILE"
            ;;
        evidence-backed-but-deferred)
            deferred_count=$((deferred_count + 1))
            printf '%s\n' "- $field_name" >> "$DEFERRED_BLOCKERS_FILE"
            ;;
        reviewed-but-rejected | reviewed-but-unresolved)
            rejected_count=$((rejected_count + 1))
            printf '%s\n' "- $field_name" >> "$REJECTED_BLOCKERS_FILE"
            ;;
        *)
            unreviewed_count=$((unreviewed_count + 1))
            printf '%s\n' "- $field_name" >> "$UNREVIEWED_BLOCKERS_FILE"
            ;;
    esac
}

classify_field() {
    field_name=$1

    current_value=$(field_current_value "$field_name")
    review_state=$(field_status_value "$field_name" "REVIEW_STATE")
    review_decision=$(field_status_value "$field_name" "REVIEW_DECISION")
    suggested_by_evidence=$(field_status_value "$field_name" "SUGGESTED_BY_EVIDENCE")
    last_applied_value=$(field_status_value "$field_name" "LAST_APPLIED_VALUE")

    if [ -z "$current_value" ]; then
        current_value="UNRESOLVED"
    fi
    if [ -z "$review_state" ]; then
        review_state="unreviewed"
    fi
    if [ -z "$review_decision" ]; then
        review_decision="unreviewed"
    fi
    if [ -z "$suggested_by_evidence" ]; then
        suggested_by_evidence="no"
    fi
    if [ -z "$last_applied_value" ]; then
        last_applied_value="UNRESOLVED"
    fi

    if atlantis_value_is_unresolved "$current_value"; then
        if [ "$review_state" = "reviewed-unresolved" ]; then
            classification="reviewed-but-unresolved"
        else
            classification="unresolved"
        fi
    elif [ "$review_state" = "reviewed-applied" ]; then
        classification="reviewed-and-applied"
    elif [ "$review_state" = "reviewed-deferred" ] && [ "$suggested_by_evidence" = "yes" ]; then
        classification="evidence-backed-but-deferred"
    elif [ "$review_state" = "reviewed-rejected" ]; then
        classification="reviewed-but-rejected"
    else
        classification="unreviewed-or-unapplied"
    fi

    record_field_status "$field_name" "$classification" "$review_state" "$review_decision" "$suggested_by_evidence" "$current_value"

    if [ "$classification" = "reviewed-and-applied" ]; then
        applied_count=$((applied_count + 1))
    else
        record_blocker "$field_name" "$classification" "$review_state" "$review_decision" "$current_value"
    fi
}

for field_name in $ALL_FIELDS; do
    classify_field "$field_name"
done

if [ "$blocker_count" -eq 0 ]; then
    command_plan_result="reviewable"
    command_plan_sufficient="yes"
else
    command_plan_result="blocked"
    command_plan_sufficient="no"
fi

SUMMARY_ENV="$COMMAND_PLAN_DIR/metadata/command-plan-summary.env"
: > "$SUMMARY_ENV"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"
atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_RESULT" "$command_plan_result"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_SUFFICIENT_FOR_FUTURE_COMMAND_GENERATION" "$command_plan_sufficient"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_BLOCKER_COUNT" "$blocker_count"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_REVIEWED_AND_APPLIED_COUNT" "$applied_count"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_UNRESOLVED_COUNT" "$unresolved_count"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_DEFERRED_COUNT" "$deferred_count"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_UNREVIEWED_COUNT" "$unreviewed_count"
atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_REJECTED_COUNT" "$rejected_count"

cat > "$COMMAND_PLAN_DIR/plans/command-plan-contract.txt" <<EOF
Atlantis shiba command-plan contract
===================================

Plan result: $command_plan_result
Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

Consumed inputs:
- staged installer-preparation directory: $INSTALLER_PREP_DIR
- structured flashing-decision directory: $FLASHING_DECISION_DIR
- decision review status file: $DECISION_REVIEW_STATUS_FILE

Produced output:
- command-plan / execution-bundle directory: $COMMAND_PLAN_DIR

Boundary notes:
- This directory is a review boundary only.
- It distinguishes unresolved fields, evidence-backed deferred fields, and reviewed-applied fields.
- It does not invoke fastboot.
- It does not invoke adb.
- It does not flash any partition.
- It does not claim Pixel 8 boots.
EOF

if [ "$command_plan_result" = "blocked" ]; then
    cat > "$COMMAND_PLAN_DIR/plans/command-plan.txt" <<EOF
Atlantis shiba command plan
===========================

Plan result: blocked
Decision files present and reviewable: yes
Decision review status present and reviewable: yes
Sufficient for future command generation: no

Why blocked:
- one or more required fields are still insufficient for future command drafting
- fields must be both concrete and explicitly reviewed-applied before this plan can become reviewable

Blocker summary:
- unresolved fields: $unresolved_count
- evidence-backed but deferred fields: $deferred_count
- unreviewed or unapplied fields: $unreviewed_count
- rejected or still-insufficient reviewed fields: $rejected_count

Next obvious review step:
- if blockers are evidence-backed but deferred, review approval manifests under: $DECISION_REVIEW_DIR/approvals/
- if blockers are unresolved or unreviewed, refresh evidence or review decisions with: sh ./installer/shiba/review-decisions.sh

All blocking fields:
EOF
    cat "$ALL_BLOCKERS_FILE" >> "$COMMAND_PLAN_DIR/plans/command-plan.txt"
    cat >> "$COMMAND_PLAN_DIR/plans/command-plan.txt" <<EOF

Decision files:
- $PARTITION_DECISIONS_FILE
- $AVB_DECISIONS_FILE
- $SLOT_DECISIONS_FILE
- $PROVENANCE_DECISIONS_FILE
- $DECISION_REVIEW_STATUS_FILE

Explicit non-claims:
- this is not a flashing-ready bundle
- this is not a fastboot command sequence
- this does not prove Pixel 8 boots
EOF
else
    cat > "$COMMAND_PLAN_DIR/plans/command-plan.txt" <<EOF
Atlantis shiba command plan
===========================

Plan result: reviewable
Decision files present and reviewable: yes
Decision review status present and reviewable: yes
Sufficient for future command generation: yes

Current scope:
- all required fields are now concrete and explicitly reviewed-applied
- this script still does not emit fastboot or adb commands automatically
- future real flashing logic remains separate planned work

Reviewed decision files:
- $PARTITION_DECISIONS_FILE
- $AVB_DECISIONS_FILE
- $SLOT_DECISIONS_FILE
- $PROVENANCE_DECISIONS_FILE
- $DECISION_REVIEW_STATUS_FILE

Explicit non-claims:
- this is not a flashing run
- this does not change device-side state
- this does not prove Pixel 8 boots
EOF
fi

cat > "$COMMAND_PLAN_DIR/README.txt" <<EOF
Atlantis shiba command-plan / execution-bundle directory
=======================================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Plan result: $command_plan_result
Decision files present and reviewable: yes
Decision review status present and reviewable: yes
Sufficient for future command generation: $command_plan_sufficient

This directory exists to make flashing decisions reviewable before any future real flashing flow is drafted.
It consumes the staged installer-preparation directory, the structured flashing-decision files, and the applied review status file.
It does not invoke fastboot.
It does not invoke adb.
It does not flash any partition.
It does not claim the result is flashable.
It does not claim Pixel 8 boots.
EOF

echo "Atlantis shiba command-plan output created at $COMMAND_PLAN_DIR"
echo "This output is a reviewable command-plan boundary only."
