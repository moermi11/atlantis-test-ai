# Atlantis `mmdebstrap` Rootfs Build

## Purpose

This document defines the first reproducible Atlantis root filesystem build path.

Sprint 1 goal:

- create a minimal Debian rootfs with `mmdebstrap`
- install Atlantis-owned packages from a local Atlantis package feed
- make generic build inputs explicit through a reviewable profile
- keep device-specific logic out of the generic rootfs

This document does not claim the rootfs already `builds` in CI or `boots` on hardware. It defines the path that will be executed and validated next.

## Build Inputs

Required host tools on a Debian build host:

- `mmdebstrap`
- `dpkg-dev`
- `debhelper`
- `devscripts`
- `build-essential`

Recommended additional tools for later validation:

- `qemu-system-aarch64`
- `qemu-user-static`
- `fastboot`
- `adb`

Manifest/profile input:

- `manifest/profiles/development-bookworm-arm64.env`
- `manifest/profiles/shiba-development-bookworm-arm64.env`

This Sprint 1 profile is the source of truth for:

- Debian suite and architecture
- package build artifact output path
- rootfs output path
- package feed output path
- generic package-list inputs
- generic Atlantis package set

The generic profile keeps future device-specific inputs explicit by leaving them unset in the generic case.

The first `shiba` profile layers on that generic baseline and adds only:

- the `shiba` device identifier
- the optional `atlantis-device-google-shiba` userspace package boundary
- the staged `shiba` compose output path
- explicit kernel and initramfs boot-artifact input fields
- a staged `shiba` boot-artifact output path

## Atlantis Package Boundaries

The generic Sprint 1 rootfs installs these Atlantis packages:

- `atlantis-base`
- `atlantis-branding`
- `atlantis-shell`

The device package is intentionally separate:

- `atlantis-device-google-shiba`

`atlantis-device-google-shiba` must not be part of the generic VM or desktop rootfs by default. It belongs in the hardware-specific boot path only.

## Package Selection

Package lists live under `build/mmdebstrap/packages/`.

Selected Debian packages for the initial generic rootfs:

| Package | Reason |
| --- | --- |
| `systemd-sysv` | system manager and init |
| `udev` | device node management |
| `dbus` | required session/system bus plumbing |
| `network-manager` | baseline network management |
| `sudo` | controlled administrative access during bring-up |
| `ca-certificates` | TLS trust store for package/network operations |
| `phosh` | initial upstream mobile shell stack |

Atlantis-owned package integration:

- `atlantis-base` pulls in the generic Atlantis package boundary
- `atlantis-shell` currently pulls in upstream Phosh
- `atlantis-branding` reserves Atlantis branding ownership without mixing in device logic

## Exact Build Commands

### 1. Build Atlantis packages

Run this command from the repository root on a Debian build host:

```sh
sh ./build/mmdebstrap/build-packages.sh
```

Result:

- generic Atlantis `.deb` artifacts are written under `out/packages/development-bookworm-arm64/`

Optional device package build:

```sh
sh ./build/mmdebstrap/build-packages.sh --include-device
```

This keeps `atlantis-device-google-shiba` explicit and outside the generic default package build path.

### 2. Build the local Atlantis package feed

```sh
sh ./build/mmdebstrap/build-package-feed.sh
```

Result:

- `out/repo/development-bookworm-arm64/Packages`
- `out/repo/development-bookworm-arm64/Packages.gz`
- copied Atlantis `.deb` files from `out/packages/development-bookworm-arm64/` into `out/repo/development-bookworm-arm64/`

### 3. Build the generic Atlantis rootfs

```sh
sh ./build/mmdebstrap/build-rootfs.sh
```

Default output:

- `out/rootfs/development-bookworm-arm64/`

### 4. Stage a `shiba`-oriented compose output

```sh
sh ./device/google/shiba/compose.sh
```

Default staged output:

- `out/device/shiba-development-bookworm-arm64/`

What this stage does:

- validates that the active `shiba` profile exists
- validates that the generic rootfs artifact and local package feed artifact already exist
- records the `atlantis-device-google-shiba` package boundary explicitly
- leaves kernel and initramfs inputs as placeholders until real artifact paths exist

What this stage does not do:

- build a kernel
- build an initramfs
- flash a device
- claim the result `boots`

### 5. Stage `shiba` boot-artifact inputs

```sh
sh ./device/google/shiba/stage-boot-artifacts.sh
```

Default staged output:

- `out/boot/shiba-development-bookworm-arm64/`

What this stage does:

- validates that the active `shiba` profile exists
- validates that the `shiba` compose stage already exists
- requires explicit kernel and initramfs artifact paths from the active profile or environment
- stages a reviewable boot-artifact directory with manifests and unresolved placeholders

What this stage does not do:

- invoke fastboot
- generate partition images
- define partition targets
- define AVB or `vbmeta` handling
- define slot strategy
- claim the result `boots`

## How the Scripts Work

### `build/mmdebstrap/build-package-feed.sh`

- loads the active Atlantis profile
- consumes built Atlantis `.deb` artifacts from the profile-defined package artifact directory
- creates a flat local APT repository at the profile-defined feed path
- generates `Packages` and `Packages.gz` with `dpkg-scanpackages`

### `build/mmdebstrap/build-packages.sh`

- loads the active Atlantis profile
- validates Debian package build tools and expected source package directories
- builds generic Atlantis packages in a stable order
- writes `.deb` artifacts into the profile-defined package artifact directory
- keeps `atlantis-device-google-shiba` optional instead of part of the generic default path

### `build/mmdebstrap/build-rootfs.sh`

- loads the active Atlantis profile
- builds the profile-defined rootfs
- loads package lists from the profile-defined package-set inputs
- appends Atlantis packages to the `mmdebstrap` `--include` set
- adds the profile-defined local Atlantis package feed when present
- emits a directory rootfs at the profile-defined output path
- cleans APT caches via a customize hook

## Artifact Contract

### Package source directories

Current Sprint 1 source locations:

- `packages/atlantis-base/`
- `packages/atlantis-shell/`
- `packages/atlantis-branding/`
- `packages/atlantis-device-google-shiba/`

What they contain:

- Debian source package metadata and package-owned files

What they do not contain:

- the canonical built artifact output for the package pipeline

State:

- `in progress`

### Built package artifact directory

Current Sprint 1 output:

- `.deb` artifacts under `out/packages/development-bookworm-arm64/`

What it contains:

- intentionally built Atlantis package artifacts from `build/mmdebstrap/build-packages.sh`
- artifacts refreshed intentionally on each package build run

What it does not contain:

- package source trees
- generated `Packages` indexes
- rootfs contents

State:

- `in progress`

### Generic rootfs artifact

Current Sprint 1 output:

- a directory-format generic rootfs at `out/rootfs/development-bookworm-arm64/`

What it contains:

- Debian base userspace from the selected suite and architecture
- generic Sprint 1 package lists
- generic Atlantis package set from the local Atlantis feed when present

What it does not contain:

- device kernel images
- device bootloader artifacts
- flashing metadata
- partition images or installer bundles

State:

- `in progress`

### Package feed artifact

Current Sprint 1 output:

- a flat local APT repository at `out/repo/development-bookworm-arm64/`

What it contains:

- Atlantis-built `.deb` packages copied from `out/packages/development-bookworm-arm64/`
- `Packages` and `Packages.gz` index files

State:

- `in progress`

### `atlantis-device-google-shiba` package boundary

Current state:

- package source exists under `packages/atlantis-device-google-shiba/`
- package feed presence is optional for the `shiba` compose stage and recorded explicitly when present

What it is for:

- `shiba`-specific userspace integration
- a package boundary that remains outside the generic Atlantis package set

What it is not:

- a kernel artifact
- an initramfs artifact
- proof that Pixel 8 `boots`

State:

- `in progress`

### Future kernel artifact

Current state:

- placeholder only

State:

- `planned`

### Future initramfs artifact

Current state:

- placeholder only

State:

- `planned`

### Staged `shiba` compose output

Current output:

- a staged directory at `out/device/shiba-development-bookworm-arm64/`

What it contains:

- references to the generic rootfs artifact and package feed artifact
- copied active profile metadata
- explicit status for the optional `atlantis-device-google-shiba` feed artifact
- placeholder state files for future kernel and initramfs inputs

What it does not contain:

- a flash script
- a partition map
- a kernel or initramfs unless future profile fields are populated
- any claim that Pixel 8 `boots`

State:

- `in progress`

### Staged `shiba` boot-artifact output

Current output:

- a staged directory at `out/boot/shiba-development-bookworm-arm64/`

What it contains:

- references to the staged `shiba` compose output
- references to the generic rootfs artifact and generated package feed artifact
- explicit references to the kernel and initramfs artifact inputs
- manifests describing the staging contract and unresolved boot-chain items

What it does not contain:

- generated partition images
- fastboot packaging
- resolved partition targets
- resolved AVB or `vbmeta` handling
- resolved slot strategy
- any claim that Pixel 8 `boots`

State:

- `in progress`

### Future device boot artifacts

Not produced by the Sprint 1 generic build path:

- device kernel and initramfs outputs
- boot or vendor boot images
- partition layout artifacts
- flashing manifests and host-side safety checks

These remain future installer and device enablement work. The generic rootfs build may become one input to that work, but it is not an installable device artifact by itself.

## What Is Still Missing Before Installer Work Can Begin

- a device profile that explicitly adds device-specific package and boot inputs
- a staged compose output that is backed by real kernel and initramfs planning inputs
- a staged boot-artifact output that is backed by real kernel and initramfs artifacts
- kernel and firmware provenance for the target device
- a defined partition and boot artifact set for the first hardware path
- host-side installer logic with safety checks
- evidence that the produced artifacts `builds` before any claim about device boot behavior

## Reproducibility Notes

Sprint 1 reproducibility constraints:

- same suite by default: `bookworm`
- same architecture by default: `arm64`
- explicit package lists in version-controlled files
- Atlantis packages enter through a generated local package feed instead of undocumented manual installs

Remaining work before Atlantis can claim reproducible image outputs:

- pin mirror snapshots or repository dates
- capture exact package versions in build manifests
- archive artifact checksums
- run the build path in CI or an equivalently controlled builder

## Non-Goals for Sprint 1

- final installer images
- OTA/update layout
- production package signing
- a final `shiba` partition layout
- claiming the resulting rootfs `boots` on real hardware
