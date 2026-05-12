# manifest

This directory owns build composition and reproducibility metadata.

Current Sprint 1 contents:

- `profiles/`: shell-friendly build profiles that define generic build inputs and explicit device overlays

Profile rules:

- generic inputs belong here: suite, architecture, package artifact output path, package feed path, rootfs output path, package-list inputs, and generic Atlantis package set
- device-specific inputs must stay explicit and separate: device IDs, device package boundaries, staged compose output paths, boot-artifact staging paths, installer-preparation paths, kernel choices, boot image paths, and flashing parameters
- the generic Sprint 1 profile must stay device-agnostic

Current profile:

- `profiles/development-bookworm-arm64.env`: generic development profile for `bookworm` + `arm64`
- `profiles/shiba-development-bookworm-arm64.env`: `shiba` device-oriented profile that layers on the generic development profile

Current profile split:

- generic build inputs: package artifact, package feed, and rootfs composition inputs shared across targets
- device-specific userspace inputs: device ID, optional device package boundary, staged compose output path
- device-specific boot-artifact staging inputs: explicit kernel artifact path, explicit initramfs artifact path, and staged boot-artifact output directory
- device-specific installer-preparation inputs: staged installer-preparation output directory for host-side flashing review
- device-specific flashing-decision inputs: structured partition, AVB/vbmeta, slot, and provenance decision files
- device-specific command-plan inputs: staged command-plan output directory for guarded flashing review

Current `shiba` contract:

- generic rootfs artifact: `out/rootfs/development-bookworm-arm64/`
- generated package feed artifact: `out/repo/development-bookworm-arm64/`
- `shiba` compose stage: `out/device/shiba-development-bookworm-arm64/`
- `shiba` boot-artifact stage: `out/boot/shiba-development-bookworm-arm64/`
- `shiba` installer-preparation stage: `out/installer/shiba-development-bookworm-arm64/`
- `shiba` flashing-decision directory: `installer/shiba/decisions/`
- `shiba` command-plan stage: `out/command-plan/shiba-development-bookworm-arm64/`

Planned contents include:

- source pinning for Atlantis-owned packages and upstream repositories
- image/profile definitions for development and release variants
- package lists and composition manifests
- reproducibility inputs such as version locks, checksums, and release manifests

No device-specific quirks should live here unless they are referenced through explicit device profiles, and explicit boot-artifact, installer-preparation, or command-plan fields must not be mistaken for implemented flashing support, resolved flashing decisions, or a finished boot chain.
