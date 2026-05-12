# Atlantis Feature Matrix

## State Vocabulary

- `planned`
- `in progress`
- `builds`
- `boots`
- `smoke-tested`
- `verified`
- `broken`
- `unverified`

## Platform Features

| Area | Feature | State | Notes |
| --- | --- | --- | --- |
| build | manifest structure | `in progress` | Sprint 1 generic profile defines suite, architecture, package-set inputs, and output paths; a first `shiba` device profile now layers on those generic inputs without adding fake boot artifacts. |
| build | package build artifacts | `in progress` | Package builds now target an explicit artifact directory under `out/packages/` instead of relying on manually present `.deb` files under `packages/`. |
| build | rootfs bootstrap | `in progress` | `mmdebstrap` rootfs script now consumes the active manifest profile, but no successful artifact is claimed yet. |
| build | package feed generation | `in progress` | Local package feed script now consumes the explicit built package artifact directory and writes a separate feed under the active profile output path; no successful feed build is recorded yet. |
| build | `shiba` compose staging | `in progress` | A device-oriented compose script now stages explicit references to the generic rootfs and package feed artifacts, but it is not a flashing flow and does not imply Pixel 8 `boots`. |
| build | `shiba` boot-artifact staging | `in progress` | A follow-on shell stage now requires explicit kernel and initramfs artifact inputs, records the compose handoff it consumed, and stages reviewable boot-input metadata without generating partition images or invoking fastboot. |
| installer | `shiba` installer preparation | `in progress` | A guarded shell stage now checks host-side preparation prerequisites, consumes the staged boot-artifact directory, and writes a reviewable flashing handoff without invoking fastboot or flashing partitions. |
| installer | `shiba` flashing-decision layer | `in progress` | Structured shell-friendly decision files now track partition targets, AVB/vbmeta handling, slot strategy, and firmware or boot-input provenance with truthful unresolved placeholders. |
| installer | `shiba` evidence capture | `in progress` | A read-only shell stage now checks host tool availability, captures safe adb or fastboot probes when possible, and writes an evidence bundle plus suggestion files without modifying device-side state. |
| installer | `shiba` decision review/apply | `in progress` | A guarded shell stage now turns evidence suggestions into explicit approval manifests, applies them only through a separate step, and records reviewed decision status for future command-plan checks. |
| installer | `shiba` command-plan generation | `in progress` | A guarded shell stage now consumes the staged installer-preparation directory plus the structured decision files and emits a blocked review bundle until required flashing decisions are resolved; it does not invoke fastboot or adb. |
| installer | `shiba` readiness check | `in progress` | A guarded shell stage now classifies the current repo state as blocked, review-ready, or session-ready from the command-plan output plus live reviewed decisions, without invoking fastboot or adb. |
| installer | `shiba` operator-session bundle | `in progress` | A non-destructive shell stage now packages the active profile, live inputs, blockers, non-claims, and operator checklist into a reviewable session bundle without implying flashing is implemented. |
| installer | `shiba` execution harness | `in progress` | A guarded shell stage now defaults to dry-run, consumes the readiness result plus session bundle and reviewed decisions, and writes an auditable execution ledger before any destructive `fastboot` step can run. |
| installer | host-side flashing flow | `planned` | Must include rollback-aware guardrails before routine device use. |
| shell | initial shell integration | `in progress` | `atlantis-shell` is reserved as the Phosh integration boundary for Sprint 1. |
| shell | launcher shell | `planned` | Atlantis-specific shell work is intentionally deferred beyond Sprint 1. |
| shell | lock screen | `planned` | Architecture reserved only. |
| shell | quick settings | `planned` | Architecture reserved only. |
| shell | notifications | `planned` | Architecture reserved only. |
| shell | settings app | `planned` | Stub package exists; UI work not started. |
| shell | app switching | `planned` | No implementation yet. |
| input | on-screen keyboard integration | `planned` | Not started. |
| updates | update flow | `planned` | Constraints acknowledged early; implementation deferred. |
| device | Pixel 8 bring-up package | `in progress` | Initial Debian package skeleton created in Sprint 0. |
| QA | QEMU ARM64 (`virt`) smoke path | `in progress` | Concrete Sprint 1 execution document exists; no recorded boot result is claimed yet. |
| QA | nested desktop Phosh smoke path | `in progress` | Concrete Sprint 1 execution document exists; no recorded session smoke result is claimed yet. |
| QA | Pixel 8 hardware validation path | `planned` | Real hardware evidence has not been captured yet. |
| branding | theme/token packaging | `in progress` | Branding package skeleton created; full assets deferred. |
| QA | validation language and evidence policy | `verified` | Documentation baseline exists in Sprint 0 and was reviewed in-repo. |

## Reading This Matrix

- `in progress` means scaffolding or active engineering exists
- `builds` in documentation or packaging context does not imply hardware verification
- package source directories, built package artifacts, generated feeds, and rootfs outputs are different artifact boundaries
- generic rootfs and package feed artifacts are not the same thing as future device boot artifacts
- a staged `shiba` compose output is a userspace handoff boundary, not a boot result
- a staged `shiba` boot-artifact directory is a boot-input handoff boundary, not a flash bundle or a boot result
- a staged `shiba` evidence bundle is a read-only review boundary, not a flashing run or a boot result
- a staged `shiba` installer-preparation directory is a flashing review boundary, not a fastboot run or a flashing result
- structured `shiba` flashing-decision files are a decision boundary, not proof that partition, AVB, or slot questions are solved
- a staged `shiba` decision-review directory is a review/apply safety boundary, not proof that flashing is safe
- a generated `shiba` command-plan / execution-bundle directory is a review boundary, not an execution boundary
- a generated `shiba` readiness-check directory is a safety boundary, not proof that flashing is safe or implemented
- a generated `shiba` operator-session bundle is a preparation boundary, not a flashing session
- a generated `shiba` execution-harness directory is an auditable session boundary; dry-run is not execution and completion is not proof of boot success
- device features remain `unverified` until the device matrix records evidence
