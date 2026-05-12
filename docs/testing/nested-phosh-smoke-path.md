# Nested Desktop Phosh Smoke Path

## Purpose

This document defines the Sprint 1 smoke path for validating the initial Atlantis shell integration in a nested desktop session.

This path is for shell/session packaging checks only. It does not validate phone hardware.

## Status

- documentation: `in progress`
- package integration path: `in progress`
- recorded smoke result: `unverified`

## Host Prerequisites

Run this path on a Debian-based desktop or laptop host with:

- a working Wayland desktop session
- `phosh`
- `phoc`
- `dbus-user-session`
- `gnome-session-bin`
- `xwayland`
- Atlantis package `.deb` files built from `packages/`

Useful additional tools:

- `weston-info` or similar Wayland inspection tools
- terminal log capture through `script` or shell redirection

## Package and Install Assumptions

This smoke path assumes:

- `atlantis-shell` depends on upstream Phosh
- `atlantis-branding` is installable even if branding assets remain minimal
- Atlantis packages are installed into a disposable or development-oriented Debian environment

Sprint 1 limitation:

- this document defines the nested session path, but does not claim Atlantis has already been smoke-tested successfully in a nested session

## Generic Boundary

The nested desktop path must stay generic:

- do not install `atlantis-device-google-shiba` for this test
- do not interpret desktop session success as evidence of phone boot success
- do not use this path to claim touch, modem, suspend, battery, or other phone-specific behavior

## Example Validation Flow

### 1. Build Atlantis packages

```sh
cd packages/atlantis-base && dpkg-buildpackage -us -uc -b
cd ../atlantis-shell && dpkg-buildpackage -us -uc -b
cd ../atlantis-branding && dpkg-buildpackage -us -uc -b
cd ../..
```

### 2. Install the package set into a Debian development environment

Documentation-level example:

```sh
sudo apt-get install ./packages/atlantis-branding_*.deb ./packages/atlantis-shell_*.deb ./packages/atlantis-base_*.deb
```

Alternative local-feed-oriented example:

```sh
sh ./build/mmdebstrap/build-package-feed.sh
sudo apt-get update
sudo apt-get install atlantis-base atlantis-branding atlantis-shell
```

The exact installation method may vary by developer environment. The important point is that the test uses Atlantis packages, not manual package lists copied by hand.

### 3. Launch a nested Phosh session

Realistic documentation-level template:

```sh
dbus-run-session -- phosh --nested
```

If the upstream package layout on the host does not expose `phosh --nested` directly, an equivalent upstream-supported nested launch path may be used instead. Record the exact command that was actually used.

## Smoke Checklist

Treat the path as `smoke-tested` only if evidence shows:

- Atlantis packages installed successfully in the test environment
- the nested session launched with upstream Phosh rather than a manually assembled substitute stack
- a visible Phosh shell session appeared in the nested environment
- basic keyboard and pointer interaction worked well enough to navigate the shell
- the shell did not fail immediately due to missing Atlantis package dependencies
- any failure point was captured precisely if the session stopped or crashed

Suggested interaction checks:

- shell window appears
- top bar or shell chrome appears
- launcher or overview can be opened
- at least one basic interaction works with keyboard or pointer input
- logs identify the failing component if the session does not stay up

## What This Path Can Prove

- `atlantis-shell` installs the intended upstream shell stack
- Atlantis shell packaging is coherent enough for a development desktop smoke test
- obvious session-startup regressions can be found before hardware flashing
- Atlantis branding/package handoff can be checked at a basic level

## What This Path Cannot Prove

- phone boot chain correctness
- ARM64-specific runtime behavior
- display panel behavior on a phone
- touch tuning, sensors, charging, suspend, audio routing, modem, or camera behavior
- whether Pixel 8 will boot the Atlantis userspace

Nested desktop testing does not validate phone hardware.

## Evidence Checklist

Record at least:

- date tested
- tester
- host distribution and desktop session
- Atlantis package build identifier or git revision
- package installation method used
- exact nested session launch command
- whether the result stayed `unverified`, reached `smoke-tested`, or failed as `broken`
- terminal log or session transcript path
- short summary of whether the shell appeared and which basic interactions succeeded
