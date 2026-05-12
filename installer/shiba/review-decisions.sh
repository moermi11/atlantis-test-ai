#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

ACTION=${1:-prepare}

case "$ACTION" in
    prepare)
        PREFLIGHT_MODE="shiba-decision-review"
        ;;
    apply)
        PREFLIGHT_MODE="shiba-decision-apply"
        ;;
    *)
        atlantis_die "Unknown review-decisions action: $ACTION"
        ;;
esac

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" "$PREFLIGHT_MODE"
atlantis_load_profile "$DEFAULT_PROFILE"

FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
EVIDENCE_BUNDLE_DIR=$(atlantis_path_from_repo "${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}")
DECISION_REVIEW_DIR=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_DIR:-}")
DECISION_REVIEW_STATUS_FILE=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}")

PARTITION_DECISIONS_FILE="$FLASHING_DECISION_DIR/partition-targets.env"
AVB_DECISIONS_FILE="$FLASHING_DECISION_DIR/avb-vbmeta-policy.env"
SLOT_DECISIONS_FILE="$FLASHING_DECISION_DIR/slot-strategy.env"
PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_DIR/boot-input-provenance.env"

PARTITION_SUGGESTIONS_FILE="$EVIDENCE_BUNDLE_DIR/suggestions/partition-targets.suggested.env"
AVB_SUGGESTIONS_FILE="$EVIDENCE_BUNDLE_DIR/suggestions/avb-vbmeta-policy.suggested.env"
SLOT_SUGGESTIONS_FILE="$EVIDENCE_BUNDLE_DIR/suggestions/slot-strategy.suggested.env"
PROVENANCE_SUGGESTIONS_FILE="$EVIDENCE_BUNDLE_DIR/suggestions/boot-input-provenance.suggested.env"

PARTITION_FIELDS="ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET ATLANTIS_SHIBA_PARTITION_TARGET_NOTES"
AVB_FIELDS="ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE ATLANTIS_SHIBA_AVB_VBMETA_TARGET ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT ATLANTIS_SHIBA_AVB_POLICY_NOTES"
SLOT_FIELDS="ATLANTIS_SHIBA_SLOT_EVIDENCE ATLANTIS_SHIBA_SLOT_READ_METHOD ATLANTIS_SHIBA_SLOT_TARGET_POLICY ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY ATLANTIS_SHIBA_SLOT_NOTES"
PROVENANCE_FIELDS="ATLANTIS_SHIBA_KERNEL_PROVENANCE ATLANTIS_SHIBA_INITRAMFS_PROVENANCE ATLANTIS_SHIBA_FIRMWARE_PROVENANCE ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE ATLANTIS_SHIBA_BOOT_INPUT_NOTES"

count_non_unresolved_from_file() {
    env_file=$1
    field_list=$2
    count=0

    for field_name in $field_list; do
        field_value=$(atlantis_value_from_env_file "$env_file" "$field_name")
        if ! atlantis_value_is_unresolved "$field_value"; then
            count=$((count + 1))
        fi
    done

    printf '%s' "$count"
}

write_partition_header() {
    output_file=$1
    cat > "$output_file" <<'EOF'
# Atlantis shiba flashing decisions: partition-target mapping
# Required before any future flashing command sequence can be considered.
# Leave values as UNRESOLVED until the mapping is backed by real device evidence.

EOF
}

write_avb_header() {
    output_file=$1
    cat > "$output_file" <<'EOF'
# Atlantis shiba flashing decisions: AVB and vbmeta policy
# Required before any future flashing command sequence can be considered.
# Leave values as UNRESOLVED until the policy is backed by real device evidence.

EOF
}

write_slot_header() {
    output_file=$1
    cat > "$output_file" <<'EOF'
# Atlantis shiba flashing decisions: slot strategy
# Required before any future flashing command sequence can be considered.
# Leave values as UNRESOLVED until the strategy is backed by real device evidence.

EOF
}

write_provenance_header() {
    output_file=$1
    cat > "$output_file" <<'EOF'
# Atlantis shiba flashing decisions: firmware and boot-input provenance
# Required before any future flashing command sequence can be considered.
# Leave values as UNRESOLVED until provenance is backed by real build evidence.

EOF
}

write_review_status_header() {
    output_file=$1
    cat > "$output_file" <<'EOF'
# Atlantis shiba flashing decision review status
# This file records whether each live decision value is still unreviewed,
# explicitly reviewed, deferred, rejected, or reviewed and applied.
# Keep values shell-friendly and leave them explicit.

EOF
}

default_review_decision() {
    suggested_value=$1

    if atlantis_value_is_unresolved "$suggested_value"; then
        printf '%s' "unresolved"
    else
        printf '%s' "deferred"
    fi
}

render_review_manifest() {
    output_file=$1
    decision_file=$2
    suggestions_file=$3
    field_list=$4
    title=$5

    cat > "$output_file" <<EOF
# Atlantis shiba decision review manifest: $title
# Valid review decisions:
# - accepted: apply REVIEWED_VALUE to the live decision file
# - unresolved: write UNRESOLVED explicitly to the live decision file
# - rejected: reject the suggested value and keep the current live value
# - deferred: keep the current live value and leave the field as still insufficient

EOF

    for field_name in $field_list; do
        current_value=$(atlantis_value_from_env_file "$decision_file" "$field_name")
        suggested_value=$(atlantis_value_from_env_file "$suggestions_file" "$field_name")

        if [ -z "$current_value" ]; then
            current_value="UNRESOLVED"
        fi

        if [ -z "$suggested_value" ]; then
            suggested_value="UNRESOLVED"
        fi

        review_decision=$(default_review_decision "$suggested_value")
        reviewed_value=$suggested_value

        if [ "$review_decision" = "unresolved" ]; then
            reviewed_value="UNRESOLVED"
        fi

        atlantis_write_shell_kv "$output_file" "${field_name}_CURRENT_VALUE" "$current_value"
        atlantis_write_shell_kv "$output_file" "${field_name}_SUGGESTED_VALUE" "$suggested_value"
        atlantis_write_shell_kv "$output_file" "${field_name}_REVIEW_DECISION" "$review_decision"
        atlantis_write_shell_kv "$output_file" "${field_name}_REVIEWED_VALUE" "$reviewed_value"
    done
}

review_decision_is_valid() {
    review_decision=$1

    case "$review_decision" in
        accepted | unresolved | rejected | deferred)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

append_review_status() {
    output_file=$1
    field_name=$2
    review_decision=$3
    review_state=$4
    suggested_by_evidence=$5
    applied_value=$6

    atlantis_write_shell_kv "$output_file" "${field_name}_REVIEW_DECISION" "$review_decision"
    atlantis_write_shell_kv "$output_file" "${field_name}_REVIEW_STATE" "$review_state"
    atlantis_write_shell_kv "$output_file" "${field_name}_SUGGESTED_BY_EVIDENCE" "$suggested_by_evidence"
    atlantis_write_shell_kv "$output_file" "${field_name}_LAST_APPLIED_VALUE" "$applied_value"
}

apply_review_manifest() {
    output_file=$1
    status_file=$2
    review_manifest=$3
    live_decision_file=$4
    suggestions_file=$5
    field_list=$6
    header_writer=$7

    "$header_writer" "$output_file"

    for field_name in $field_list; do
        current_value=$(atlantis_value_from_env_file "$live_decision_file" "$field_name")
        suggested_value=$(atlantis_value_from_env_file "$suggestions_file" "$field_name")
        review_decision=$(atlantis_value_from_env_file "$review_manifest" "${field_name}_REVIEW_DECISION")
        reviewed_value=$(atlantis_value_from_env_file "$review_manifest" "${field_name}_REVIEWED_VALUE")

        if [ -z "$current_value" ]; then
            current_value="UNRESOLVED"
        fi

        if [ -z "$suggested_value" ]; then
            suggested_value="UNRESOLVED"
        fi

        if [ -z "$review_decision" ]; then
            atlantis_die "Missing review decision for $field_name in $review_manifest"
        fi

        review_decision_is_valid "$review_decision" || atlantis_die "Invalid review decision for $field_name: $review_decision"

        suggested_by_evidence="no"
        if ! atlantis_value_is_unresolved "$suggested_value"; then
            suggested_by_evidence="yes"
        fi

        case "$review_decision" in
            accepted)
                if [ -z "$reviewed_value" ] || atlantis_value_is_unresolved "$reviewed_value"; then
                    atlantis_die "Accepted review decision for $field_name requires a concrete REVIEWED_VALUE."
                fi
                applied_value=$reviewed_value
                review_state="reviewed-applied"
                ;;
            unresolved)
                applied_value="UNRESOLVED"
                review_state="reviewed-unresolved"
                ;;
            rejected)
                applied_value=$current_value
                review_state="reviewed-rejected"
                ;;
            deferred)
                applied_value=$current_value
                review_state="reviewed-deferred"
                ;;
        esac

        [ -n "$applied_value" ] || atlantis_die "Applied value for $field_name must not be blank."

        atlantis_write_shell_kv "$output_file" "$field_name" "$applied_value"
        append_review_status "$status_file" "$field_name" "$review_decision" "$review_state" "$suggested_by_evidence" "$applied_value"
    done
}

if [ "$ACTION" = "prepare" ]; then
    rm -rf "$DECISION_REVIEW_DIR"
    mkdir -p \
        "$DECISION_REVIEW_DIR/metadata" \
        "$DECISION_REVIEW_DIR/current" \
        "$DECISION_REVIEW_DIR/suggestions" \
        "$DECISION_REVIEW_DIR/approvals" \
        "$DECISION_REVIEW_DIR/notes" \
        "$DECISION_REVIEW_DIR/applied"

    ln -sfn "$EVIDENCE_BUNDLE_DIR" "$DECISION_REVIEW_DIR/evidence-bundle"
    ln -sfn "$FLASHING_DECISION_DIR" "$DECISION_REVIEW_DIR/live-decisions"

    cp "$PROFILE" "$DECISION_REVIEW_DIR/active-profile.env"
    cp "$PARTITION_DECISIONS_FILE" "$DECISION_REVIEW_DIR/current/"
    cp "$AVB_DECISIONS_FILE" "$DECISION_REVIEW_DIR/current/"
    cp "$SLOT_DECISIONS_FILE" "$DECISION_REVIEW_DIR/current/"
    cp "$PROVENANCE_DECISIONS_FILE" "$DECISION_REVIEW_DIR/current/"
    cp "$PARTITION_SUGGESTIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/"
    cp "$AVB_SUGGESTIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/"
    cp "$SLOT_SUGGESTIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/"
    cp "$PROVENANCE_SUGGESTIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/"
    cp "$DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_DIR/current/"

    render_review_manifest "$DECISION_REVIEW_DIR/approvals/partition-targets.review.env" "$PARTITION_DECISIONS_FILE" "$PARTITION_SUGGESTIONS_FILE" "$PARTITION_FIELDS" "partition targets"
    render_review_manifest "$DECISION_REVIEW_DIR/approvals/avb-vbmeta-policy.review.env" "$AVB_DECISIONS_FILE" "$AVB_SUGGESTIONS_FILE" "$AVB_FIELDS" "AVB and vbmeta policy"
    render_review_manifest "$DECISION_REVIEW_DIR/approvals/slot-strategy.review.env" "$SLOT_DECISIONS_FILE" "$SLOT_SUGGESTIONS_FILE" "$SLOT_FIELDS" "slot strategy"
    render_review_manifest "$DECISION_REVIEW_DIR/approvals/boot-input-provenance.review.env" "$PROVENANCE_DECISIONS_FILE" "$PROVENANCE_SUGGESTIONS_FILE" "$PROVENANCE_FIELDS" "boot-input provenance"

    SUMMARY_ENV="$DECISION_REVIEW_DIR/metadata/decision-review-summary.env"
    : > "$SUMMARY_ENV"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_EVIDENCE_BUNDLE_DIR" "$EVIDENCE_BUNDLE_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_DIR" "$DECISION_REVIEW_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"
    atlantis_write_kv "$SUMMARY_ENV" "PARTITION_FIELDS_WITH_CONCRETE_SUGGESTIONS" "$(count_non_unresolved_from_file "$PARTITION_SUGGESTIONS_FILE" "$PARTITION_FIELDS")"
    atlantis_write_kv "$SUMMARY_ENV" "AVB_FIELDS_WITH_CONCRETE_SUGGESTIONS" "$(count_non_unresolved_from_file "$AVB_SUGGESTIONS_FILE" "$AVB_FIELDS")"
    atlantis_write_kv "$SUMMARY_ENV" "SLOT_FIELDS_WITH_CONCRETE_SUGGESTIONS" "$(count_non_unresolved_from_file "$SLOT_SUGGESTIONS_FILE" "$SLOT_FIELDS")"
    atlantis_write_kv "$SUMMARY_ENV" "PROVENANCE_FIELDS_WITH_CONCRETE_SUGGESTIONS" "$(count_non_unresolved_from_file "$PROVENANCE_SUGGESTIONS_FILE" "$PROVENANCE_FIELDS")"

    cat > "$DECISION_REVIEW_DIR/notes/review-approval-contract.txt" <<EOF
Atlantis shiba decision review/apply contract
============================================

Review boundary:
- structured live decision files: $FLASHING_DECISION_DIR
- read-only evidence suggestions: $EVIDENCE_BUNDLE_DIR/suggestions/
- reviewed approval files: $DECISION_REVIEW_DIR/approvals/
- applied review status file: $DECISION_REVIEW_STATUS_FILE

Valid review decisions:
- accepted
- unresolved
- rejected
- deferred

Meaning:
- accepted: apply REVIEWED_VALUE to the live decision file
- unresolved: write UNRESOLVED explicitly to the live decision file
- rejected: reject the suggestion and keep the current live value
- deferred: keep the current live value and leave the field insufficient for future command drafting

Safety notes:
- prepare does not change live decision files
- apply is a separate explicit step
- reviewed decisions still do not prove Pixel 8 boots
- reviewed decisions alone do not make future flashing safe
EOF

    cat > "$DECISION_REVIEW_DIR/README.txt" <<EOF
Atlantis shiba decision-review directory
=======================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}

This directory exists to review evidence suggestions before any live decision file changes.
It contains:
- copied live decision files
- copied evidence suggestion files
- editable approval manifests

Next step:
- review the files under approvals/
- edit REVIEW_DECISION and REVIEWED_VALUE entries deliberately
- run: sh ./installer/shiba/review-decisions.sh apply

This prepare step does not change live decision files.
It does not invoke fastboot.
It does not invoke adb.
It does not flash anything.
EOF

    echo "Atlantis shiba decision-review output created at $DECISION_REVIEW_DIR"
    echo "This output is a review boundary only. Live decision files were not changed."
else
    APPLIED_DIR="$DECISION_REVIEW_DIR/applied"
    mkdir -p "$APPLIED_DIR"

    TMP_PARTITION_FILE="$APPLIED_DIR/partition-targets.applied.env"
    TMP_AVB_FILE="$APPLIED_DIR/avb-vbmeta-policy.applied.env"
    TMP_SLOT_FILE="$APPLIED_DIR/slot-strategy.applied.env"
    TMP_PROVENANCE_FILE="$APPLIED_DIR/boot-input-provenance.applied.env"
    TMP_REVIEW_STATUS_FILE="$APPLIED_DIR/review-status.applied.env"

    write_review_status_header "$TMP_REVIEW_STATUS_FILE"

    apply_review_manifest "$TMP_PARTITION_FILE" "$TMP_REVIEW_STATUS_FILE" "$DECISION_REVIEW_DIR/approvals/partition-targets.review.env" "$PARTITION_DECISIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/partition-targets.suggested.env" "$PARTITION_FIELDS" write_partition_header
    apply_review_manifest "$TMP_AVB_FILE" "$TMP_REVIEW_STATUS_FILE" "$DECISION_REVIEW_DIR/approvals/avb-vbmeta-policy.review.env" "$AVB_DECISIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/avb-vbmeta-policy.suggested.env" "$AVB_FIELDS" write_avb_header
    apply_review_manifest "$TMP_SLOT_FILE" "$TMP_REVIEW_STATUS_FILE" "$DECISION_REVIEW_DIR/approvals/slot-strategy.review.env" "$SLOT_DECISIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/slot-strategy.suggested.env" "$SLOT_FIELDS" write_slot_header
    apply_review_manifest "$TMP_PROVENANCE_FILE" "$TMP_REVIEW_STATUS_FILE" "$DECISION_REVIEW_DIR/approvals/boot-input-provenance.review.env" "$PROVENANCE_DECISIONS_FILE" "$DECISION_REVIEW_DIR/suggestions/boot-input-provenance.suggested.env" "$PROVENANCE_FIELDS" write_provenance_header

    cp "$TMP_PARTITION_FILE" "$PARTITION_DECISIONS_FILE"
    cp "$TMP_AVB_FILE" "$AVB_DECISIONS_FILE"
    cp "$TMP_SLOT_FILE" "$SLOT_DECISIONS_FILE"
    cp "$TMP_PROVENANCE_FILE" "$PROVENANCE_DECISIONS_FILE"
    cp "$TMP_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"

    APPLY_SUMMARY_ENV="$DECISION_REVIEW_DIR/metadata/decision-apply-summary.env"
    : > "$APPLY_SUMMARY_ENV"
    atlantis_write_kv "$APPLY_SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
    atlantis_write_kv "$APPLY_SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
    atlantis_write_kv "$APPLY_SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
    atlantis_write_kv "$APPLY_SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_write_kv "$APPLY_SUMMARY_ENV" "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"

    cat > "$DECISION_REVIEW_DIR/notes/apply-result.txt" <<EOF
Atlantis shiba decision apply result
===================================

Applied outputs:
- $PARTITION_DECISIONS_FILE
- $AVB_DECISIONS_FILE
- $SLOT_DECISIONS_FILE
- $PROVENANCE_DECISIONS_FILE
- $DECISION_REVIEW_STATUS_FILE

What this means:
- accepted fields are now reviewed and applied in the live decision files
- unresolved fields stay explicitly unresolved
- rejected or deferred fields remain visible in the approval manifests and review status file

Next step:
- run: sh ./installer/shiba/generate-command-plan.sh
- review any remaining blockers reported by the guarded command-plan stage
EOF

    echo "Atlantis shiba reviewed decisions were applied to live decision files."
    echo "Command-plan generation can now consume reviewed states more explicitly."
fi
