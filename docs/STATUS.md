# 🌊 Atlantis – Sprint 2 Status

| Metadaten | Wert |
|-----------|------|
| Sprint-Ziel | Dry-Run & Contract-Validierung (Phase 1) |
| Stichtag Review | [TT.MM.JJJJ] |
| Hardware | Google Pixel 8 (`shiba`) – physisch verfügbar |
| Basis-OS | Debian `bookworm` / `arm64` |
| Shell | Phosh (Wayland) |

## 🛡️ Guarded Contracts (Status)
| Contract | Pfad/Datei | Status | Letzter Check |
|----------|------------|--------|---------------|
| Device Compose (`shiba`) | `profiles/shiba/` | ⬜ Entwurf | - |
| Boot-Artifact | `out/boot-artifacts/` | ⬜ Nicht validiert | - |
| Installer-Prep | `contracts/installer-prep/` | ⬜ Geblockt | - |
| Read-Only Evidence | `evidence/` | ⬜ Leer | - |
| Decision-Review | `reviews/` | ⬜ Kein Input | - |
| Command-Plan | `plans/command-plan/` | 🚫 Explizit blockiert | - |
| Readiness | `contracts/readiness/` | ⬜ Nicht erreicht | - |
| Operator-Session | `bundles/operator/` | ⬜ Staging | - |
| Execution-Harness | `harness/` | ⬜ Nicht aktiv | - |

## 🤖 KI-Auftrags-Log
| Datum | Modell | Aufgabe | Output-Datei | Hash/Sign | Validiert? |
|-------|--------|---------|--------------|-----------|------------|
| - | - | - | - | - | - |

## ✅ Go / No-Go Matrix
- 🔴 **FLASH VERBOTEN**, solange nicht alle Contracts auf `✅ Validiert` stehen.
- 🔴 **KEIN MERGE** in `main`, wenn `CI` oder `Smoke-Test` rot markiert ist.
- 🟡 **TESTWEISE EXECUTION** nur in isolierten Verzeichnissen (`/tmp/atlantis-test/` oder separatem Branch).
- 🟢 **GO** nur bei: reproduzierbarer Hash-Kette + manueller Bestätigung in dieser Datei.

## 📌 Nächste 3 Schritte
1. [ ] Contract-Dateien auf syntaktische & logische Vollständigkeit prüfen (Phase 1)
2. [ ] Dry-Run mit `mmdebstrap` im Staging-Ordner
3. [ ] Erster Read-Only Evidence-Chain Aufbau
