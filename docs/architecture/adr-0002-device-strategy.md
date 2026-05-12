# ADR-0002: Device Strategy

- Status: accepted
- Date: 2026-04-21

## Context

Atlantis needs a real target device for bring-up. A first device is necessary to drive kernel, installer, and validation work, but allowing that device to define the entire product architecture would create long-term portability debt.

## Decision

Google Pixel 8 (`shiba`) is the first development and bring-up device for Atlantis.

Constraints attached to this decision:

- Pixel 8 availability justifies the choice; it does not justify Pixel-only architecture
- device-specific code must stay under `device/google/shiba/` and dedicated device packages
- generic shell, installer abstractions, and core OS composition must not embed `shiba` assumptions
- a second modern validation device will be selected after the foundation and first boot path stabilize

## Consequences

Positive:

- provides a concrete target for boot and installer work
- keeps early efforts tied to real hardware constraints

Tradeoffs:

- Pixel 8 bring-up may force temporary use of device-specific kernel and firmware handling
- some engineering work will be gated by hardware access and legal clarity around firmware acquisition

## Follow-Up

- maintain per-device validation evidence
- define criteria for the second target device before device-specific shortcuts spread
- review portability explicitly at the end of early bring-up sprints
