# ADR-0005: Multi-Target Testing Strategy

- Status: accepted
- Date: 2026-04-21

## Context

Atlantis cannot rely on a single test environment.

If testing happens only on Pixel 8 hardware, iteration becomes slow and risky. If testing happens only in virtualized environments, the project can appear to progress while the real phone boot path remains untouched.

Sprint 1 needs a testing strategy that:

- speeds up iteration on generic issues
- allows UI/session work before hardware bring-up succeeds
- still reserves truth for real device evidence

The main alternatives were:

### Option A: hardware-first only

Advantages:

- every result is directly tied to the real target device

Disadvantages:

- slowest feedback loop
- highest flashing risk during early packaging mistakes
- poor place to debug generic rootfs or shell dependency issues

### Option B: virtualization-first only

Advantages:

- fast iteration
- easy automation

Disadvantages:

- can create false confidence about device readiness
- cannot validate the Pixel 8 boot chain or hardware capabilities

### Option C: layered validation across QEMU ARM64, nested Phosh, and Pixel 8

Advantages:

- QEMU catches generic ARM64 image and service regressions quickly
- nested Phosh exercises UI/session packaging without hardware flashing
- Pixel 8 remains the only source of truth for actual device bring-up

Disadvantages:

- requires discipline to keep claims scoped to the right layer
- expands the documentation and test-matrix surface area

## Decision

Choose Option C.

Atlantis requires three validation targets:

- QEMU ARM64 (`virt`) for generic ARM64 rootfs and early userspace checks
- nested desktop Phosh for shell/session smoke tests
- real Pixel 8 hardware for all device boot and hardware claims

## Consequences

Positive:

- faster iteration without losing honesty about hardware status
- cleaner separation between generic build failures and device-specific bring-up failures
- better foundation for later CI because each layer has a distinct responsibility

Tradeoffs:

- matrices and docs must stay explicit about what each environment can and cannot prove
- success in QEMU or nested desktop testing must not be reported as Pixel 8 success

## Long-Term Impact

- gives Atlantis a repeatable bring-up pattern for future devices
- reduces pressure to debug every problem on real hardware first
- keeps hardware evidence as the standard for `boots`, `smoke-tested`, and `verified` claims

## Follow-Up

- add concrete QEMU boot commands once the first generic bootable artifact exists
- define the nested Phosh smoke-test checklist
- record the first hardware evidence with artifact identifiers and dates
