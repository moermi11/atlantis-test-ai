# ci

This directory contains continuous integration and release automation definitions.

Planned jobs include:

- Debian packaging lint/build checks
- package artifact directory validation before feed generation
- manifest validation
- documentation linting and link checks
- image composition smoke builds
- release artifact generation and provenance capture

CI should validate reproducibility assumptions early, even before hardware bring-up is complete.
