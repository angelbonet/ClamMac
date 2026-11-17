# CLAUDE.md — ClamMac

App nativa de barra de menú (SwiftUI, macOS 14+, solo arm64 por ahora) que es la interfaz del ClamAV de Homebrew. Equivalente de ClamGuard (Windows). Autor: Ángel Bonet · ABDatabase. Docs: https://angelbonet.github.io/ClamMac/

## Estructura
- `Sources/ClamMacCore` lógica testeable · `Sources/ClamMac` app (Engine = orquestador, Views, ClamMacApp).
- Scripts: `build_app.sh` (compila+firma), `build_dmg.sh` (DMG, notariza app y DMG), `release.sh` (publica en GitHub).
- Documentación para usuarios y desarrollo en `docs/` (MkDocs Material → GitHub Pages, workflow `docs.yml`). Léeme del DMG: `Installer/Leeme.template.html`.

## Cosas que NO son obvias
- **Firma por hash** (`SIGN_HASH`, certificado G2 de Innovaorto `F211AC…`) porque hay dos certificados con el mismo nombre. Notarización: perfil `notarytool` `cephaloplan` en el llavero. **Con la pantalla bloqueada, notarytool no lee el llavero** y falla: mantener desbloqueado.
- La app **no está sandboxeada** y necesita *Acceso total al disco*; sin él macOS oculta ficheros en silencio (por eso hay banner de aviso).
- `clamscan --version` imprime la fecha de las firmas en **hora local** (no UTC).
- Ajustes (`AppSettings`) con decodificación tolerante: al añadir un campo hay que añadirlo también a `CodingKeys` e `init(from:)`, o se pierden ajustes antiguos.
- **Pruebas aisladas**: usar `CLAMMAC_DATA_DIR`; sin él una instancia de prueba comparte datos y mata el `clamd` de la app real. Otras variables de prueba: `CLAMMAC_FAKE_VERSION`, `CLAMMAC_AUTOINSTALL`, `CLAMMAC_UPDATE_NO_RELAUNCH`, `CLAMMAC_LIVE`.
- Las versiones <1.0.2 no tienen autoactualización; el cambio de versión depende del código de la versión *instalada*.
- El `swift`/`git` del PATH deben ser los modernos (Xcode / Homebrew); en esta máquina hubo restos antiguos.
- Los iconos derivan de la mascota de ClamAV (marca de Cisco): no cubiertos por la licencia MIT.

## Pendiente
- Binario universal (Intel) · retomar capturas de pantalla de la 1.0.2 para la documentación (Estado, Cuarentena, Firmas).
