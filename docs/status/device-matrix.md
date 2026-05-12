# Atlantis Device Matrix

## State Vocabulary

- `planned`
- `in progress`
- `builds`
- `boots`
- `smoke-tested`
- `verified`
- `broken`
- `unverified`

## Devices

| Device | Role | Boot Path | Installer Path | Generic Portability Status | Notes |
| --- | --- | --- | --- | --- | --- |
| Google Pixel 8 (`shiba`) | primary bring-up target | `in progress` | `in progress` | `in progress` | Sprint 1 documents the boot path and now stages reviewable boot-artifact, installer-preparation, structured flashing-decision, read-only evidence, decision-review, blocked command-plan, readiness-check, operator-session, and guarded execution-harness boundaries, but no successful hardware boot is claimed. |
| Secondary device (TBD) | future validation target | `planned` | `planned` | `planned` | Must be a newer device. Selection deferred until foundation and first bring-up path are stable. |

## Pixel 8 Capability Status

| Capability | State | Evidence |
| --- | --- | --- |
| image build artifacts | `in progress` | Sprint 1 scripts now define explicit package artifact, package feed, rootfs, compose, boot-artifact staging, installer-preparation, structured flashing-decision, read-only evidence, decision-review, blocked command-plan, readiness-check, operator-session, and guarded execution-harness boundaries, but no recorded Pixel 8 boot result exists yet. |
| boot | `unverified` | No hardware boot evidence recorded. |
| display | `unverified` | No hardware evidence recorded. |
| touch | `unverified` | No hardware evidence recorded. |
| storage | `unverified` | No hardware evidence recorded. |
| encryption | `unverified` | No hardware evidence recorded. |
| Wi-Fi | `unverified` | No hardware evidence recorded. |
| Bluetooth | `unverified` | No hardware evidence recorded. |
| audio | `unverified` | No hardware evidence recorded. |
| suspend/resume | `unverified` | No hardware evidence recorded. |
| modem | `unverified` | No hardware evidence recorded. |
| SMS/data | `unverified` | No hardware evidence recorded. |
| camera | `unverified` | No hardware evidence recorded. |
| GPS | `unverified` | No hardware evidence recorded. |
| sensors | `unverified` | No hardware evidence recorded. |
| fingerprint | `unverified` | No hardware evidence recorded. |
| battery reporting | `unverified` | No hardware evidence recorded. |
| charging | `unverified` | No hardware evidence recorded. |
