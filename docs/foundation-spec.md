# Atlantis Foundation Specification

## 1. Product Definition

Atlantis is a Debian-based mobile operating system for mainstream smartphone users. It is intended to feel calm, modern, trustworthy, and understandable while remaining maintainable by a real engineering team over years of iteration.

Atlantis is not an Android ROM and not an Android-derived product definition. Device bring-up may temporarily rely on device-specific kernel and firmware realities where needed, but the product architecture is Debian-first and Atlantis-owned.

## 2. Target Audience

Primary audience:

- normal smartphone users who expect a polished daily-driver experience
- users who value clarity, privacy, predictable behavior, and long-term support

Secondary audience:

- engineers and early adopters contributing to bring-up, packaging, QA, and product maturity

Atlantis should not require users to be Linux specialists to understand basic system behavior.

## 3. Product Principles

- Truthfulness over optimism
- Reproducibility over ad-hoc customization
- Long-term maintainability over short-lived hacks
- Clear ownership boundaries between system layers
- Upstream-oriented reuse where it reduces risk
- Mainstream usability over enthusiast-only roughness
- Documentation as a first-class deliverable

## 4. UX Principles

Atlantis should feel:

- calm, not noisy
- modern, not experimental
- capable, not stripped-down
- polished, not developer-first
- simple in primary flows, not simplistic in functionality

Core user journeys must eventually include:

- home screen
- app launcher
- lock screen
- notifications
- quick settings
- settings app
- app switching
- on-screen keyboard integration
- update flow

Sprint 0 does not implement these flows; it reserves the architectural space for them.

## 5. Technical Baseline

- Base distribution: Debian stable
- Package management: `apt` and `dpkg`
- Display stack: Wayland
- OS composition style: Debian packages plus reproducible image composition
- Preferred bootstrap primitive: `mmdebstrap`-generated Debian root filesystems with pinned package inputs
- Mobile UX strategy: pragmatic modular integration of proven upstream components, wrapped by Atlantis-owned packages and services where product behavior must be specific
- Primary development device: Google Pixel 8 (`shiba`)
- Secondary validation device: not yet selected; must be a newer device, not a legacy fallback

## 6. Architectural Layers

### 6.1 Core OS

Owns:

- Debian base system composition
- package feeds and metapackages
- update assumptions
- system services and policy defaults

Does not own:

- branding details
- device-specific quirks
- installer logic

### 6.2 Shell and UX

Owns:

- launcher, lock screen, quick settings, notifications, navigation, and shell-facing service integration

Must remain:

- replaceable in parts
- decoupled from device quirks
- packaged independently from core OS composition

### 6.3 Branding

Owns:

- design tokens
- logos
- wallpapers
- sounds
- theme defaults

Branding must not block engineering progress.

### 6.4 Device Enablement

Owns:

- kernel and boot integration choices for specific devices
- firmware acquisition procedures
- hardware quirks
- device validation evidence

Device code must remain isolated under `device/` and device packages.

### 6.5 Installer and Flash Tooling

Owns:

- host-side flashing flows
- image packaging for installable artifacts
- device safety prompts and rollback-aware procedures

### 6.6 CI and Release

Owns:

- package validation
- manifest checks
- smoke image builds
- release metadata and provenance capture

## 7. Device Strategy

Pixel 8 (`shiba`) is the first bring-up target because it is available, not because Atlantis is intended to become a Pixel-only system.

Device strategy rules:

- keep generic Atlantis layers device-agnostic
- confine device-specific logic to `device/` and device packages
- document all firmware and kernel provenance
- choose bootstrap steps that can be repeated for a second modern device
- avoid shell or package assumptions that hard-code Pixel-specific hardware behavior

## 8. Repository Structure

- `manifest/`: build composition, source pinning, image profiles, reproducibility metadata
- `packages/`: Atlantis-owned Debian packages and metapackages
- `shell/`: Atlantis shell and user-facing system integration
- `branding/`: visual assets and theme resources
- `device/`: per-device enablement and validation notes
- `installer/`: host-side install and flash tooling
- `docs/`: specifications, ADRs, plans, and status tracking
- `ci/`: validation and release automation

## 9. v0.1 Definition of Done

Atlantis v0.1 is not a finished consumer OS. The initial milestone is complete when all of the following exist in credible form:

- reproducible Debian root filesystem composition for Atlantis images
- Atlantis package repository or equivalent package feed generation
- installable development artifact path for Pixel 8 bring-up
- documented and reviewable device package boundary for `shiba`
- first boot path that reaches a visible system state on the target device
- truthful status matrices showing what is planned, building, booting, or verified
- CI coverage for package linting and image composition smoke checks

Hardware features are not part of v0.1 unless directly evidenced.

## 10. Non-Goals

Atlantis is not intended to become:

- an Android ROM
- an AOSP derivative
- a one-device-only experiment
- a hobby distro with exposed rough edges as the product surface
- a rewrite of every upstream graphics or shell component from scratch

## 11. Current Branding Assumptions

These assumptions are active until superseded:

- product name: Atlantis
- primary color family: Atlantis Blue
- secondary accent family: Seafoam
- logo direction: minimal clean droplet mark
- working system font: Inter

These are sufficient for packaging and theming scaffolding, but not yet a full brand system.

## 12. Truthfulness and Testing Policy for Hardware Claims

Atlantis uses explicit validation states:

- `planned`
- `in progress`
- `builds`
- `boots`
- `smoke-tested`
- `verified`
- `broken`
- `unverified`

Rules:

- never describe a capability as working without direct evidence
- if evidence is missing, use `unverified`
- distinguish image build success from boot success
- distinguish boot success from feature verification
- record evidence source, date, artifact, and tester when possible
- do not collapse unknown states into optimistic wording

This policy applies especially to boot, display, touch, storage, encryption, Wi-Fi, Bluetooth, audio, suspend, modem, SMS/data, camera, GPS, sensors, fingerprint, battery reporting, and charging.
