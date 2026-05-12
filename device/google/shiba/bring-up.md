# Pixel 8 (`shiba`) Bring-Up Plan

## Purpose

This document defines the first credible bring-up path for Google Pixel 8 as Atlantis' primary development device.

## Current Status

- device target selected
- device package skeleton created
- staged userspace and boot-artifact handoff paths are defined
- staged installer-preparation path is defined
- structured flashing-decision files are defined
- read-only evidence bundle path is defined
- reviewed decision-apply path is defined
- guarded command-plan path is defined
- guarded readiness-check path is defined
- operator-session bundle path is defined
- guarded execution-harness path is defined
- no boot attempt has been recorded yet
- all hardware capabilities remain `unverified`

## First Bring-Up Objective

Reach a repeatable development artifact path that can be used to attempt booting a Debian-based Atlantis image on Pixel 8 without mixing device-specific quirks into generic Atlantis packages.

## Chosen Bring-Up Shape

- generic Atlantis root filesystem built from Debian inputs using `mmdebstrap`
- Atlantis packages built into an explicit artifact directory and installed through a generated local package feed
- Pixel 8 specific boot and kernel handling isolated in `atlantis-device-google-shiba`
- firmware handled through documented acquisition and staging steps rather than implicit repository blobs
- flashing and assembly steps owned by `installer/`

## Non-Claims

This plan does not claim that any of the following currently work:

- boot
- display
- touch
- modem
- Wi-Fi
- audio
- charging

All remain `unverified` until recorded on hardware.

## Required Next Artifacts

- manifest definition for `mmdebstrap` rootfs bootstrap
- explicit package artifact directory and local package repository workflow
- documented boot-artifact staging interface between manifest, compose output, package outputs, and installer
- documented installer-preparation interface for host-side flashing review
- structured flashing-decision files for partition targets, AVB/vbmeta handling, slot strategy, and boot-input provenance
- a read-only evidence collection path that can inform those structured flashing-decision files truthfully
- a reviewed decision-approval path that can explicitly accept, reject, defer, or leave suggestions unresolved before live decision files change
- guarded command-plan generation that stays blocked until those flashing decisions are resolved truthfully
- a guarded readiness-check path that classifies the repo state without collapsing unresolved inputs into false readiness
- an operator-session bundle that records the exact reviewed inputs, blockers, and non-claims for a future manual hardware session
- a guarded execution harness that defaults to dry-run, requires explicit acknowledgement before destructive actions, and records the exact stop point for each attempted session
- firmware provenance notes and extraction policy
- first safe development flashing procedure

## Evidence to Capture in Sprint 1 and Sprint 2

When bring-up begins, capture:

- exact build identifier
- boot artifact inputs
- flashing command or scripted path
- device reaction and visible boot stage reached
- logs or serial output if available
- tester and date

## Risks Specific to `shiba`

- device-specific kernel requirements may slow time-to-first-boot
- firmware rights and provenance may constrain redistribution
- successful boot may still leave most user-facing capabilities `unverified`
