# Atlantis Risk Register

## Rating Guide

- Likelihood: low, medium, high
- Impact: medium, high, critical

## Active Risks

| ID | Risk | Likelihood | Impact | Mitigation | Status |
| --- | --- | --- | --- | --- | --- |
| R-001 | Pixel 8 bring-up may require device-specific kernel or firmware handling that is slower than expected to package cleanly. | high | critical | Keep device code isolated, document provenance early, and treat user-side firmware acquisition as a first-class workflow if redistribution is unclear. | open |
| R-002 | The project could drift into a Pixel-only architecture during early bring-up. | medium | critical | Enforce device package boundaries, track portability explicitly, and require generic layers to remain device-agnostic. | open |
| R-003 | A shell stack decision made too early could create long-term maintenance burden. | medium | high | Delay overbuilding the shell, prototype with replaceable modules, and record ADRs before major UX framework commitments. | open |
| R-004 | Reproducibility could be weakened by ad-hoc firmware, local scripts, or unpinned inputs. | medium | critical | Use manifests, version pinning, checksums, and CI smoke builds; document every external acquisition path. | open |
| R-005 | Legal or licensing issues around firmware redistribution could block releases. | medium | critical | Separate firmware handling from repo contents and track provenance and rights before distribution. | open |
| R-006 | Lack of a second target device could hide portability problems until late. | medium | high | Keep second-device criteria visible in planning and perform architecture reviews before device-specific shortcuts spread. | open |
| R-007 | Security and update assumptions might be deferred too long and become expensive to retrofit. | medium | high | Document update and rollback constraints early in manifests, installer, and package ownership boundaries. | open |

## Review Cadence

- review at least once per sprint
- add new risks when architectural or legal unknowns appear
- close risks only when mitigations are implemented and evidenced
