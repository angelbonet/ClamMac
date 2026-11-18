# CLAUDE.md — ClamMac

App nativa de barra de menú (SwiftUI, macOS 14+, binario universal arm64 + x86_64) que es la interfaz del ClamAV de Homebrew. Equivalente de ClamGuard (Windows). Autor: Ángel Bonet · ABDatabase. Docs: https://angelbonet.github.io/ClamMac/

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
- Autoprueba de la app: fichero EICAR (`TestFile`) → botón «Probar protección»; gancho de pruebas `CLAMMAC_AUTOSELFTEST=1`. Hay ZIP descargable en `docs/descargas/`.
- Las versiones <1.0.2 no tienen autoactualización; el cambio de versión depende del código de la versión *instalada*.
- El `swift`/`git` del PATH deben ser los modernos (Xcode / Homebrew); en esta máquina hubo restos antiguos.
- **Dock**: la app es `LSUIElement`; al abrir la ventana pasa a `.regular` y vuelve a `.accessory` escuchando `NSWindow.willCloseNotification` (en SwiftUI `onDisappear` NO se dispara al cerrar la ventana).
- Notarización: un `503` de notarytool es caída del servicio de Apple (no del llavero); reintentar más tarde. `gh` necesita el scope `workflow` para subir `.github/workflows`.
- Los iconos derivan de la mascota de ClamAV (marca de Cisco): no cubiertos por la licencia MIT.

## Motor incluido (desde 1.1.0)
- ClamAV 1.5.4 va DENTRO de la app (`Contents/Helpers`, estático, universal), compilado por `Engine/build_clamav.sh` (necesita `brew install cmake ninja rustup`; toolchain Rust aislada en `build/engine/`). `build_app.sh` exige `build/engine/universal` y firma cada helper con hardened runtime + `--identifier`.
- Firmas propias en `Application Support/ClamMac/Database` + `freshclam.conf` propio; la 1ª vez copia las de Homebrew. Se pasa `--cvdcertsdir` (certs en `Contents/Resources/certs`) a freshclam/clamscan/clamd. `NULL X509 store` de freshclam es ruido inocuo (libcurl de Apple, no OpenSSL).
- GPLv2: licencias en `Contents/Resources/Licenses` + `docs/licencias.md` (enlace al tarball exacto + receta). Subir de versión ClamAV = cambiar versión/SHA en el script y en licencias.
- Sin motor incluido (builds de desarrollo) cae al de Homebrew. Pruebas de la app desde terminal NO pasan el autotest (TCC): instalar en /Applications y lanzar con `open -n --env ...`.

## Estado
- Última versión publicada: **1.1.0** (antes 1.0.3 (2026-11-17), universal, notarizada; web de docs desplegada. Autoactualización de un clic verificada en uso real.

## Pendiente
- Capturas nuevas (Estado, Cuarentena, Firmas) para la documentación; probar en un Mac Intel real.
- Decisiones abiertas: licencia MIT, ZIP EICAR, logo abDatabase en «Acerca de».
- Retomar capturas de pantalla de la 1.0.2 para la documentación (Estado, Cuarentena, Firmas).
