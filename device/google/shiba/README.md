# device/google/shiba

This directory owns Google Pixel 8 (`shiba`) specific enablement only.

Expected contents over time:

- bring-up notes and boot procedures
- kernel configuration fragments
- hardware quirks
- firmware acquisition and handling scripts
- audio, display, input, and modem notes
- validation evidence for this device

Current state in Sprint 1:

- target device selected
- first device-oriented compose staging path added for Sprint 2 preparation
- no hardware capability is claimed as working
- all runtime capabilities remain `unverified` until backed by direct evidence

See `docs/device/google/shiba/boot-path.md` for the Sprint 1 boot-path definition.

Current repo-owned entry point:

- `sh ./device/google/shiba/compose.sh`
- `sh ./device/google/shiba/stage-boot-artifacts.sh`
- `sh ./installer/shiba/prepare.sh`
- `sh ./installer/shiba/collect-evidence.sh`
- `sh ./installer/shiba/review-decisions.sh`
- `sh ./installer/shiba/generate-command-plan.sh`
- `sh ./installer/shiba/check-readiness.sh`
- `sh ./installer/shiba/generate-session-bundle.sh`
- `sh ./installer/shiba/execute-session.sh`

The compose path stages references to the generic rootfs artifact and package feed artifact for `shiba`. The boot-artifact path runs after compose and stages explicit kernel/initramfs inputs plus reviewable manifests under `out/boot/shiba-development-bookworm-arm64/`. The installer-preparation path runs after boot-artifact staging and writes a reviewable flashing handoff under `out/installer/shiba-development-bookworm-arm64/`. The structured flashing-decision files live under `installer/shiba/decisions/`. The read-only evidence path then captures reviewable host or device observations under `out/evidence/shiba-development-bookworm-arm64/`. The decision-review path turns those suggestions into explicit approval manifests under `out/decision-review/shiba-development-bookworm-arm64/`. The guarded command-plan path consumes the live reviewed decisions plus the installer-preparation output to write a blocked or reviewable command-plan bundle under `out/command-plan/shiba-development-bookworm-arm64/`. The readiness path then classifies the repo state under `out/readiness/shiba-development-bookworm-arm64/`, the session-bundle path packages the operator-facing review bundle under `out/session-bundle/shiba-development-bookworm-arm64/`, and the execution-harness path defaults to dry-run while recording a guarded flashing-session ledger under `out/execution/shiba-development-bookworm-arm64/`.

None of these stages claim a bootable Pixel 8 result. The execution harness is the first repo-owned path that can attempt destructive `fastboot` steps, but only after session-ready inputs, explicit acknowledgement, and auditable logging.

The generic package build default remains device-agnostic. `atlantis-device-google-shiba` stays explicit and optional in the package build path.

Generic QEMU and nested desktop validation paths live under `docs/testing/` and must not be treated as device evidence for `shiba`.
