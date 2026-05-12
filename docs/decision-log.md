# Atlantis Decision Log

| Date | Decision | Reference | Notes |
| --- | --- | --- | --- |
| 2026-04-21 | Adopt Debian stable as the Atlantis base distribution. | ADR-0001 | Aligns package management, lifecycle expectations, and tooling choices. |
| 2026-04-21 | Use Google Pixel 8 (`shiba`) as the first bring-up device without making it the permanent architectural center. | ADR-0002 | Availability-driven, with explicit portability constraints. |
| 2026-04-21 | Prefer `mmdebstrap`-based rootfs composition plus device-isolated packaging for first build/bootstrap work. | ADR-0003 | Chosen for clarity, reproducibility, and Debian-native workflows. |
| 2026-04-21 | Standardize Sprint 1 rootfs generation on a scriptable `mmdebstrap` flow with Atlantis packages supplied through a local package feed. | ADR-0004 | Turns the bootstrap choice into an executable build path. |
| 2026-04-21 | Require a layered testing strategy across QEMU ARM64, nested desktop Phosh, and real Pixel 8 hardware. | ADR-0005 | Separates fast iteration from true hardware validation. |
| 2026-04-21 | Use upstream Phosh as the initial Atlantis shell while keeping Atlantis-owned integration boundaries replaceable. | ADR-0006 | Avoids early UI rewrites while preserving a path to a future Atlantis shell. |
