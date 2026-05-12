#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$REPO_ROOT/build/mmdebstrap/common.sh"

DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
ATLANTIS_PROFILE=${ATLANTIS_PROFILE:-$DEFAULT_PROFILE}
export ATLANTIS_PROFILE

MODE="dry-run"
ACK_VALUE=""
EXPECTED_ACK="I_UNDERSTAND_ATLANTIS_SHIBA_FLASHING_CAN_OVERWRITE_DEVICE_PARTITIONS"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --execute)
            MODE="execute"
            ;;
        --acknowledge)
            shift
            [ "$#" -gt 0 ] || atlantis_die "--acknowledge requires a value."
            ACK_VALUE=$1
            ;;
        --acknowledge=*)
            ACK_VALUE=${1#*=}
            ;;
        *)
            atlantis_die "Unknown argument: $1"
            ;;
    esac
    shift
done

sh "$REPO_ROOT/build/mmdebstrap/preflight.sh" shiba-execution
atlantis_load_profile "$DEFAULT_PROFILE"

INSTALLER_PREP_DIR=$(atlantis_path_from_repo "${ATLANTIS_INSTALLER_PREP_DIR:-}")
FLASHING_DECISION_DIR=$(atlantis_path_from_repo "${ATLANTIS_FLASHING_DECISION_DIR:-}")
COMMAND_PLAN_DIR=$(atlantis_path_from_repo "${ATLANTIS_COMMAND_PLAN_DIR:-}")
DECISION_REVIEW_STATUS_FILE=$(atlantis_path_from_repo "${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}")
READINESS_DIR=$(atlantis_path_from_repo "${ATLANTIS_READINESS_DIR:-}")
SESSION_BUNDLE_DIR=$(atlantis_path_from_repo "${ATLANTIS_SESSION_BUNDLE_DIR:-}")
EXECUTION_DIR=$(atlantis_path_from_repo "${ATLANTIS_EXECUTION_DIR:-}")

PARTITION_DECISIONS_FILE="$FLASHING_DECISION_DIR/partition-targets.env"
AVB_DECISIONS_FILE="$FLASHING_DECISION_DIR/avb-vbmeta-policy.env"
SLOT_DECISIONS_FILE="$FLASHING_DECISION_DIR/slot-strategy.env"
PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_DIR/boot-input-provenance.env"
READINESS_SUMMARY_FILE="$READINESS_DIR/metadata/readiness-summary.env"
SESSION_BUNDLE_SUMMARY_FILE="$SESSION_BUNDLE_DIR/metadata/session-bundle-summary.env"
COMMAND_PLAN_SUMMARY_FILE="$COMMAND_PLAN_DIR/metadata/command-plan-summary.env"

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
. "$READINESS_SUMMARY_FILE"
# shellcheck disable=SC1090
. "$SESSION_BUNDLE_SUMMARY_FILE"
# shellcheck disable=SC1090
. "$COMMAND_PLAN_SUMMARY_FILE"

BOOT_ARTIFACT_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/boot-artifact-stage.path")
COMPOSE_STAGE_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/compose-stage.path")
ROOTFS_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/generic-rootfs.path")
PACKAGE_FEED_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/package-feed.path")
KERNEL_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/kernel-artifact.path")
INITRAMFS_REF=$(atlantis_read_first_line "$INSTALLER_PREP_DIR/metadata/initramfs-artifact.path")

rm -rf "$EXECUTION_DIR"
mkdir -p \
    "$EXECUTION_DIR/metadata" \
    "$EXECUTION_DIR/rendered" \
    "$EXECUTION_DIR/logs" \
    "$EXECUTION_DIR/blockers" \
    "$EXECUTION_DIR/notes" \
    "$EXECUTION_DIR/bundle/decisions"

ln -sfn "$INSTALLER_PREP_DIR" "$EXECUTION_DIR/installer-preparation"
ln -sfn "$COMMAND_PLAN_DIR" "$EXECUTION_DIR/command-plan"
ln -sfn "$READINESS_DIR" "$EXECUTION_DIR/readiness"
ln -sfn "$SESSION_BUNDLE_DIR" "$EXECUTION_DIR/session-bundle"
ln -sfn "$FLASHING_DECISION_DIR" "$EXECUTION_DIR/flashing-decisions"
if [ -n "$BOOT_ARTIFACT_REF" ] && [ -e "$BOOT_ARTIFACT_REF" ]; then
    ln -sfn "$BOOT_ARTIFACT_REF" "$EXECUTION_DIR/boot-artifact-stage"
fi

cp "$PROFILE" "$EXECUTION_DIR/active-profile.env"
cp "$PARTITION_DECISIONS_FILE" "$EXECUTION_DIR/bundle/decisions/"
cp "$AVB_DECISIONS_FILE" "$EXECUTION_DIR/bundle/decisions/"
cp "$SLOT_DECISIONS_FILE" "$EXECUTION_DIR/bundle/decisions/"
cp "$PROVENANCE_DECISIONS_FILE" "$EXECUTION_DIR/bundle/decisions/"
cp "$DECISION_REVIEW_STATUS_FILE" "$EXECUTION_DIR/bundle/decisions/"
cp "$READINESS_SUMMARY_FILE" "$EXECUTION_DIR/metadata/"
cp "$SESSION_BUNDLE_SUMMARY_FILE" "$EXECUTION_DIR/metadata/"
cp "$COMMAND_PLAN_SUMMARY_FILE" "$EXECUTION_DIR/metadata/"

STEP_SEQUENCE_TSV="$EXECUTION_DIR/rendered/step-sequence.tsv"
STEP_SEQUENCE_TXT="$EXECUTION_DIR/rendered/flashing-step-sequence.txt"
RENDERED_COMMANDS_FILE="$EXECUTION_DIR/rendered/rendered-commands.sh"
ATTEMPTED_COMMANDS_FILE="$EXECUTION_DIR/logs/attempted-commands.sh"
SESSION_LEDGER_FILE="$EXECUTION_DIR/logs/session-ledger.tsv"
STEP_LOG_FILE="$EXECUTION_DIR/logs/step-log.txt"
BLOCKERS_FILE="$EXECUTION_DIR/blockers/execution-blockers.txt"
SUMMARY_ENV="$EXECUTION_DIR/metadata/execution-summary.env"

printf 'step_id\tcategory\tattempt_mode\tdestructive\tdescription\tcommand\n' > "$STEP_SEQUENCE_TSV"
cat > "$RENDERED_COMMANDS_FILE" <<'EOF'
#!/bin/sh
# Rendered Atlantis shiba session commands.
# Review only; this file does not mean commands were executed.
EOF
cat > "$ATTEMPTED_COMMANDS_FILE" <<'EOF'
#!/bin/sh
# Attempted Atlantis shiba session commands.
# This file records only commands the harness actually tried to run.
EOF
printf 'timestamp\tstep_id\tcategory\tattempt_mode\tstate\texit_status\tcommand\n' > "$SESSION_LEDGER_FILE"
: > "$STEP_LOG_FILE"
: > "$BLOCKERS_FILE"
: > "$SUMMARY_ENV"

ALL_FIELDS="ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET ATLANTIS_SHIBA_PARTITION_TARGET_NOTES ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE ATLANTIS_SHIBA_AVB_VBMETA_TARGET ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT ATLANTIS_SHIBA_AVB_POLICY_NOTES ATLANTIS_SHIBA_SLOT_EVIDENCE ATLANTIS_SHIBA_SLOT_READ_METHOD ATLANTIS_SHIBA_SLOT_TARGET_POLICY ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY ATLANTIS_SHIBA_SLOT_NOTES ATLANTIS_SHIBA_KERNEL_PROVENANCE ATLANTIS_SHIBA_INITRAMFS_PROVENANCE ATLANTIS_SHIBA_FIRMWARE_PROVENANCE ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE ATLANTIS_SHIBA_BOOT_INPUT_NOTES"

blocker_count=0
renderable="yes"
execution_eligible="yes"
execution_attempted="no"
destructive_execution_allowed="no"
commands_rendered_count=0
commands_attempted_count=0
last_completed_step="none"
first_failed_or_blocked_step="none"
final_session_result="in progress"
current_step_id="none"
stop_execution="no"

field_current_value() {
    field_name=$1
    eval "printf '%s' \"\${$field_name-}\""
}

field_status_value() {
    field_name=$1
    suffix=$2
    eval "printf '%s' \"\${${field_name}_${suffix}-}\""
}

append_log_line() {
    printf '[%s] %s\n' "$(atlantis_timestamp_utc)" "$1" >> "$STEP_LOG_FILE"
}

record_ledger() {
    timestamp=$1
    step_id=$2
    category=$3
    attempt_mode=$4
    state=$5
    exit_status=$6
    command_text=$7

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$timestamp" "$step_id" "$category" "$attempt_mode" "$state" "$exit_status" "$command_text" >> "$SESSION_LEDGER_FILE"
}

record_blocker() {
    blocker_message=$1
    blocker_count=$((blocker_count + 1))
    renderable="no"
    if [ "$first_failed_or_blocked_step" = "none" ]; then
        first_failed_or_blocked_step="blocked-before-execution"
    fi
    printf '%s\n' "- $blocker_message" >> "$BLOCKERS_FILE"
    append_log_line "blocker: $blocker_message"
}

require_reference_path() {
    label=$1
    path_value=$2

    if [ -n "$path_value" ] && [ -e "$path_value" ]; then
        return 0
    fi

    record_blocker "$label is missing: $path_value"
    return 1
}

validate_reviewed_field() {
    field_name=$1
    current_value=$(field_current_value "$field_name")
    review_state=$(field_status_value "$field_name" "REVIEW_STATE")

    if [ -z "$current_value" ] || atlantis_value_is_unresolved "$current_value"; then
        record_blocker "$field_name is unresolved in live decision files."
        return 1
    fi

    if [ "$review_state" != "reviewed-applied" ]; then
        record_blocker "$field_name is not reviewed-applied (state: ${review_state:-unset})."
        return 1
    fi

    return 0
}

render_step() {
    step_id=$1
    category=$2
    attempt_mode=$3
    destructive=$4
    description=$5
    command_text=$6

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$step_id" "$category" "$attempt_mode" "$destructive" "$description" "$command_text" >> "$STEP_SEQUENCE_TSV"
    printf '%s. [%s] [%s] %s\n' "$step_id" "$category" "$attempt_mode" "$description" >> "$STEP_SEQUENCE_TXT"
    if [ -n "$command_text" ] && [ "$command_text" != "-" ]; then
        printf '%s\n' "$command_text" >> "$RENDERED_COMMANDS_FILE"
        commands_rendered_count=$((commands_rendered_count + 1))
    else
        printf '# %s\n' "$description" >> "$RENDERED_COMMANDS_FILE"
    fi
}

quote_arg() {
    printf "'%s'" "$(atlantis_escape_squote "$1")"
}

run_step() {
    step_id=$1
    category=$2
    attempt_mode=$3
    destructive=$4
    description=$5
    command_text=$6

    render_step "$step_id" "$category" "$attempt_mode" "$destructive" "$description" "$command_text"
    current_step_id=$step_id

    if [ "$MODE" != "execute" ]; then
        record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "rendered-only" "-" "$command_text"
        return 0
    fi

    if [ "$attempt_mode" = "render-only" ]; then
        record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "rendered-only" "-" "$command_text"
        return 0
    fi

    execution_attempted="yes"
    if [ "$destructive" = "yes" ]; then
        destructive_execution_allowed="yes"
    fi

    printf '# %s %s\n' "$(atlantis_timestamp_utc)" "$description" >> "$ATTEMPTED_COMMANDS_FILE"
    printf '%s\n' "$command_text" >> "$ATTEMPTED_COMMANDS_FILE"

    record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "attempted" "-" "$command_text"
    append_log_line "attempting step $step_id: $description"

    if [ -z "$command_text" ] || [ "$command_text" = "-" ]; then
        last_completed_step=$step_id
        record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "completed" "0" "$command_text"
        return 0
    fi

    set +e
    sh -c "$command_text"
    exit_status=$?
    set -e

    commands_attempted_count=$((commands_attempted_count + 1))

    if [ "$exit_status" -eq 0 ]; then
        last_completed_step=$step_id
        record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "completed" "$exit_status" "$command_text"
        append_log_line "completed step $step_id"
        return 0
    fi

    if [ "$first_failed_or_blocked_step" = "none" ]; then
        first_failed_or_blocked_step=$step_id
    fi
    final_session_result="broken"
    record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "failed" "$exit_status" "$command_text"
    append_log_line "failed step $step_id with exit status $exit_status"
    return "$exit_status"
}

plan_step() {
    step_id=$1
    category=$2
    attempt_mode=$3
    destructive=$4
    description=$5
    command_text=$6

    if [ "$MODE" = "execute" ] && [ "$stop_execution" = "yes" ]; then
        render_step "$step_id" "$category" "$attempt_mode" "$destructive" "$description" "$command_text"
        record_ledger "$(atlantis_timestamp_utc)" "$step_id" "$category" "$attempt_mode" "not-attempted-after-stop" "-" "$command_text"
        return 0
    fi

    if run_step "$step_id" "$category" "$attempt_mode" "$destructive" "$description" "$command_text"; then
        step_status=0
    else
        step_status=$?
    fi

    if [ "$MODE" = "execute" ] && [ "$step_status" -ne 0 ]; then
        stop_execution="yes"
    fi

    return 0
}

write_summary() {
    : > "$SUMMARY_ENV"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_NAME" "$PROFILE_NAME"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_PROFILE_PATH" "$PROFILE"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_DEVICE_ID" "${ATLANTIS_DEVICE_ID:-unset}"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_READINESS_DIR" "$READINESS_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_SESSION_BUNDLE_DIR" "$SESSION_BUNDLE_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "ATLANTIS_EXECUTION_DIR" "$EXECUTION_DIR"
    atlantis_write_kv "$SUMMARY_ENV" "EXECUTION_MODE" "$MODE"
    atlantis_write_kv "$SUMMARY_ENV" "READINESS_CLASSIFICATION" "${READINESS_CLASSIFICATION:-blocked}"
    atlantis_write_kv "$SUMMARY_ENV" "SESSION_BUNDLE_CLASSIFICATION" "${SESSION_BUNDLE_CLASSIFICATION:-blocked}"
    atlantis_write_kv "$SUMMARY_ENV" "COMMAND_PLAN_RESULT" "${COMMAND_PLAN_RESULT:-blocked}"
    atlantis_write_kv "$SUMMARY_ENV" "RENDERABLE" "$renderable"
    atlantis_write_kv "$SUMMARY_ENV" "EXECUTION_ELIGIBLE" "$execution_eligible"
    atlantis_write_kv "$SUMMARY_ENV" "EXECUTION_ATTEMPTED" "$execution_attempted"
    atlantis_write_kv "$SUMMARY_ENV" "DESTRUCTIVE_EXECUTION_ALLOWED" "$destructive_execution_allowed"
    atlantis_write_kv "$SUMMARY_ENV" "EXECUTION_BLOCKER_COUNT" "$blocker_count"
    atlantis_write_kv "$SUMMARY_ENV" "COMMANDS_RENDERED_COUNT" "$commands_rendered_count"
    atlantis_write_kv "$SUMMARY_ENV" "COMMANDS_ATTEMPTED_COUNT" "$commands_attempted_count"
    atlantis_write_kv "$SUMMARY_ENV" "LAST_COMPLETED_STEP" "$last_completed_step"
    atlantis_write_kv "$SUMMARY_ENV" "FIRST_FAILED_OR_BLOCKED_STEP" "$first_failed_or_blocked_step"
    atlantis_write_kv "$SUMMARY_ENV" "FINAL_SESSION_RESULT" "$final_session_result"
    atlantis_write_kv "$SUMMARY_ENV" "FASTBOOT_AVAILABLE" "$FASTBOOT_AVAILABLE"
    atlantis_write_kv "$SUMMARY_ENV" "ADB_AVAILABLE" "$ADB_AVAILABLE"
}

handle_interrupt() {
    signal_name=$1
    if [ "$first_failed_or_blocked_step" = "none" ]; then
        first_failed_or_blocked_step=$current_step_id
    fi
    final_session_result="broken"
    append_log_line "interrupted by $signal_name"
    record_ledger "$(atlantis_timestamp_utc)" "$current_step_id" "session" "$MODE" "interrupted" "130" "$signal_name"
    write_summary
    exit 130
}

trap 'handle_interrupt INT' INT
trap 'handle_interrupt TERM' TERM

FASTBOOT_AVAILABLE="no"
ADB_AVAILABLE="no"
FASTBOOT_COMMAND="fastboot"

if atlantis_command_available fastboot; then
    FASTBOOT_AVAILABLE="yes"
fi
if atlantis_command_available adb; then
    ADB_AVAILABLE="yes"
fi

HOST_TOOLS_ENV="$EXECUTION_DIR/metadata/host-tools.env"
: > "$HOST_TOOLS_ENV"
atlantis_write_kv "$HOST_TOOLS_ENV" "FASTBOOT_AVAILABLE" "$FASTBOOT_AVAILABLE"
atlantis_write_kv "$HOST_TOOLS_ENV" "ADB_AVAILABLE" "$ADB_AVAILABLE"

if [ "${READINESS_CLASSIFICATION:-blocked}" != "session-ready" ]; then
    record_blocker "Readiness classification is ${READINESS_CLASSIFICATION:-blocked}, not session-ready."
fi

if [ "${SESSION_BUNDLE_CLASSIFICATION:-blocked}" != "session-ready" ]; then
    record_blocker "Session bundle classification is ${SESSION_BUNDLE_CLASSIFICATION:-blocked}, not session-ready."
fi

if [ "${COMMAND_PLAN_RESULT:-blocked}" != "reviewable" ]; then
    record_blocker "Command-plan result is ${COMMAND_PLAN_RESULT:-blocked}, not reviewable."
fi

require_reference_path "boot-artifact stage reference" "$BOOT_ARTIFACT_REF"
require_reference_path "compose stage reference" "$COMPOSE_STAGE_REF"
require_reference_path "generic rootfs reference" "$ROOTFS_REF"
require_reference_path "package feed reference" "$PACKAGE_FEED_REF"
require_reference_path "kernel artifact reference" "$KERNEL_REF"
require_reference_path "initramfs artifact reference" "$INITRAMFS_REF"

for field_name in $ALL_FIELDS; do
    validate_reviewed_field "$field_name"
done

case ${ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT:-UNRESOLVED} in
    not-required|NOT-REQUIRED|none|NONE|no|NO|skip|SKIP)
        AVB_WRITE_STEP_MODE="render-only"
        AVB_WRITE_STEP_COMMAND="-"
        AVB_WRITE_STEP_DESCRIPTION="Reviewed AVB policy omits a vbmeta write step (${ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT})."
        ;;
    *)
        record_blocker "Reviewed AVB write requirement (${ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT:-UNRESOLVED}) still needs a repo-owned vbmeta artifact and write contract."
        AVB_WRITE_STEP_MODE="render-only"
        AVB_WRITE_STEP_COMMAND="-"
        AVB_WRITE_STEP_DESCRIPTION="AVB write step remains blocked until a repo-owned vbmeta artifact contract exists."
        ;;
esac

if [ "$FASTBOOT_AVAILABLE" != "yes" ]; then
    execution_eligible="no"
    if [ "$MODE" = "execute" ]; then
        record_blocker "fastboot is required for execution mode."
    fi
fi

if [ "$MODE" = "execute" ]; then
    if [ "$ACK_VALUE" != "$EXPECTED_ACK" ]; then
        execution_eligible="no"
        record_blocker "Execution mode requires --acknowledge $EXPECTED_ACK"
    fi
fi

cat > "$STEP_SEQUENCE_TXT" <<EOF
Atlantis shiba flashing execution harness
=========================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Mode: $MODE
Readiness classification: ${READINESS_CLASSIFICATION:-blocked}
Session bundle classification: ${SESSION_BUNDLE_CLASSIFICATION:-blocked}
Command-plan result: ${COMMAND_PLAN_RESULT:-blocked}

EOF

if [ "$renderable" != "yes" ]; then
    cat >> "$STEP_SEQUENCE_TXT" <<EOF
Render result: blocked

This harness stays blocked because one or more reviewed inputs are still insufficient for a truthful flashing session.

Blockers:
EOF
    cat "$BLOCKERS_FILE" >> "$STEP_SEQUENCE_TXT"
    cat >> "$STEP_SEQUENCE_TXT" <<EOF

Explicit non-claims:
- dry-run is not execution
- execution remains blocked here
- this harness does not prove Pixel 8 boots
EOF
    final_session_result="blocked"
    execution_eligible="no"
else
    cat >> "$STEP_SEQUENCE_TXT" <<EOF
Render result: reviewable

Ordered step sequence:
EOF

    DEVICE_CHECK_COMMAND="$FASTBOOT_COMMAND devices"
    SLOT_CHECK_COMMAND="$FASTBOOT_COMMAND getvar current-slot"
    FLASH_KERNEL_COMMAND="$FASTBOOT_COMMAND flash $(quote_arg "${ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET}") $(quote_arg "$KERNEL_REF")"
    FLASH_INITRAMFS_COMMAND="$FASTBOOT_COMMAND flash $(quote_arg "${ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET}") $(quote_arg "$INITRAMFS_REF")"

    plan_step "01" "execution-precheck" "execution-only" "no" "Check that a fastboot-visible device is present." "$DEVICE_CHECK_COMMAND"
    plan_step "02" "execution-precheck" "execution-only" "no" "Capture the current slot for the execution ledger." "$SLOT_CHECK_COMMAND"
    plan_step "03" "execution-destructive" "execution-only" "yes" "Flash the reviewed boot-input target with the reviewed kernel artifact." "$FLASH_KERNEL_COMMAND"
    plan_step "04" "execution-destructive" "execution-only" "yes" "Flash the reviewed initramfs-input target with the reviewed initramfs artifact." "$FLASH_INITRAMFS_COMMAND"
    plan_step "05" "review-checkpoint" "$AVB_WRITE_STEP_MODE" "no" "$AVB_WRITE_STEP_DESCRIPTION" "$AVB_WRITE_STEP_COMMAND"
    plan_step "06" "review-checkpoint" "render-only" "no" "Reviewed rootfs handoff target: ${ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET}. No destructive command is emitted from this field by the current harness." "-"
    plan_step "07" "review-checkpoint" "render-only" "no" "Reviewed slot strategy: target policy ${ATLANTIS_SHIBA_SLOT_TARGET_POLICY}; fallback policy ${ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY}." "-"
    plan_step "08" "review-checkpoint" "render-only" "no" "Reviewed provenance notes: kernel ${ATLANTIS_SHIBA_KERNEL_PROVENANCE}; initramfs ${ATLANTIS_SHIBA_INITRAMFS_PROVENANCE}; firmware ${ATLANTIS_SHIBA_FIRMWARE_PROVENANCE}." "-"

    if [ "$MODE" = "dry-run" ]; then
        final_session_result="in progress"
    elif [ "$final_session_result" != "broken" ]; then
        final_session_result="unverified"
    fi
fi

cat > "$EXECUTION_DIR/notes/execution-contract.txt" <<EOF
Atlantis shiba execution-harness contract
=========================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Mode: $MODE

Consumed inputs:
- command-plan / execution-bundle directory: $COMMAND_PLAN_DIR
- readiness-check directory: $READINESS_DIR
- operator-session bundle directory: $SESSION_BUNDLE_DIR
- live decision files: $FLASHING_DECISION_DIR
- live review-status file: $DECISION_REVIEW_STATUS_FILE
- installer-preparation directory: $INSTALLER_PREP_DIR

Produced output:
- execution harness directory: $EXECUTION_DIR

Boundary notes:
- dry-run is not execution
- execution mode needs session-ready inputs plus an explicit acknowledgement
- the execution ledger records rendered steps, attempted commands, and stop points
- this harness does not claim rollback is implemented
- this harness does not prove Pixel 8 boots
EOF

cat > "$EXECUTION_DIR/notes/non-claims.txt" <<EOF
Atlantis shiba execution-harness non-claims
===========================================

- A dry-run output is not a flashing result.
- A rendered command sequence is not proof that flashing is safe.
- A completed flashing session would still not prove Pixel 8 boots.
- Rollback remains manual or unresolved unless explicitly documented elsewhere.
EOF

cat > "$EXECUTION_DIR/notes/rollback-status.txt" <<EOF
Atlantis shiba rollback and abort status
=======================================

- rollback implementation: unresolved
- rollback handling in this harness: manual only
- abort handling in this harness: the session ledger records the last completed step and the first failed or blocked step
- session stop state:
  - last completed step: $last_completed_step
  - first failed or blocked step: $first_failed_or_blocked_step
EOF

if [ "$MODE" = "execute" ] && [ "$renderable" = "yes" ] && [ "$execution_eligible" = "yes" ]; then
    if [ "$final_session_result" != "broken" ]; then
        final_session_result="in progress"
    fi
fi

if [ "$MODE" = "execute" ] && { [ "$renderable" != "yes" ] || [ "$execution_eligible" != "yes" ]; }; then
    final_session_result="blocked"
fi

cat > "$EXECUTION_DIR/README.txt" <<EOF
Atlantis shiba flashing execution harness output
================================================

Profile: $PROFILE_NAME
Profile file: $PROFILE
Device id: ${ATLANTIS_DEVICE_ID:-unset}
Mode: $MODE
Renderable: $renderable
Execution eligible: $execution_eligible
Final session result: $final_session_result

This directory records the first guarded Atlantis shiba flashing session harness.
It consumes the reviewed command-plan inputs, the readiness result, the operator-session bundle, and the live decision files.
It always writes a ledger.
It defaults to dry-run.
It only attempts destructive commands in explicit execution mode after acknowledgement.
It does not prove Pixel 8 boots.
EOF

write_summary

echo "Atlantis shiba execution-harness output created at $EXECUTION_DIR"
echo "Mode: $MODE"
echo "Renderable: $renderable"
echo "Execution eligible: $execution_eligible"

if [ "$MODE" = "execute" ] && { [ "$renderable" != "yes" ] || [ "$execution_eligible" != "yes" ]; }; then
    atlantis_die "Execution mode is blocked. Review $EXECUTION_DIR/blockers/execution-blockers.txt"
fi

if [ "$MODE" = "execute" ] && [ "$final_session_result" = "broken" ]; then
    atlantis_die "Execution mode stopped after a failed step. Review $EXECUTION_DIR/logs/session-ledger.tsv"
fi
