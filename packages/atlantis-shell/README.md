# atlantis-shell

Atlantis shell integration package skeleton.

Sprint 1 responsibility:

- depend on the initial upstream shell stack used by Atlantis
- carry Atlantis-owned session defaults and integration later
- keep the package boundary stable so Phosh can be replaced in a future sprint

Current decision:

- upstream Phosh is the initial shell
- Atlantis does not build a custom shell in Sprint 1
- this package exists so a future Atlantis shell can replace Phosh without moving shell ownership into `atlantis-base`
