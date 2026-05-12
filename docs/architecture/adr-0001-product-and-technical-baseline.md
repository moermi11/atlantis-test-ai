# ADR-0001: Product and Technical Baseline

- Status: accepted
- Date: 2026-04-21

## Context

Atlantis needs an explicit product and technical baseline before implementation expands. Without this, early bring-up work could drift toward an Android-derived architecture, an enthusiast-only distro, or a device-specific prototype that cannot scale.

## Decision

Atlantis will be developed as a Debian-based mobile operating system with these baseline constraints:

- Debian stable is the base distribution
- package management is centered on `apt` and `dpkg`
- the display stack is Wayland
- Atlantis will prefer upstream components and package integration over rewriting entire subsystems
- Atlantis is aimed at mainstream smartphone users, not only Linux enthusiasts
- shell, branding, device, installer, and core OS concerns must remain separate

## Consequences

Positive:

- aligns tooling, packaging, and lifecycle assumptions with Debian norms
- narrows early architectural choices
- creates a stable reference point for future ADRs

Tradeoffs:

- some mobile enablement work may require more integration effort than Android-based shortcuts
- Debian-stable cadence may require selective packaging work for mobile components

## Follow-Up

- define device strategy separately
- choose an initial build/bootstrap path
- keep package naming and repository structure consistent with this baseline
