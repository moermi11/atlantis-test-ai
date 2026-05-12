# Atlantis Testing and Validation Policy

## Purpose

This document defines how Atlantis reports progress and validates claims.

## Validation States

- `planned`: work is identified but implementation has not started
- `in progress`: engineering work is underway but no stable output is claimed
- `builds`: a relevant package or image artifact builds successfully
- `boots`: the system reaches a booted state on target hardware
- `smoke-tested`: basic manual sanity checks passed for a capability
- `verified`: capability is confirmed with recorded evidence on hardware
- `broken`: a capability is known not to work or regressed from a prior known state
- `unverified`: no direct evidence is available yet

## Evidence Expectations

For hardware-related claims, prefer recording:

- date tested
- tester
- device model and revision if relevant
- build or artifact identifier
- brief result summary
- logs, photos, serial output, or command transcripts when available

## Core Rule

Atlantis must never claim a hardware feature works without direct evidence.

Examples:

- an image produced by CI is `builds`, not `boots`
- seeing a boot splash is not enough to mark touch or Wi-Fi as verified
- a planned modem path remains `unverified` until a real device test confirms it

## Test Layers

### Documentation and Policy

- link checks
- document completeness reviews
- ADR consistency

### Packaging

- `dpkg-buildpackage` success
- explicit package artifact directory population under `out/packages/`
- `lintian` and packaging sanity checks
- dependency closure review for metapackages

### Image Composition

- rootfs bootstrap reproducibility
- local package feed generation from explicit built package artifacts
- manifest validation
- artifact checksum generation

### Device Bring-Up

- boot path evidence
- input/display/audio/network smoke tests
- installer safety validation

## Sprint 1 Test Targets

Atlantis Sprint 1 uses three complementary validation targets. None of them is sufficient on its own.

### A. QEMU ARM64 (`virt`)

Primary role:

- validate that a generic ARM64 Debian rootfs can be composed reproducibly with `mmdebstrap`
- exercise package installation and dependency closure for `atlantis-base`, `atlantis-branding`, and `atlantis-shell`
- boot a generic ARM64 kernel/initramfs/userspace combination to verify early userspace assumptions
- provide a fast place to catch obvious `systemd`, packaging, and image assembly failures

What this target can meaningfully prove:

- rootfs composition `builds`
- Atlantis package feed integration `builds`
- generic ARM64 userspace reaches a booted state if a suitable `virt` kernel/initramfs is supplied
- broad regressions in service startup can be smoke-tested quickly

What this target cannot prove:

- Pixel 8 bootloader behavior
- fastboot flashing safety
- Pixel-specific kernel, display, touch, storage, sensors, modem, camera, or power management
- whether a `shiba` boot image is acceptable to the real device boot chain

State guidance:

- QEMU results can move generic build targets to `builds`, and a generic VM image to `boots`
- QEMU results must not move Pixel 8 hardware capabilities above `unverified`

Execution document:

- [docs/testing/qemu-arm64-smoke-path.md](testing/qemu-arm64-smoke-path.md)

### B. Desktop Nested Testing (`Phosh`)

Primary role:

- run the initial Phosh-based shell stack inside a developer workstation session before hardware bring-up
- validate shell packaging, branding handoff, session defaults, and basic UI navigation paths without requiring device flashing
- test Atlantis-owned shell integration boundaries while still relying on upstream Phosh behavior

How UI will be tested without hardware:

- install Atlantis metapackages on a Debian development environment
- launch a nested Wayland session using upstream Phosh tooling
- check that Atlantis branding assets, package dependencies, and session wiring behave as expected
- use desktop keyboard and pointer input for early smoke checks

What this target can meaningfully prove:

- `atlantis-shell` installs and pulls the intended upstream stack
- Phosh-based session startup path is wired correctly enough for desktop smoke tests
- branding and shell packaging regressions can be found before hardware flashing

What this target cannot prove:

- ARM64-specific behavior
- phone boot chain correctness
- touch tuning, display panel behavior, suspend, battery, modem, camera, or radio integration
- real-device performance or thermal characteristics

State guidance:

- nested testing can move the shell integration path to `smoke-tested`
- nested testing does not justify marking phone hardware features as `verified`

Execution document:

- [docs/testing/nested-phosh-smoke-path.md](testing/nested-phosh-smoke-path.md)

### C. Real Hardware (Google Pixel 8 `shiba`)

Primary role:

- validate the only boot path that matters for the first Atlantis device
- confirm bootloader assumptions, flashing procedures, kernel compatibility, initramfs handoff, and real userspace startup
- capture evidence for display, touch, storage, and any later hardware capability claims

What only real hardware can prove:

- whether the device accepts the Atlantis development boot artifacts
- whether the boot chain reaches a visible booted state on `shiba`
- whether display, touch, storage, charging, radio, and power behavior work on the actual phone
- whether slot handling, rollback risk, and recovery procedures are safe enough for repeated bring-up

State guidance:

- only direct Pixel 8 testing can move Pixel 8 capabilities to `boots`, `smoke-tested`, or `verified`
- absence of hardware evidence keeps the status at `unverified`

Hardware boot-path document:

- [docs/device/google/shiba/boot-path.md](device/google/shiba/boot-path.md)

## Sprint 1 Reality

As of Sprint 1 planning and build-path definition:

- no Atlantis hardware capability is `verified`
- no Pixel 8 boot claim exists
- QEMU, nested Phosh, and Pixel 8 all remain required parts of the validation strategy
- the current deliverable is a credible first boot path, not a completed phone OS

## Status Language Reminder

Use only the following states in matrices and status reports:

- `planned`
- `in progress`
- `builds`
- `boots`
- `smoke-tested`
- `verified`
- `broken`
- `unverified`
