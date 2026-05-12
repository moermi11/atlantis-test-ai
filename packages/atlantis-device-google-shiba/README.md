# atlantis-device-google-shiba

Google Pixel 8 (`shiba`) device package skeleton for Atlantis.

Sprint 1 responsibility:

- package device-specific boot and kernel integration
- carry documented hardware quirks
- define firmware acquisition hooks where legally appropriate
- keep `shiba` specifics out of generic Atlantis packages
- act as the optional device userspace package boundary referenced by the `shiba` compose profile and stage

This package must remain device-specific. It is not a place to hide generic Atlantis logic, and its existence does not imply working hardware support.

Current non-claim:

- this package is not a kernel artifact
- this package is not an initramfs artifact
- a staged `shiba` compose output that references this package boundary does not mean Pixel 8 `boots`
- a staged `shiba` boot-artifact directory that references explicit kernel/initramfs inputs does not mean Pixel 8 `boots`
