# CLAUDE.md — ClamMac

App nativa de barra de menú (SwiftUI, macOS 13+ (mínimo; no usar APIs de macOS 14 como `onChange(_:_:)` de dos parámetros ni `Text.foregroundStyle`), binario universal arm64 + x86_64) que es la interfaz del ClamAV de Homebrew. Equivalente de ClamGuard (Windows). Autor: Ángel Bonet · ABDatabase. Docs: https://angelbonet.github.io/ClamMac/

## Estructura
- `Sources/ClamMacCore` lógica testeable · `Sources/ClamMac` app (Engine = orquestador, Views, ClamMacApp).
- Scripts: `build_app.sh` (compila+firma), `build_dmg.sh` (DMG, notariza app y DMG), `release.sh` (publica en GitHub).
- Documentación para usuarios y desarrollo en `docs/` (MkDocs Material → GitHub Pages, workflow `docs.yml`). Léeme del DMG: `Installer/Leeme.template.html`.

## Cosas que NO son obvias
- **Firma por hash** (`SIGN_HASH` = `DD3894D5…`, «Developer ID Application: Angel Bonet Catalá», Team `P4CY35PF88`, cuenta PERSONAL; desde 1.1.1, antes Innovaorto `54HHDMD6T8`: el usuario no quiere Innovaorto en ClamMac). Notarización: perfil `cephaloplan` con `--team-id P4CY35PF88` (`NOTARY_TEAM`). `UpdateChecker.expectedTeamID` debe coincidir con el Team de firma: cambiarlo rompe la autoactualización desde versiones anteriores (hay que instalar a mano una vez). Con la pantalla bloqueada, notarytool no lee el llavero.
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

## Idiomas (desde 1.2.0)
- 14 idiomas (es ca en fr de it pt-PT pt-BR nl pl ro sv el cs) en `Localization/<id>.lproj/Localizable.strings`, clave = texto en español. SwiftUI traduce los literales; lo calculado usa `tr()` (en `Localization.swift`, marcadores `%@`/`%ld`). Evitar ternarios de literales en `Text`/`Button` (no se traducen). Test `testTranslationsAreComplete`.
- Selector en Ajustes (`Language.setOverride` → `AppleLanguages`, se aplica al reiniciar). Prueba de UI: `CLAMMAC_OPENWINDOW=1` abre la ventana al arrancar; capturar SOLO la ventana (`screencapture -l <id>`), nunca la pantalla completa.

## Motor incluido (desde 1.1.0)
- ClamAV 1.5.4 va DENTRO de la app (`Contents/Helpers`, estático, universal), compilado por `Engine/build_clamav.sh` (necesita `brew install cmake ninja rustup`; toolchain Rust aislada en `build/engine/`). `build_app.sh` exige `build/engine/universal` y firma cada helper con hardened runtime + `--identifier`.
- Firmas propias en `Application Support/ClamMac/Database` + `freshclam.conf` propio; la 1ª vez copia las de Homebrew. Se pasa `--cvdcertsdir` (certs en `Contents/Resources/certs`) a freshclam/clamscan/clamd. `NULL X509 store` de freshclam es ruido inocuo (libcurl de Apple, no OpenSSL).
- GPLv2: licencias en `Contents/Resources/Licenses` + `docs/licencias.md` (enlace al tarball exacto + receta). Subir de versión ClamAV = cambiar versión/SHA en el script y en licencias.
- Sin motor incluido (builds de desarrollo) cae al de Homebrew. Pruebas de la app desde terminal NO pasan el autotest (TCC): instalar en /Applications y lanzar con `open -n --env ...`.

## Estado
- Última versión publicada: **1.1.2** (mínimo macOS 13, firmada con la cuenta personal). **1.2.0** (idiomas) preparada en el árbol, sin publicar. Autoactualización de un clic verificada en uso real.

## Pendiente
- Capturas nuevas (Estado, Cuarentena, Firmas) para la documentación; probar en un Mac Intel real.
- Decisiones abiertas: licencia MIT, ZIP EICAR, logo abDatabase en «Acerca de».
- Retomar capturas de pantalla de la 1.0.2 para la documentación (Estado, Cuarentena, Firmas).
