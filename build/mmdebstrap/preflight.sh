#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

. "$SCRIPT_DIR/common.sh"

MODE=${1:-rootfs}

case "$MODE" in
    package-build)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
        ;;
    rootfs)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
        ;;
    package-feed)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/development-bookworm-arm64.env"
        ;;
    shiba-compose)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-boot-artifacts)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-installer-prep)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-command-plan)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-evidence)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-decision-review)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-decision-apply)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-readiness)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-session-bundle)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    shiba-execution)
        DEFAULT_PROFILE="$REPO_ROOT/manifest/profiles/shiba-development-bookworm-arm64.env"
        ;;
    *)
        atlantis_die "Unknown preflight mode: $MODE"
        ;;
esac

atlantis_load_profile "$DEFAULT_PROFILE"

validate_rootfs() {
    PACKAGE_LISTS=${PACKAGE_LISTS:-${ATLANTIS_PACKAGE_LISTS:-}}

    atlantis_require_command mmdebstrap
    atlantis_require_value "ATLANTIS_PACKAGE_LISTS" "$PACKAGE_LISTS"

    for package_list in $PACKAGE_LISTS; do
        atlantis_require_file "$(atlantis_path_from_repo "$package_list")"
    done
}

validate_package_build() {
    PACKAGE_ARTIFACT_DIR=${ATLANTIS_PACKAGE_ARTIFACT_DIR:-}

    atlantis_require_command dpkg-buildpackage
    atlantis_require_command dpkg-parsechangelog
    atlantis_require_command dpkg-architecture
    atlantis_require_command dh

    atlantis_require_value "ATLANTIS_PACKAGE_ARTIFACT_DIR" "$PACKAGE_ARTIFACT_DIR"

    for package_dir in \
        packages/atlantis-base \
        packages/atlantis-shell \
        packages/atlantis-branding
    do
        atlantis_require_dir "$(atlantis_path_from_repo "$package_dir")"
        atlantis_require_file "$(atlantis_path_from_repo "$package_dir")/debian/control"
        atlantis_require_file "$(atlantis_path_from_repo "$package_dir")/debian/changelog"
        atlantis_require_file "$(atlantis_path_from_repo "$package_dir")/debian/rules"
    done

    mkdir -p "$(atlantis_path_from_repo "$PACKAGE_ARTIFACT_DIR")"
}

validate_package_feed() {
    PACKAGE_ARTIFACT_DIR=${ATLANTIS_PACKAGE_ARTIFACT_DIR:-}

    atlantis_require_command dpkg-scanpackages
    atlantis_require_value "ATLANTIS_PACKAGE_ARTIFACT_DIR" "$PACKAGE_ARTIFACT_DIR"
    mkdir -p "$(atlantis_path_from_repo "$PACKAGE_ARTIFACT_DIR")"
}

validate_shiba_compose() {
    ROOTFS_DIR=${ATLANTIS_ROOTFS_DIR:-}
    REPO_DIR=${ATLANTIS_REPO_DIR:-}
    DEVICE_STAGE_DIR=${ATLANTIS_DEVICE_STAGE_DIR:-}
    DEVICE_PACKAGE_SOURCE_DIR=${ATLANTIS_DEVICE_PACKAGE_SOURCE_DIR:-}
    KERNEL_ARTIFACT=${ATLANTIS_KERNEL_ARTIFACT:-}
    INITRAMFS_ARTIFACT=${ATLANTIS_INITRAMFS_ARTIFACT:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba compose requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba compose requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_ROOTFS_DIR" "$ROOTFS_DIR"
    atlantis_require_value "ATLANTIS_REPO_DIR" "$REPO_DIR"
    atlantis_require_value "ATLANTIS_DEVICE_STAGE_DIR" "$DEVICE_STAGE_DIR"

    atlantis_require_dir "$(atlantis_path_from_repo "$ROOTFS_DIR")"
    atlantis_require_dir "$(atlantis_path_from_repo "$REPO_DIR")"
    atlantis_require_file "$(atlantis_path_from_repo "$REPO_DIR")/Packages"

    if [ -n "$DEVICE_PACKAGE_SOURCE_DIR" ]; then
        atlantis_require_dir "$(atlantis_path_from_repo "$DEVICE_PACKAGE_SOURCE_DIR")"
    fi

    if [ -n "$KERNEL_ARTIFACT" ]; then
        atlantis_require_path "$(atlantis_path_from_repo "$KERNEL_ARTIFACT")"
    fi

    if [ -n "$INITRAMFS_ARTIFACT" ]; then
        atlantis_require_path "$(atlantis_path_from_repo "$INITRAMFS_ARTIFACT")"
    fi
}

validate_shiba_boot_artifacts() {
    DEVICE_STAGE_DIR=${ATLANTIS_DEVICE_STAGE_DIR:-}
    BOOT_ARTIFACT_DIR=${ATLANTIS_BOOT_ARTIFACT_DIR:-}
    KERNEL_ARTIFACT=${ATLANTIS_KERNEL_ARTIFACT:-}
    INITRAMFS_ARTIFACT=${ATLANTIS_INITRAMFS_ARTIFACT:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba boot-artifact staging requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba boot-artifact staging requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_DEVICE_STAGE_DIR" "$DEVICE_STAGE_DIR"
    atlantis_require_value "ATLANTIS_BOOT_ARTIFACT_DIR" "$BOOT_ARTIFACT_DIR"
    atlantis_require_value "ATLANTIS_KERNEL_ARTIFACT" "$KERNEL_ARTIFACT"
    atlantis_require_value "ATLANTIS_INITRAMFS_ARTIFACT" "$INITRAMFS_ARTIFACT"

    atlantis_require_dir "$(atlantis_path_from_repo "$DEVICE_STAGE_DIR")"
    atlantis_require_file "$(atlantis_path_from_repo "$DEVICE_STAGE_DIR")/active-profile.env"
    atlantis_require_path "$(atlantis_path_from_repo "$KERNEL_ARTIFACT")"
    atlantis_require_path "$(atlantis_path_from_repo "$INITRAMFS_ARTIFACT")"
}

validate_shiba_installer_prep() {
    BOOT_ARTIFACT_DIR=${ATLANTIS_BOOT_ARTIFACT_DIR:-}
    INSTALLER_PREP_DIR=${ATLANTIS_INSTALLER_PREP_DIR:-}
    KERNEL_ARTIFACT=${ATLANTIS_KERNEL_ARTIFACT:-}
    INITRAMFS_ARTIFACT=${ATLANTIS_INITRAMFS_ARTIFACT:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba installer preparation requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba installer preparation requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_command fastboot
    atlantis_require_command adb

    atlantis_require_value "ATLANTIS_BOOT_ARTIFACT_DIR" "$BOOT_ARTIFACT_DIR"
    atlantis_require_value "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
    atlantis_require_value "ATLANTIS_KERNEL_ARTIFACT" "$KERNEL_ARTIFACT"
    atlantis_require_value "ATLANTIS_INITRAMFS_ARTIFACT" "$INITRAMFS_ARTIFACT"

    atlantis_require_dir "$(atlantis_path_from_repo "$BOOT_ARTIFACT_DIR")"
    atlantis_require_file "$(atlantis_path_from_repo "$BOOT_ARTIFACT_DIR")/active-profile.env"
    atlantis_require_file "$(atlantis_path_from_repo "$BOOT_ARTIFACT_DIR")/metadata/kernel-artifact.path"
    atlantis_require_file "$(atlantis_path_from_repo "$BOOT_ARTIFACT_DIR")/metadata/initramfs-artifact.path"
    atlantis_require_file "$(atlantis_path_from_repo "$BOOT_ARTIFACT_DIR")/manifests/boot-artifact-contract.txt"
    atlantis_require_path "$(atlantis_path_from_repo "$KERNEL_ARTIFACT")"
    atlantis_require_path "$(atlantis_path_from_repo "$INITRAMFS_ARTIFACT")"
}

validate_shiba_command_plan() {
    INSTALLER_PREP_DIR=${ATLANTIS_INSTALLER_PREP_DIR:-}
    FLASHING_DECISION_DIR=${ATLANTIS_FLASHING_DECISION_DIR:-}
    COMMAND_PLAN_DIR=${ATLANTIS_COMMAND_PLAN_DIR:-}
    DECISION_REVIEW_STATUS_FILE=${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba command-plan generation requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba command-plan generation requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
    atlantis_require_value "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_require_value "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
    atlantis_require_value "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"

    INSTALLER_PREP_PATH=$(atlantis_path_from_repo "$INSTALLER_PREP_DIR")
    FLASHING_DECISION_PATH=$(atlantis_path_from_repo "$FLASHING_DECISION_DIR")
    DECISION_REVIEW_STATUS_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_STATUS_FILE")

    atlantis_require_dir "$INSTALLER_PREP_PATH"
    atlantis_require_file "$INSTALLER_PREP_PATH/active-profile.env"
    atlantis_require_file "$INSTALLER_PREP_PATH/manifests/installer-prep-contract.txt"
    atlantis_require_file "$INSTALLER_PREP_PATH/plans/flashing-plan.txt"

    PARTITION_DECISIONS_FILE="$FLASHING_DECISION_PATH/partition-targets.env"
    AVB_DECISIONS_FILE="$FLASHING_DECISION_PATH/avb-vbmeta-policy.env"
    SLOT_DECISIONS_FILE="$FLASHING_DECISION_PATH/slot-strategy.env"
    PROVENANCE_DECISIONS_FILE="$FLASHING_DECISION_PATH/boot-input-provenance.env"

    atlantis_require_file "$PARTITION_DECISIONS_FILE"
    atlantis_require_file "$AVB_DECISIONS_FILE"
    atlantis_require_file "$SLOT_DECISIONS_FILE"
    atlantis_require_file "$PROVENANCE_DECISIONS_FILE"
    atlantis_require_file "$DECISION_REVIEW_STATUS_PATH"

    # shellcheck disable=SC1090
    . "$PARTITION_DECISIONS_FILE"
    # shellcheck disable=SC1090
    . "$AVB_DECISIONS_FILE"
    # shellcheck disable=SC1090
    . "$SLOT_DECISIONS_FILE"
    # shellcheck disable=SC1090
    . "$PROVENANCE_DECISIONS_FILE"
    # shellcheck disable=SC1090
    . "$DECISION_REVIEW_STATUS_PATH"

    unresolved_count=0

    check_decision_value() {
        decision_label=$1
        decision_value=$2

        if atlantis_value_is_unresolved "$decision_value"; then
            unresolved_count=$((unresolved_count + 1))
            echo "Unresolved flashing decision: $decision_label"
        fi
    }

    check_decision_value "partition mapping evidence" "${ATLANTIS_SHIBA_PARTITION_MAPPING_EVIDENCE:-}"
    check_decision_value "boot input target partition role" "${ATLANTIS_SHIBA_PARTITION_BOOT_INPUT_TARGET:-}"
    check_decision_value "initramfs input target partition role" "${ATLANTIS_SHIBA_PARTITION_INITRAMFS_INPUT_TARGET:-}"
    check_decision_value "rootfs handoff target" "${ATLANTIS_SHIBA_PARTITION_ROOTFS_HANDOFF_TARGET:-}"
    check_decision_value "partition target notes" "${ATLANTIS_SHIBA_PARTITION_TARGET_NOTES:-}"

    check_decision_value "AVB policy evidence" "${ATLANTIS_SHIBA_AVB_POLICY_EVIDENCE:-}"
    check_decision_value "vbmeta target" "${ATLANTIS_SHIBA_AVB_VBMETA_TARGET:-}"
    check_decision_value "AVB verification approach" "${ATLANTIS_SHIBA_AVB_VERIFICATION_APPROACH:-}"
    check_decision_value "AVB write requirement" "${ATLANTIS_SHIBA_AVB_WRITE_REQUIREMENT:-}"
    check_decision_value "AVB policy notes" "${ATLANTIS_SHIBA_AVB_POLICY_NOTES:-}"

    check_decision_value "slot strategy evidence" "${ATLANTIS_SHIBA_SLOT_EVIDENCE:-}"
    check_decision_value "slot read method" "${ATLANTIS_SHIBA_SLOT_READ_METHOD:-}"
    check_decision_value "slot target policy" "${ATLANTIS_SHIBA_SLOT_TARGET_POLICY:-}"
    check_decision_value "slot fallback policy" "${ATLANTIS_SHIBA_SLOT_FALLBACK_POLICY:-}"
    check_decision_value "slot notes" "${ATLANTIS_SHIBA_SLOT_NOTES:-}"

    check_decision_value "kernel provenance" "${ATLANTIS_SHIBA_KERNEL_PROVENANCE:-}"
    check_decision_value "initramfs provenance" "${ATLANTIS_SHIBA_INITRAMFS_PROVENANCE:-}"
    check_decision_value "firmware provenance" "${ATLANTIS_SHIBA_FIRMWARE_PROVENANCE:-}"
    check_decision_value "boot-input provenance evidence" "${ATLANTIS_SHIBA_BOOT_INPUT_PROVENANCE_EVIDENCE:-}"
    check_decision_value "boot-input provenance notes" "${ATLANTIS_SHIBA_BOOT_INPUT_NOTES:-}"

    echo "Shiba flashing decision files present: yes"
    echo "Shiba flashing decision files reviewable: yes"

    if [ "$unresolved_count" -eq 0 ]; then
        echo "Shiba flashing decision set sufficient for future command generation: yes"
    else
        echo "Shiba flashing decision set sufficient for future command generation: no"
    fi
}

validate_shiba_evidence() {
    INSTALLER_PREP_DIR=${ATLANTIS_INSTALLER_PREP_DIR:-}
    FLASHING_DECISION_DIR=${ATLANTIS_FLASHING_DECISION_DIR:-}
    COMMAND_PLAN_DIR=${ATLANTIS_COMMAND_PLAN_DIR:-}
    EVIDENCE_BUNDLE_DIR=${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba evidence collection requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba evidence collection requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
    atlantis_require_value "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_require_value "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
    atlantis_require_value "ATLANTIS_EVIDENCE_BUNDLE_DIR" "$EVIDENCE_BUNDLE_DIR"

    INSTALLER_PREP_PATH=$(atlantis_path_from_repo "$INSTALLER_PREP_DIR")
    FLASHING_DECISION_PATH=$(atlantis_path_from_repo "$FLASHING_DECISION_DIR")

    atlantis_require_dir "$INSTALLER_PREP_PATH"
    atlantis_require_file "$INSTALLER_PREP_PATH/active-profile.env"
    atlantis_require_file "$INSTALLER_PREP_PATH/manifests/installer-prep-contract.txt"
    atlantis_require_file "$INSTALLER_PREP_PATH/plans/flashing-plan.txt"

    atlantis_require_file "$FLASHING_DECISION_PATH/partition-targets.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/avb-vbmeta-policy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/slot-strategy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/boot-input-provenance.env"
}

validate_shiba_decision_review() {
    FLASHING_DECISION_DIR=${ATLANTIS_FLASHING_DECISION_DIR:-}
    EVIDENCE_BUNDLE_DIR=${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}
    DECISION_REVIEW_DIR=${ATLANTIS_DECISION_REVIEW_DIR:-}
    DECISION_REVIEW_STATUS_FILE=${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba decision review requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba decision review requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_require_value "ATLANTIS_EVIDENCE_BUNDLE_DIR" "$EVIDENCE_BUNDLE_DIR"
    atlantis_require_value "ATLANTIS_DECISION_REVIEW_DIR" "$DECISION_REVIEW_DIR"
    atlantis_require_value "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"

    FLASHING_DECISION_PATH=$(atlantis_path_from_repo "$FLASHING_DECISION_DIR")
    EVIDENCE_BUNDLE_PATH=$(atlantis_path_from_repo "$EVIDENCE_BUNDLE_DIR")
    DECISION_REVIEW_STATUS_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_STATUS_FILE")

    atlantis_require_dir "$FLASHING_DECISION_PATH"
    atlantis_require_dir "$EVIDENCE_BUNDLE_PATH"
    atlantis_require_file "$DECISION_REVIEW_STATUS_PATH"

    atlantis_require_file "$FLASHING_DECISION_PATH/partition-targets.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/avb-vbmeta-policy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/slot-strategy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/boot-input-provenance.env"

    atlantis_require_file "$EVIDENCE_BUNDLE_PATH/metadata/evidence-summary.env"
    atlantis_require_file "$EVIDENCE_BUNDLE_PATH/suggestions/partition-targets.suggested.env"
    atlantis_require_file "$EVIDENCE_BUNDLE_PATH/suggestions/avb-vbmeta-policy.suggested.env"
    atlantis_require_file "$EVIDENCE_BUNDLE_PATH/suggestions/slot-strategy.suggested.env"
    atlantis_require_file "$EVIDENCE_BUNDLE_PATH/suggestions/boot-input-provenance.suggested.env"
}

validate_shiba_decision_apply() {
    DECISION_REVIEW_DIR=${ATLANTIS_DECISION_REVIEW_DIR:-}
    DECISION_REVIEW_STATUS_FILE=${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}

    validate_shiba_decision_review

    DECISION_REVIEW_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_DIR")
    DECISION_REVIEW_STATUS_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_STATUS_FILE")

    atlantis_require_dir "$DECISION_REVIEW_PATH"
    atlantis_require_file "$DECISION_REVIEW_PATH/suggestions/partition-targets.suggested.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/suggestions/avb-vbmeta-policy.suggested.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/suggestions/slot-strategy.suggested.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/suggestions/boot-input-provenance.suggested.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/approvals/partition-targets.review.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/approvals/avb-vbmeta-policy.review.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/approvals/slot-strategy.review.env"
    atlantis_require_file "$DECISION_REVIEW_PATH/approvals/boot-input-provenance.review.env"
    atlantis_require_file "$DECISION_REVIEW_STATUS_PATH"
}

report_installer_reference_state() {
    installer_prep_path=$1
    metadata_file=$2
    label=$3

    referenced_path=$(atlantis_read_first_line "$installer_prep_path/metadata/$metadata_file")
    if [ -n "$referenced_path" ] && [ -e "$referenced_path" ]; then
        echo "$label present: yes"
        return 0
    fi

    echo "$label present: no"
    return 1
}

validate_shiba_readiness() {
    INSTALLER_PREP_DIR=${ATLANTIS_INSTALLER_PREP_DIR:-}
    FLASHING_DECISION_DIR=${ATLANTIS_FLASHING_DECISION_DIR:-}
    COMMAND_PLAN_DIR=${ATLANTIS_COMMAND_PLAN_DIR:-}
    DECISION_REVIEW_STATUS_FILE=${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}
    EVIDENCE_BUNDLE_DIR=${ATLANTIS_EVIDENCE_BUNDLE_DIR:-}
    DECISION_REVIEW_DIR=${ATLANTIS_DECISION_REVIEW_DIR:-}
    READINESS_DIR=${ATLANTIS_READINESS_DIR:-}

    [ "$PROFILE_KIND" = "device" ] || atlantis_die "Shiba readiness checking requires a device profile. Active profile kind: $PROFILE_KIND"
    [ "${ATLANTIS_DEVICE_ID:-}" = "google-shiba" ] || atlantis_die "Shiba readiness checking requires ATLANTIS_DEVICE_ID=google-shiba."

    atlantis_require_value "ATLANTIS_INSTALLER_PREP_DIR" "$INSTALLER_PREP_DIR"
    atlantis_require_value "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_require_value "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
    atlantis_require_value "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"
    atlantis_require_value "ATLANTIS_READINESS_DIR" "$READINESS_DIR"

    INSTALLER_PREP_PATH=$(atlantis_path_from_repo "$INSTALLER_PREP_DIR")
    FLASHING_DECISION_PATH=$(atlantis_path_from_repo "$FLASHING_DECISION_DIR")
    COMMAND_PLAN_PATH=$(atlantis_path_from_repo "$COMMAND_PLAN_DIR")
    DECISION_REVIEW_STATUS_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_STATUS_FILE")
    EVIDENCE_BUNDLE_PATH=$(atlantis_path_from_repo "$EVIDENCE_BUNDLE_DIR")
    DECISION_REVIEW_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_DIR")

    atlantis_require_dir "$INSTALLER_PREP_PATH"
    atlantis_require_dir "$COMMAND_PLAN_PATH"
    atlantis_require_file "$COMMAND_PLAN_PATH/metadata/command-plan-summary.env"
    atlantis_require_file "$COMMAND_PLAN_PATH/plans/command-plan.txt"
    atlantis_require_file "$DECISION_REVIEW_STATUS_PATH"
    atlantis_require_file "$FLASHING_DECISION_PATH/partition-targets.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/avb-vbmeta-policy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/slot-strategy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/boot-input-provenance.env"

    report_installer_reference_state "$INSTALLER_PREP_PATH" "boot-artifact-stage.path" "Shiba boot-artifact reference"
    report_installer_reference_state "$INSTALLER_PREP_PATH" "compose-stage.path" "Shiba compose-stage reference"
    report_installer_reference_state "$INSTALLER_PREP_PATH" "generic-rootfs.path" "Generic rootfs reference"
    report_installer_reference_state "$INSTALLER_PREP_PATH" "package-feed.path" "Package feed reference"
    report_installer_reference_state "$INSTALLER_PREP_PATH" "kernel-artifact.path" "Kernel artifact reference"
    report_installer_reference_state "$INSTALLER_PREP_PATH" "initramfs-artifact.path" "Initramfs artifact reference"

    if [ -d "$EVIDENCE_BUNDLE_PATH" ] && [ -f "$EVIDENCE_BUNDLE_PATH/metadata/evidence-summary.env" ]; then
        echo "Shiba evidence bundle present: yes"
    else
        echo "Shiba evidence bundle present: no"
    fi

    if [ -d "$DECISION_REVIEW_PATH" ] && [ -f "$DECISION_REVIEW_PATH/active-profile.env" ]; then
        echo "Shiba decision-review directory present: yes"
    else
        echo "Shiba decision-review directory present: no"
    fi
}

validate_shiba_session_bundle() {
    READINESS_DIR=${ATLANTIS_READINESS_DIR:-}
    SESSION_BUNDLE_DIR=${ATLANTIS_SESSION_BUNDLE_DIR:-}

    validate_shiba_readiness

    atlantis_require_value "ATLANTIS_SESSION_BUNDLE_DIR" "$SESSION_BUNDLE_DIR"

    READINESS_PATH=$(atlantis_path_from_repo "$READINESS_DIR")
    atlantis_require_dir "$READINESS_PATH"
    atlantis_require_file "$READINESS_PATH/metadata/readiness-summary.env"
    atlantis_require_file "$READINESS_PATH/checklists/operator-session-checklist.txt"
}

validate_shiba_execution() {
    COMMAND_PLAN_DIR=${ATLANTIS_COMMAND_PLAN_DIR:-}
    FLASHING_DECISION_DIR=${ATLANTIS_FLASHING_DECISION_DIR:-}
    DECISION_REVIEW_STATUS_FILE=${ATLANTIS_DECISION_REVIEW_STATUS_FILE:-}
    SESSION_BUNDLE_DIR=${ATLANTIS_SESSION_BUNDLE_DIR:-}
    EXECUTION_DIR=${ATLANTIS_EXECUTION_DIR:-}

    validate_shiba_session_bundle

    atlantis_require_value "ATLANTIS_COMMAND_PLAN_DIR" "$COMMAND_PLAN_DIR"
    atlantis_require_value "ATLANTIS_FLASHING_DECISION_DIR" "$FLASHING_DECISION_DIR"
    atlantis_require_value "ATLANTIS_DECISION_REVIEW_STATUS_FILE" "$DECISION_REVIEW_STATUS_FILE"
    atlantis_require_value "ATLANTIS_SESSION_BUNDLE_DIR" "$SESSION_BUNDLE_DIR"
    atlantis_require_value "ATLANTIS_EXECUTION_DIR" "$EXECUTION_DIR"

    COMMAND_PLAN_PATH=$(atlantis_path_from_repo "$COMMAND_PLAN_DIR")
    FLASHING_DECISION_PATH=$(atlantis_path_from_repo "$FLASHING_DECISION_DIR")
    DECISION_REVIEW_STATUS_PATH=$(atlantis_path_from_repo "$DECISION_REVIEW_STATUS_FILE")
    SESSION_BUNDLE_PATH=$(atlantis_path_from_repo "$SESSION_BUNDLE_DIR")

    atlantis_require_dir "$COMMAND_PLAN_PATH"
    atlantis_require_dir "$SESSION_BUNDLE_PATH"
    atlantis_require_file "$COMMAND_PLAN_PATH/metadata/command-plan-summary.env"
    atlantis_require_file "$COMMAND_PLAN_PATH/plans/command-plan.txt"
    atlantis_require_file "$DECISION_REVIEW_STATUS_PATH"
    atlantis_require_file "$FLASHING_DECISION_PATH/partition-targets.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/avb-vbmeta-policy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/slot-strategy.env"
    atlantis_require_file "$FLASHING_DECISION_PATH/boot-input-provenance.env"
    atlantis_require_file "$SESSION_BUNDLE_PATH/metadata/session-bundle-summary.env"
    atlantis_require_file "$SESSION_BUNDLE_PATH/checklists/operator-session-checklist.txt"
}

case "$MODE" in
    package-build)
        validate_package_build
        ;;
    rootfs)
        validate_rootfs
        ;;
    package-feed)
        validate_package_feed
        ;;
    shiba-compose)
        validate_shiba_compose
        ;;
    shiba-boot-artifacts)
        validate_shiba_boot_artifacts
        ;;
    shiba-installer-prep)
        validate_shiba_installer_prep
        ;;
    shiba-command-plan)
        validate_shiba_command_plan
        ;;
    shiba-evidence)
        validate_shiba_evidence
        ;;
    shiba-decision-review)
        validate_shiba_decision_review
        ;;
    shiba-decision-apply)
        validate_shiba_decision_apply
        ;;
    shiba-readiness)
        validate_shiba_readiness
        ;;
    shiba-session-bundle)
        validate_shiba_session_bundle
        ;;
    shiba-execution)
        validate_shiba_execution
        ;;
esac

echo "Atlantis preflight passed for $MODE: $PROFILE_NAME ($PROFILE)"
