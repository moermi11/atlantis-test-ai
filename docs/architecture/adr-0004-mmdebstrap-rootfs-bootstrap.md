# ADR-0004: `mmdebstrap` Rootfs Bootstrap

- Status: accepted
- Date: 2026-04-21

## Context

Sprint 1 needs the first executable Atlantis build path, not just a preferred direction. That build path must:

- produce a minimal Debian rootfs for ARM64
- stay reproducible and scriptable
- integrate Atlantis-owned packages without mixing device logic into the generic base image
- remain useful for QEMU, nested desktop testing, and later Pixel 8 hardware bring-up

The team considered three practical bootstrap approaches.

### Option A: `debootstrap` plus manual customization scripts

Advantages:

- familiar and widely used
- minimal dependency footprint

Disadvantages:

- reproducibility tends to drift into ad-hoc post-processing
- weaker built-in support for the richer hook and packaging flow Atlantis needs
- does not improve clarity over the existing decision to use `mmdebstrap`

### Option B: `mmdebstrap` with an Atlantis local package feed

Advantages:

- Debian-native tooling with explicit support for hooks and package selection
- good fit for minimal rootfs generation and scripted customization
- straightforward integration with Atlantis `.deb` packages through a local feed
- easy to keep device packages optional and separate

Disadvantages:

- still requires later work for version pinning and CI hardening
- host environment requirements must be documented clearly

### Option C: image-builder frameworks first (`live-build`, `debos`, or similar)

Advantages:

- can provide higher-level image assembly workflows
- may become useful later for installer or release artifact generation

Disadvantages:

- more abstraction than Atlantis needs for the first rootfs
- hides the first boot path behind extra framework choices too early
- increases cognitive load before the rootfs/package boundaries are stable

## Decision

Choose Option B.

Atlantis standardizes Sprint 1 rootfs generation on:

- `mmdebstrap` for Debian rootfs creation
- version-controlled package lists under `build/mmdebstrap/packages/`
- Atlantis package integration through a generated local APT feed
- device packages added explicitly, not implicitly

## Consequences

Positive:

- Atlantis now has a concrete rootfs build path that can be reviewed, scripted, and improved
- generic userspace remains separate from device-specific enablement
- the same rootfs approach can feed QEMU, nested desktop testing, and later hardware images

Tradeoffs:

- reproducibility is only partial until package versions and mirrors are pinned more tightly
- a rootfs alone does not solve the Pixel 8 boot artifact problem
- later installer/image tooling may still need a higher-level assembly layer

## Long-Term Impact

- keeps Atlantis aligned with Debian-native composition instead of custom image hacks
- makes Atlantis-owned packages the stable integration layer rather than one-off filesystem edits
- preserves a clean path for additional devices because rootfs composition stays generic

## Follow-Up

- run the scripted rootfs build in a controlled Debian builder
- add version pinning and artifact checksum capture
- connect the rootfs output to installer/image assembly work for Sprint 2
