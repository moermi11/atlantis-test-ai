# ADR-0003: Build and Packaging Approach

- Status: accepted
- Date: 2026-04-21

## Context

Atlantis needs a first build/bootstrap strategy that can produce Debian-based images for mobile bring-up without entangling generic OS layers with device-specific boot hacks. The strategy also needs to be understandable by future maintainers and suitable for CI.

Two credible implementation paths were considered for Pixel 8 bring-up:

### Path A: Mainline-first bring-up

Description:

- bootstrap a Debian rootfs
- target upstream or near-upstream kernel support first
- avoid carrying significant device-specific downstream kernel state early

Advantages:

- strongest long-term portability story
- cleaner alignment with upstream Linux direction

Disadvantages:

- highest near-term boot risk on a modern phone platform
- likely slower time-to-first-boot
- may block practical validation while upstream gaps remain

### Path B: Device-kernel-first bring-up with strict isolation

Description:

- bootstrap a Debian rootfs using `mmdebstrap`
- package Atlantis-owned components as Debian packages
- keep Pixel 8 boot assets, kernel choices, quirks, and firmware procedures inside a dedicated device package and `device/google/shiba/`
- use installer tooling to assemble or flash development artifacts without turning the product into an Android-derived codebase

Advantages:

- more realistic path to first boot on available hardware
- preserves clean separation between generic Atlantis layers and device-specific enablement
- easier to stage in CI because rootfs, packages, and device artifacts can be validated separately

Disadvantages:

- requires careful discipline to prevent downstream device specifics from leaking upward
- firmware provenance and redistribution constraints must be managed explicitly

## Decision

Choose Path B for initial bring-up.

Implementation baseline:

- use `mmdebstrap` for reproducible Debian root filesystem generation
- build Atlantis-owned Debian packages under `packages/`
- compose images through `manifest/` definitions with pinned inputs
- keep Pixel 8-specific kernel, boot, and firmware handling in a device package and device tree
- treat firmware acquisition as a documented workflow, not an implicit repository payload

## Consequences

Positive:

- balances first-boot realism with maintainable architecture
- supports incremental progress: package builds, rootfs builds, image assembly, installer flow, then device boot
- keeps future second-device bring-up plausible

Tradeoffs:

- does not guarantee quick support for any specific hardware capability
- still requires later review of how and when to reduce downstream device deltas

## Follow-Up

- implement the `mmdebstrap` bootstrap path in Sprint 1
- define local package repository generation and pinned inputs
- design installer handoff for development flashing
- document firmware provenance and user-side acquisition boundaries before shipping artifacts
