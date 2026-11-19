# CLAUDE.md — ClamMac

App nativa de barra de menú (SwiftUI, macOS 13+ (mínimo; no usar APIs de macOS 14 como `onChange(_:_:)` de dos parámetros ni `Text.foregroundStyle`), binario universal arm64 + x86_64) con el motor ClamAV incluido (sin Homebrew). Proyecto propio, NO es un fork: la idea nace de ClamGuard (Windows) de David Casas M (CC BY-SA 4.0; `davidcasascompetenciadigital-prog/ClamGuard`), sin compartir código; el MIT de ClamMac solo vale mientras siga así. Autor: Ángel Bonet · ABDatabase. Docs: https://angelbonet.github.io/ClamMac/

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
- Versión actual: **1.2.3**, PUBLICADA 2026-11-19 y marcada como correcta (única release en GitHub; 1.2.0–1.2.2 borradas porque no descargaban firmas en Macs ajenos al de desarrollo, ver «Trampa grave»). 1.2.2 = el cool-down de freshclam.dat bloqueaba también el espejo; 1.2.1 = espejo de firmas, motivo del fallo/cool-down, «Copiar diagnóstico», tarjeta de novedades, japonés y árabe = 16 idiomas. Autoactualización de un clic verificada en uso real.
- Fork en la organización: https://github.com/fmwarriors/ClamMac (web https://fmwarriors.github.io/ClamMac/), como con rustdesk-manager. Sincronizar tras cada push: `gh repo sync fmwarriors/ClamMac` (y relanzar `Deploy Documentation` si cambian docs).

- Solo se conserva en GitHub la release más reciente (y su etiqueta): al publicar una nueva, borrar la anterior (`gh release delete vX --cleanup-tag --yes`) si Ángel lo confirma.
- `LICENSE` debe quedar como MIT estándar (GitHub lo reconoce); los avisos extra van en `NOTICE.md`.
- **Decisión de licencia (2026-11-18): se queda MIT.** David Casas M (ClamGuard, CC BY-SA 4.0) sugirió Creative Commons; Ángel se lo explicó públicamente en X: CC no se recomienda para software y el motor ClamAV incluido es GPLv2 (NC/ND chocarían). MIT vale porque ClamMac lanza `clamscan`/`freshclam`/`clamd` como procesos separados (mera agregación). **No enlazar `libclamav` directamente**: eso haría el código obra derivada de GPL. Opcional pendiente: documentación (`docs/`) en CC BY 4.0.
- Fork de ClamGuard `angelbonet/ClamGuard`: copia sin cambios del de David; decidir si se borra.

## Firmas: espejo propio + cool-down (desde 1.2.1)
- **Causa de la incidencia Lorente (2026-11-19):** el CDN de ClamAV limita por IP pública (429/403 + «cool-down» de horas en `freshclam.dat`); varios Macs de una clínica instalando a la vez (~300 MB cada uno) lo agotan, y los reintentos lo alargan. `curl -I https://database.clamav.net` da 403.
- `Updater.updateNow`: 1.º espejo `https://clamav.abdatabase.com` (`PrivateMirror` + `DNSDatabaseInfo no`, conf propia `freshclam-mirror.conf`); si falla, CDN oficial (`freshclam.conf`) salvo que `settings.officialCoolDownUntil` esté en el futuro. Probado con freshclam real (espejo local) y con espejo caído → respaldo OK.
- Servidor del espejo: `Mirror/deploy_mirror.sh` (cvdupdate + nginx + certbot, en el VPS Arsys 94.143.142.237; lo ejecuta Ángel con sudo). **`tools.abdatabase.com` NO es un nombre DNS** (solo etiqueta del VPS); el espejo necesita el registro A `clamav.abdatabase.com`. **DESPLEGADO 2026-11-19** (DNS en Route 53 cuenta `abdatabase`, zona abdatabase.com; script ejecutado en el VPS como `administrador` con sudo; certificado Let's Encrypt hasta 2027-02-17, renovación por certbot; temporizador horario `clamav-mirror.timer`; datos en `/var/lib/clamav-mirror/db`). Probado de punta a punta con el `freshclam` de la app. Trampa: tras `systemctl reload nginx` hay que esperar unos segundos antes de probar (si no, sirve el certificado caducado del servidor por defecto `whatsapp.abdatabase.com`).
- Novedades: `Localization/<id>.lproj/WhatsNew.strings` (clave = versión, texto con «•»). **Al subir de versión hay que añadir la entrada nueva en los 16 idiomas** (test `testWhatsNewExistsForCurrentVersion` exige la de la versión actual: actualizarlo al versionar).
- Pendiente cosmético: en árabe el diseño no se espeja (barra lateral a la izquierda) y «الجديد في ClamMac 1.2.1» muestra bidi invertido.

## Soporte: «pide brew» / «Actualizar firmas no hace nada»
- Causa típica: el usuario tiene una versión <1.1.0 (dependía de Homebrew; sin él `freshclam` no se encuentra y falla en silencio). Primero pedir la versión de «Acerca de»; solución: instalar el DMG actual. Incidencia Lorente 2026-11-18 (sin confirmar).
- Si ya es ≥1.1.0: red (¿firewall bloquea `database.clamav.net` 443?) o permisos; mirar la pestaña Registro.

## Pendiente
- Probar en un Mac Intel real, en macOS 13 y en una instalación limpia sin Homebrew; probar el cambio de idioma desde el selector.
- Traducciones (13 idiomas nuevos) sin revisar por nativos.
- Web y Léeme del DMG solo en español; «Acerca de» sin mención a ClamGuard (requiere versión nueva).
- Capturas nuevas (Estado, Cuarentena, Firmas) para la documentación.
- Decisiones abiertas: ZIP EICAR, logo abDatabase en «Acerca de».

## Trampa: `freshclam.dat` y el cool-down (1.2.2)
`freshclam` guarda el cool-down del CDN (429/403) en `freshclam.dat` de la carpeta de firmas y lo respeta **también con `PrivateMirror`**, saliendo con código 0 sin descargar. Por eso `Updater` aparta ese fichero (`ClamPaths.stashFreshclamState`) durante la ejecución contra el espejo y lo restaura después, y `interpret` trata «cool-down» o «código 0 sin base de datos» como fallo. Reproducido con servidores locales (429 y bueno). Arreglo manual en un Mac con 1.2.1: `rm "~/Library/Application Support/ClamMac/Database/freshclam.dat"`.

## ⚠️ Trampa grave: ruta de certificados grabada en el binario (corregida en 1.2.3)
Tras descargar, freshclam **prueba** la base cargándola con libclamav, que busca los certificados en una ruta compilada (`<repo>/build/engine/out-<arch>/etc/certs`) y NO usa `--cvdcertsdir` ni `CVDCertsDirectory` para esa prueba. En el Mac de desarrollo esa ruta existe, así que **nunca falló aquí**; en cualquier otro Mac daba «Broken or not a CVD file» y no se descargaba ninguna firma (afectó a 1.1.0–1.2.2). Arreglo: `TestDatabases no` en los dos `freshclam*.conf` (la integridad sigue verificada por la firma digital). Descubierto por SSH en Recinf01 (Lorente, iMac 2017, Ventura) el 2026-11-19.
**Lección:** probar siempre una versión nueva en un Mac limpio / de cliente (no en el de desarrollo, donde existen rutas de compilación). Para depurar un Mac de cliente: `freshclam` a mano con un `DatabaseDirectory` temporal; la sección `[espejo]` de «Copiar diagnóstico» también lleva la salida.
Acceso a Recinf01 (temporal): salto por el servidor FM de Lorente (`ProxyCommand=ssh -p 8024 -W %h:%p admin@lorenteortodonciazar.es`) hacia `clinica@192.168.1.13`; el router no permite reenvío SSH (`forwarding-enabled=no`, no tocar). La ARCH del User-Agent de freshclam es la de compilación (arm64) aunque corra en Intel.

## Pendiente tras 1.2.3
- Verificar en Recinf01 (Lorente) que pasa a 1.2.3 y muestra versión de firmas; Ángel debe desactivar Sesión remota allí y rotar las contraseñas expuestas en el chat (Recinf01 `clinica`, sudo del VPS).
- Cosmético: árabe sin espejado RTL / bidi del título de Novedades. Mostrar también el error del espejo (no solo el cool-down oficial) en Estado.
- Lección: probar cada release en un Mac limpio/de cliente, no solo en el de desarrollo.
