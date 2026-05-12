# packages

This directory contains Atlantis-owned Debian package sources, metapackages, overrides, and packaging metadata.

Artifact boundary:

- package source directories live here under `packages/`
- built `.deb` artifacts are written intentionally under `out/packages/`
- the generated local package feed is written separately under `out/repo/`

The `packages/` tree is source input, not the canonical built artifact directory.

Packaging rules:

- keep generic Atlantis packages separate from device packages
- prefer small native Debian packages over ad-hoc image-only customization
- document external dependencies and provenance
- keep package names stable and product-oriented

Current Sprint 1 package roles:

- `atlantis-base`: generic Atlantis metapackage for system-level defaults
- `atlantis-shell`: initial shell integration package, using upstream Phosh
- `atlantis-branding`: branding and theme boundary
- `atlantis-device-google-shiba`: Pixel 8-specific enablement boundary

Current Sprint 1 build path:

- `sh ./build/mmdebstrap/build-packages.sh` builds the generic package set
- `sh ./build/mmdebstrap/build-packages.sh --include-device` adds the optional `shiba` device package
- built `.deb` outputs land under `out/packages/development-bookworm-arm64/`
- each package build run refreshes that artifact directory intentionally before writing new `.deb` outputs
