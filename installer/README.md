# installer

This directory contains host-side installation and flashing tooling for Atlantis.

Scope:

- fastboot and recovery helper flows
- image packaging for installation artifacts
- guardrails around destructive device operations
- repeatable development install paths

Installer logic must stay separate from generic build composition and from device runtime packages.

Current contract with Sprint 1 build artifacts:

- input expected earlier in the generic pipeline: built Atlantis `.deb` artifacts under `out/packages/development-bookworm-arm64/`
- input expected later: generic rootfs artifact from `out/rootfs/development-bookworm-arm64/`
- input expected later: generic package feed artifact from `out/repo/development-bookworm-arm64/`
- input available now: staged `shiba` compose output from `out/device/shiba-development-bookworm-arm64/`
- input available now when explicit boot inputs exist: staged `shiba` boot-artifact directory from `out/boot/shiba-development-bookworm-arm64/`
- output available now for review only: staged `shiba` installer-preparation directory at `out/installer/shiba-development-bookworm-arm64/`
- input available now for review: structured `shiba` flashing-decision files under `installer/shiba/decisions/`
- output available now for review only: read-only `shiba` evidence bundle directory at `out/evidence/shiba-development-bookworm-arm64/`
- output available now for review only: staged `shiba` decision-review directory at `out/decision-review/shiba-development-bookworm-arm64/`
- input available now for applied review state: `installer/shiba/decisions/review-status.env`
- output available now for review only: generated `shiba` command-plan / execution-bundle directory at `out/command-plan/shiba-development-bookworm-arm64/`
- output available now for review only: generated `shiba` readiness-check directory at `out/readiness/shiba-development-bookworm-arm64/`
- output available now for review only: generated `shiba` operator-session bundle directory at `out/session-bundle/shiba-development-bookworm-arm64/`
- output available now for guarded review or execution logging: generated `shiba` execution-harness directory at `out/execution/shiba-development-bookworm-arm64/`
- not implemented here yet: device boot artifacts, partition images, rollback automation, or proof of successful boot

Current repo-owned entry point:

- `sh ./installer/shiba/prepare.sh`
- `sh ./installer/shiba/collect-evidence.sh`
- `sh ./installer/shiba/review-decisions.sh`
- `sh ./installer/shiba/generate-command-plan.sh`
- `sh ./installer/shiba/check-readiness.sh`
- `sh ./installer/shiba/generate-session-bundle.sh`
- `sh ./installer/shiba/execute-session.sh`

Boundary summary:

- the staged `shiba` compose output is a userspace handoff boundary only
- the staged `shiba` boot-artifact directory is a boot-input handoff boundary only
- the staged `shiba` installer-preparation directory is a host-side flashing review boundary only
- the structured `shiba` flashing-decision files are a reviewable decision boundary only
- the read-only `shiba` evidence bundle is a review boundary only
- the staged `shiba` decision-review directory is a review-and-apply safety boundary only
- the live `shiba` review-status file records what was explicitly reviewed and applied
- the generated `shiba` command-plan / execution-bundle directory is a review boundary only, not an execution boundary
- the generated `shiba` readiness-check directory is a safety boundary only
- the generated `shiba` operator-session bundle directory is a preparation boundary only
- the generated `shiba` execution-harness directory is an auditable session boundary only and defaults to dry-run
- a future boot-success evidence layer remains `planned`

The installer-preparation stage checks host-side prerequisites, consumes the staged `shiba` boot-artifact directory, and writes reviewable manifests plus a flashing handoff. The evidence stage then collects only read-only host and device observations and writes review companion files instead of overwriting the structured flashing-decision files. The decision-review stage turns those suggestions into explicit approval manifests and applies them only through a separate `apply` step, while recording reviewed status in a live review-status file. The command-plan stage then consumes the installer-preparation output together with the live structured flashing-decision files and the applied review-status file, and it stays blocked until required fields are both concrete and reviewed-applied. The readiness-check stage classifies the current repo state as blocked, review-ready, or session-ready without executing anything, and the operator-session bundle stage packages the exact current inputs, blockers, and checklist for a future manual session. The execution-harness stage then defaults to dry-run, renders the first guarded flashing step sequence when the reviewed inputs are sufficient, requires an explicit destructive-action acknowledgement before real `fastboot` commands can run, and records every rendered or attempted step in an auditable session ledger. None of these boundaries claim Pixel 8 `boots`.
