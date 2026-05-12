# atlantis-base

Atlantis metapackage skeleton for core operating system defaults.

Sprint 1 responsibility:

- provide the generic Atlantis package entry point for rootfs composition
- depend on Atlantis-owned shell and branding packages only
- avoid device-specific dependencies and hardware quirks

This package is the generic package that `mmdebstrap` should include for all Atlantis rootfs builds.
