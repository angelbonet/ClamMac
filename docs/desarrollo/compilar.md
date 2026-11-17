# Compilar y firmar

## Requisitos

- macOS 14+ con **Xcode** (Swift 6.x). Comprueba que `swift --version` es el de Xcode.
- ClamAV (`brew install clamav`) para ejecutar los tests de detección.
- Python 3 con Pillow y numpy, solo para regenerar los iconos.

## Comandos

```bash
git clone https://github.com/angelbonet/ClamMac.git
cd ClamMac

swift build                   # compilación de desarrollo
swift test                    # tests (incluye detección EICAR real)
./build_app.sh                # build/ClamMac.app firmada
./build_app.sh --install      # ... y la copia a /Applications
./build_dmg.sh                # DMG firmado y notarizado (build/ClamMac-x.y.z.dmg)
SKIP_NOTARIZE=1 ./build_dmg.sh   # DMG sin notarizar, para pruebas rápidas
```

## Firma de código

Los scripts firman por **hash de certificado** (`SIGN_HASH` en `build_app.sh` y `build_dmg.sh`) con *hardened runtime* y *timestamp*. Se usa el hash porque si hay dos certificados «Developer ID Application» con el mismo nombre, `codesign` falla por ambigüedad.

Para compilar **tu propia copia**:

1. Lista tus identidades: `security find-identity -v -p codesigning`
2. Cambia `SIGN_HASH` por el hash de tu *Developer ID Application*.
3. Cambia `expectedTeamID` en `Sources/ClamMacCore/UpdateChecker.swift` por tu Team ID (la app solo instala actualizaciones firmadas por ese equipo) y `UpdateChecker.repo` por tu repositorio.

## Notarización

Se usa `notarytool` con un perfil guardado en el llavero (nombre por defecto en `build_dmg.sh`: variable `NOTARY_PROFILE`):

```bash
xcrun notarytool store-credentials "mi-perfil" \
  --apple-id "tu@apple.id" --team-id "TEAMID" --password "contraseña-específica-de-app"
NOTARY_PROFILE=mi-perfil ./build_dmg.sh
```

`build_dmg.sh` notariza la app y el DMG, graba los tickets (`stapler`) y verifica con `spctl`.

!!! warning "Con la pantalla bloqueada falla"
    Con la sesión bloqueada, `notarytool` no puede leer el perfil del llavero ("No Keychain password item found"). Mantén el Mac desbloqueado durante la notarización (p. ej. con `caffeinate -dimsu`). La cola de Apple suele tardar 3-4 minutos, pero a veces mucho más.

## Variables de entorno solo para pruebas

| Variable | Efecto |
|---|---|
| `CLAMMAC_DATA_DIR` | Usa otra carpeta de datos (aísla ajustes, `clamd`, cuarentena) |
| `CLAMMAC_FAKE_VERSION` | Simula otra versión instalada (p. ej. `0.0.1` para forzar el aviso de actualización) |
| `CLAMMAC_AUTOINSTALL=1` | Instala la actualización en cuanto la encuentra |
| `CLAMMAC_UPDATE_NO_RELAUNCH=1` | No reabre la app tras sustituirla |
| `CLAMMAC_LIVE=1` | Activa el test contra la API real de GitHub |

!!! danger "Aísla siempre las pruebas"
    Al probar una instancia aparte, define `CLAMMAC_DATA_DIR`. Sin él comparte los ajustes y el `clamd` de la app instalada y puede cerrarle el `clamd`.

## Iconos

`Icon/src/` guarda los PNG de diseño; `python3 Icon/make_icons.py` genera `AppIcon.icns` (app) e `InstallerIcon.icns` (DMG) con fondo transparente. El script del DMG pone el icono del instalador al volumen y al propio `.dmg`.

## El Léeme del DMG

Se genera desde `Installer/Leeme.template.html` (HTML autocontenido con hoja de estilos de impresión) y se incluye como `Léeme.html`; `__VERSION__` se sustituye al construir.
