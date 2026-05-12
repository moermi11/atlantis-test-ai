# Pixel 8 (`shiba`) Boot Path

## Status

- boot path definition: `in progress`
- flashing implementation: `planned`
- hardware boot result: `unverified`

This document defines the first credible Atlantis boot path for Google Pixel 8 (`shiba`). It does not claim that Atlantis currently boots on this device.

The repo now contains a `shiba` compose staging script at `device/google/shiba/compose.sh`, a follow-on boot-artifact staging script at `device/google/shiba/stage-boot-artifacts.sh`, a guarded installer-preparation script at `installer/shiba/prepare.sh`, structured flashing-decision files under `installer/shiba/decisions/`, a read-only evidence collector at `installer/shiba/collect-evidence.sh`, a guarded decision review/apply script at `installer/shiba/review-decisions.sh`, a guarded command-plan generator at `installer/shiba/generate-command-plan.sh`, a guarded readiness checker at `installer/shiba/check-readiness.sh`, an operator-session bundle generator at `installer/shiba/generate-session-bundle.sh`, and a guarded execution harness at `installer/shiba/execute-session.sh`. These layers create reviewable handoff directories, evidence bundles, approval manifests, readiness summaries, session bundles, and execution ledgers only. They are not proof that Pixel 8 `boots`.

## Assumptions

Bootloader assumptions for Sprint 1:

- the device bootloader is unlockable and unlocked for development use
- OEM unlocking was enabled before running `fastboot flashing unlock`
- the user preserves a known-good stock recovery path before flashing Atlantis development artifacts

Relevant upstream references:

- Android Open Source Project bootloader unlock flow: [Lock and unlock the bootloader](https://source.android.com/docs/core/architecture/bootloader/locking_unlocking)
- Google Pixel factory image guidance and rollback warning: [Factory Images for Nexus and Pixel Devices](https://developers.google.com/android/images)

## Flashing Model

Sprint 1 flashing model:

- host-side flashing uses `fastboot`
- flashing is treated as a development workflow, not an installer UX
- Atlantis does not overwrite random partitions ad hoc; the exact partition map must be documented before implementation
- stock recovery images should remain available so the device can be restored after failed bring-up attempts

Current non-claim:

- Atlantis does not yet provide a safe flashing script for `shiba`
- Atlantis does not yet provide a final fastboot command sequence for `shiba`

## Boot Chain Overview

High-level boot chain for the first Atlantis attempt:

1. Pixel 8 starts in the vendor-controlled secure boot chain.
2. The unlocked bootloader accepts a development flashing workflow and can enter fastboot mode.
3. A device-specific Atlantis boot artifact supplies the kernel and the initramfs needed for early userspace.
4. The initramfs mounts or pivots into the Atlantis rootfs built by `mmdebstrap`.
5. `systemd` starts the generic Atlantis userspace from that rootfs.
6. The initial shell path attempts to reach upstream Phosh through the Atlantis package boundary.

Important boundary:

- steps 1 to 3 are device-specific and belong to `atlantis-device-google-shiba` plus installer tooling
- steps 4 to 6 are generic Atlantis userspace and must remain device-agnostic

## Kernel, Initramfs, and Rootfs Structure

### Kernel

- owned by the `shiba` device bring-up path
- not part of `atlantis-base`
- must carry whatever device support is required to reach early userspace on Pixel 8

Sprint 1 does not claim a final kernel source choice or config set.

### Initramfs

- acts as the bridge between the device boot artifact and the Atlantis rootfs
- should stay as generic as possible, with `shiba`-specific boot requirements kept isolated
- is expected to perform the minimum work needed to locate and mount the Atlantis rootfs

Sprint 1 does not yet define the final initramfs contents.

### Staged compose output

- owned by `device/google/shiba/compose.sh`
- consumes the generic rootfs artifact and local package feed artifact
- records the `atlantis-device-google-shiba` package boundary when present
- leaves kernel and initramfs inputs as placeholders until those artifacts exist

The staged compose output is a reviewable handoff point for Sprint 2 preparation. It is not itself a boot artifact.

### Staged boot-artifact output

- owned by `device/google/shiba/stage-boot-artifacts.sh`
- consumes the staged `shiba` compose output
- requires explicit kernel and initramfs artifact paths from the active `shiba` profile or environment
- stages a reviewable boot-artifact directory with metadata, manifests, and unresolved boot-chain placeholders

The staged boot-artifact output is a reviewable boot-input boundary. It is not a flash package and it is not proof that Pixel 8 `boots`.

### Staged installer-preparation output

- owned by `installer/shiba/prepare.sh`
- consumes the staged `shiba` boot-artifact directory
- checks host-side flashing preparation commands without invoking them
- stages a reviewable installer-preparation directory with manifests, assumptions, and a flashing-plan file

The staged installer-preparation output is a reviewable host-side preparation boundary. It is not a fastboot command sequence, it is not a flashing flow, and it is not proof that Pixel 8 `boots`.

### Structured flashing-decision files

- owned by `installer/shiba/decisions/`
- keep partition targets, AVB/vbmeta handling, slot strategy, and firmware or boot-input provenance explicit in shell-friendly files
- default to truthful unresolved placeholders until real `shiba` evidence exists
- must be reviewed and filled in before any future flashing command sequence can be considered

The structured flashing-decision files are a review boundary. They do not mean the unresolved flashing questions are solved.

### Read-only evidence bundle

- owned by `installer/shiba/collect-evidence.sh`
- consumes the staged `shiba` installer-preparation directory plus the structured flashing-decision files
- runs only safe, read-only host and device probes when `fastboot` or `adb` are available
- generates review companion suggestion files instead of overwriting the structured flashing-decision files

The evidence bundle is a review boundary only. It does not reboot, unlock, erase, or flash anything, and it does not prove that Pixel 8 `boots`.

### Reviewed decision-approval files

- owned by `installer/shiba/review-decisions.sh`
- consume the live structured decision files plus the evidence bundle suggestion files
- record whether each suggestion was accepted, left unresolved, rejected, or deferred
- require an explicit `apply` step before live decision files change

The reviewed decision-approval files are a safety boundary only. They do not mean the resulting live decisions are complete, safe to flash, or proof that Pixel 8 `boots`.

### Applied live decision review state

- recorded in `installer/shiba/decisions/review-status.env`
- tracks whether each live decision field is still unreviewed, reviewed-applied, deferred, rejected, or explicitly left unresolved
- is consumed by the guarded command-plan stage together with the live decision files

The applied live decision review state is still a safety boundary only. It does not make flashing safe by itself, and it does not prove that Pixel 8 `boots`.

### Generated command-plan output

- owned by `installer/shiba/generate-command-plan.sh`
- consumes the staged `shiba` installer-preparation directory plus the structured flashing-decision files
- emits a reviewable command-plan / execution-bundle directory
- stays blocked when required flashing decisions are still unresolved

The generated command-plan output is a review boundary, not an execution boundary. It does not invoke `fastboot`, it does not invoke `adb`, and it does not prove that Pixel 8 `boots`.

### Generated readiness-check output

- owned by `installer/shiba/check-readiness.sh`
- consumes the command-plan output, live decision files, live review-status file, and installer or evidence context where present
- classifies the current repo state as blocked, review-ready, or session-ready
- stays non-destructive and keeps missing or unresolved prerequisites explicit

The generated readiness-check output is a safety boundary only. It does not invoke `fastboot`, it does not invoke `adb`, and it does not prove that Pixel 8 `boots`.

### Generated operator-session bundle

- owned by `installer/shiba/generate-session-bundle.sh`
- consumes the readiness-check output plus the current guarded `shiba` review artifacts
- packages the active profile, current inputs, blockers, non-claims, and operator checklist into one reviewable directory
- remains blocked or review-ready truthfully when prerequisites are still incomplete

The generated operator-session bundle is a preparation boundary only. It does not perform a flashing session, and it does not prove that Pixel 8 `boots`.

### Generated execution-harness output

- owned by `installer/shiba/execute-session.sh`
- consumes the command-plan output, the readiness-check output, the operator-session bundle, and the live reviewed decision files
- defaults to dry-run and renders the first guarded flashing step sequence only when the reviewed inputs are sufficient
- requires an explicit acknowledgement before any destructive `fastboot` step can run
- records rendered commands, attempted commands, per-step outcomes, and stop points in an auditable session ledger

The generated execution-harness output is an execution boundary only. Dry-run is not execution, execution is not proof of boot success, and a completed flashing session would still not prove that Pixel 8 `boots`.

### Rootfs

- built with `mmdebstrap`
- composed from Debian packages plus Atlantis-owned packages
- generic by default: `atlantis-base`, `atlantis-branding`, `atlantis-shell`
- optionally extended with `atlantis-device-google-shiba` for a hardware-focused image build

The `mmdebstrap` rootfs is userspace. It is not the boot artifact by itself.

## How the `mmdebstrap` Rootfs Fits In

The rootfs is the generic Atlantis payload that the device-specific boot path must hand off to.

Expected ownership split:

- `build/mmdebstrap/`: creates the rootfs
- `out/packages/`: receives built Atlantis `.deb` artifacts before feed generation
- `packages/atlantis-base`: defines generic Atlantis package entry points
- `packages/atlantis-shell`: pulls in the initial Phosh-based shell layer
- `packages/atlantis-branding`: owns generic product branding
- `packages/atlantis-device-google-shiba`: owns only `shiba`-specific integration
- `device/google/shiba/compose.sh`: stages a device-oriented handoff directory without implementing flashing
- `device/google/shiba/stage-boot-artifacts.sh`: stages explicit kernel/initramfs inputs on top of the compose handoff without implementing flashing
- `installer/shiba/prepare.sh`: stages a host-side flashing review plan without implementing flashing
- `installer/shiba/decisions/`: records structured flashing decisions with truthful unresolved placeholders until validated
- `installer/shiba/collect-evidence.sh`: captures read-only evidence to inform the structured flashing decisions without overwriting them
- `installer/shiba/review-decisions.sh`: turns evidence suggestions into explicit reviewed approvals and applies them only through a separate guarded step
- `installer/shiba/generate-command-plan.sh`: stages a blocked or reviewable command-plan bundle without implementing flashing
- `installer/shiba/check-readiness.sh`: stages a safety-only readiness summary without implementing flashing
- `installer/shiba/generate-session-bundle.sh`: stages an operator-facing preparation bundle without implementing flashing
- `installer/shiba/execute-session.sh`: stages an auditable dry-run or explicitly acknowledged execution session without claiming boot success
- `installer/`: will later assemble the kernel, initramfs, rootfs, and flash steps into a controlled workflow

## Unknowns

The following remain intentionally unresolved in Sprint 1:

- exact `shiba` partition targets for the Atlantis development boot flow
- exact handling required for AVB, `vbmeta`, and related verified boot components in a development-unlocked state
- the exact future fastboot command sequence and rollback-safe write order once the structured flashing decisions are resolved truthfully
- whether the first rootfs should live on a dedicated image, userdata-backed storage, or another intermediate layout
- the minimum kernel configuration and modules required to reach visible userspace on the device
- the earliest reliable logging path for failed boot attempts

## Blockers

Current blockers to the first real boot attempt:

- no verified `shiba` kernel build artifact is tracked in-repo yet
- no initramfs handoff implementation exists yet
- no real flashing script with rollback-aware safeguards exists yet
- rollback remains manual or unresolved in the first execution harness
- the structured flashing decisions still default to unresolved placeholder values until real device evidence is recorded
- no captured device boot logs or partition inventory are attached to Atlantis bring-up documentation yet

## Risks

Known risks for Sprint 2 bring-up work:

- incorrect flashing could soft-brick the device until stock images are restored
- Pixel 8 anti-rollback behavior is a real risk on devices updated to Android 15 May 2025 or newer, as documented by Google
- a successful kernel boot may still leave display, touch, storage, or other user-facing capabilities `unverified`
- an apparently good boot artifact may fail due to slot handling or verified-boot assumptions that are still undocumented

## What Sprint 2 Must Produce

Before Atlantis can claim a first boot attempt path exists in practice, Sprint 2 must produce:

- a staged `shiba` compose output backed by real kernel and initramfs planning inputs
- a staged `shiba` boot-artifact output backed by real kernel and initramfs artifacts
- a staged `shiba` installer-preparation output backed by a reviewable flashing plan
- structured `shiba` flashing-decision files backed by real partition, AVB, slot, and provenance evidence
- a staged `shiba` evidence bundle that truthfully records read-only host or device observations
- a staged `shiba` decision-review output that records which evidence suggestions were accepted, rejected, deferred, or left unresolved
- a staged `shiba` command-plan output that is no longer blocked on unresolved flashing decisions
- a staged `shiba` readiness-check output that is no longer blocked on missing or unresolved prerequisites
- a staged `shiba` operator-session bundle that truthfully records the exact reviewed inputs for a future manual session
- a staged `shiba` execution-harness output that truthfully records dry-run versus attempted execution steps
- a concrete kernel artifact for `shiba`
- a concrete initramfs handoff design
- a documented fastboot command sequence or scripted equivalent
- a rootfs artifact generated from the Sprint 1 `mmdebstrap` flow
- captured evidence showing whether the device reaches `boots`, stays `broken`, or remains `unverified`
