# Atlantis

Atlantis is a Debian-based mobile operating system aimed at mainstream smartphone users.

This repository is the monorepo for Atlantis foundations, packaging, shell work, device enablement, installer tooling, CI, and long-term product documentation. Sprint 1 turns the project from structure into a real boot path definition: a manifest-driven `mmdebstrap` rootfs path, a layered testing strategy, Phosh as the initial shell boundary, and a documented Pixel 8 boot path for the first genuine boot attempt. The current repo state now also includes a device-oriented `shiba` compose staging path, a minimal boot-artifact staging boundary, a guarded installer-preparation boundary, a read-only evidence boundary, a guarded decision-review boundary, a blocked command-plan boundary, a guarded readiness boundary, an operator-session bundle boundary, and a guarded execution-harness boundary that together assemble existing inputs for Sprint 2 review and dry-run session rendering without claiming a bootable or safe-to-flash Pixel 8 result.

Current development focus:

- Debian-based, reproducible OS composition
- explicit package build artifacts under `out/packages/` feeding a generated local package repository under `out/repo/`
- minimal manifest/profile-driven rootfs composition for `bookworm` + `arm64`
- first device-oriented `shiba` profile, staged compose contract, staged boot-artifact contract, guarded installer-preparation contract, read-only evidence contract, guarded decision-review contract, blocked command-plan contract, guarded readiness contract, operator-session bundle contract, and guarded execution-harness contract on top of the generic rootfs and package feed artifacts
- modular mobile UX stack on Wayland
- first bring-up path for Google Pixel 8 (`shiba`)
- strict separation between generic Atlantis components and device-specific enablement
- truthful status tracking with no unsupported hardware claims

See [docs/foundation-spec.md](docs/foundation-spec.md) for the product and architecture baseline, [docs/roadmap.md](docs/roadmap.md) for the staged execution plan, and [docs/testing.md](docs/testing.md) for the layered validation policy plus Sprint 1 smoke-path documents.
