# Atlantis Roadmap

## Planning Assumptions

- execution is staged to reduce risk and preserve reviewability
- no milestone implies hardware support unless evidence is recorded
- Pixel 8 is the first device target, but each sprint should leave reusable artifacts for future devices

## Sprint 0: Foundation

Goal:

- establish repository structure, core docs, ADRs, package skeletons, status tracking, and chosen bootstrap strategy

Exit criteria:

- repo skeleton exists
- foundation spec exists
- baseline ADRs exist
- status matrices and testing policy exist
- initial package skeletons exist

Status:

- `in progress`

## Sprint 1: Boot and Build Path Definition

Goal:

- define and implement the first real Atlantis boot path without claiming working hardware

Planned work:

- bootstrap a minimal Debian rootfs with `mmdebstrap`
- move Sprint 1 generic rootfs composition behind a manifest/profile boundary
- define Atlantis package build and package feed integration for image composition
- document QEMU ARM64, nested Phosh, and Pixel 8 testing roles
- add concrete Sprint 1 smoke-path runbooks for QEMU ARM64 and nested Phosh
- define Phosh integration boundaries as the initial shell strategy
- document the Pixel 8 boot chain assumptions and first flashing model

Exit criteria:

- `mmdebstrap` rootfs path exists as scripts plus documentation
- generic development profile defines the Sprint 1 rootfs inputs
- package build outputs land in an explicit artifact directory and the feed path consumes that directory
- testing strategy is defined
- Phosh integration is defined without pretending Atlantis UI is finished
- Pixel 8 boot path is documented with unknowns, blockers, and risks
- next step for the first boot attempt is clear

Status:

- `in progress`

## Sprint 2: First Boot Attempt

Goal:

- execute the documented Pixel 8 bring-up path and capture the first truthful boot result

Planned work:

- build Atlantis packages into a local feed and generic rootfs artifact
- keep the package build artifact boundary explicit and separate from the generated feed
- stage the first reviewable `shiba` compose output from the generic rootfs artifact, the package feed artifact, and the optional device package boundary
- stage the first reviewable `shiba` boot-artifact directory from the compose output plus explicit kernel/initramfs artifact inputs
- stage the first guarded `shiba` installer-preparation output from the boot-artifact directory plus host-side checks
- move partition targets, AVB/vbmeta handling, slot strategy, and firmware provenance into structured decision files with truthful unresolved placeholders until validated
- stage the first read-only `shiba` evidence bundle to inform those structured flashing decisions truthfully
- stage the first guarded `shiba` decision-review output so evidence suggestions can be reviewed and applied deliberately
- stage the first guarded `shiba` command-plan / execution-bundle output from the installer-preparation directory plus the structured flashing-decision files
- stage the first guarded `shiba` readiness-check output from the command-plan output plus the live reviewed decision state
- stage the first operator-facing `shiba` session bundle from the readiness-check output plus the current guarded review artifacts
- stage the first guarded `shiba` execution harness that defaults to dry-run, consumes the reviewed session artifacts, and records an auditable session ledger before any destructive command can run
- implement the safest possible host-side flashing flow
- capture the first hardware boot evidence or precise failure point

Exit criteria:

- staged device-oriented `shiba` compose output exists on top of the generic rootfs and package feed artifacts
- staged `shiba` boot-artifact output exists and truthfully records unresolved boot-chain items
- staged `shiba` installer-preparation output exists and truthfully records unresolved flashing-plan items
- structured `shiba` flashing-decision files exist and keep unresolved flashing choices explicit
- staged `shiba` evidence bundle exists and truthfully records read-only decision evidence or missing-device states
- staged `shiba` decision-review output exists and distinguishes accepted, unresolved, rejected, and deferred evidence suggestions
- staged `shiba` command-plan output exists and remains blocked when required flashing decisions are unresolved
- staged `shiba` readiness-check output exists and classifies blocked, review-ready, and session-ready states truthfully
- staged `shiba` operator-session bundle exists and records exact inputs, blockers, and non-claims for a future manual hardware session
- staged `shiba` execution-harness output exists, defaults to dry-run, and records rendered versus attempted steps explicitly
- installable development artifact path remains blocked on validated partition/AVB/slot/fastboot decisions plus flashing work
- boot attempt process is executed on real hardware
- boot status is truthfully recorded as `boots`, `broken`, or `unverified`

Status:

- `planned`

## Sprint 3: First Visible Shell

Goal:

- reach a visible Atlantis-branded shell layer on a booted system

Planned work:

- choose initial shell component stack
- package shell dependencies
- add lock screen, launcher shell surface, and settings entry points as stubs
- integrate basic branding tokens without redesigning the brand system

Exit criteria:

- visible shell session is reachable on supported build path
- shell package build is automated
- user-facing shell status is documented separately from hardware capability status

Status:

- `planned`

## Sprint 4: Input, Network, and Settings Basics

Goal:

- establish basic usability primitives for interactive testing

Planned work:

- touch/input integration
- Wi-Fi bring-up path if hardware allows
- initial settings surfaces
- on-screen keyboard integration path
- basic logs and bug-report capture flow

Exit criteria:

- interactive test plan exists for input/network/settings basics
- each capability is marked with explicit validation state

Status:

- `planned`

## Beyond Sprint 4

Future planning areas, intentionally not committed yet:

- update and rollback flow
- notifications and quick settings maturity beyond upstream Phosh
- modem and telephony validation
- camera and sensor strategy
- second-device selection and portability review
