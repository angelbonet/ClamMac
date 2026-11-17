# Seguridad y privacidad

## Qué hace ClamMac

- Analiza con **ClamAV** los ficheros de las carpetas vigiladas y los que tú le pidas.
- Aparta lo infectado a cuarentena o avisa, según tus ajustes.
- **No desactiva** ninguna protección de macOS.

## Convivencia con las protecciones de macOS

ClamMac **complementa** a XProtect, Gatekeeper y la notarización de Apple; no los sustituye ni los toca. Funcionan a la vez sin interferir. Ventaja de ClamAV: firmas abiertas, que además detectan malware de **otras plataformas** (Windows, Linux, macros de Office), útil si reenvías archivos a otras personas.

## Lo que ClamMac **no** hace (limitaciones)

- **No es un antivirus residente a nivel de kernel.** Detecta lo que cae en las carpetas vigiladas **después de que el fichero se haya escrito**, no lo bloquea antes de abrirse. Si abres un fichero justo al descargarlo, puede ejecutarse antes de que termine el análisis (normalmente segundos).
- **No analiza todo el disco por defecto**: solo las carpetas vigiladas y los análisis que lances o programes.
- **No protege en tiempo real contra exploits ni tráfico de red.**
- **La cuarentena no está cifrada**: el fichero se aparta con todos los permisos quitados, pero no se cifra.
- La detección es la de ClamAV: no detecta todo ni está libre de falsos positivos.

## Qué datos usa y adónde se conecta

ClamMac **no envía telemetría** ni datos de uso. Las únicas conexiones son:

| Destino | Para qué |
|---|---|
| `database.clamav.net` (vía `freshclam`) | Descargar las firmas |
| `api.github.com` y `github.com` | Buscar y descargar versiones nuevas de la app |
| `api.pushover.net` | Solo si activas Pushover, para enviarte avisos |

Los ficheros analizados **no salen del Mac**: el análisis es local.

### Dónde guarda sus datos

Todo en `~/Library/Application Support/ClamMac/`:

| Fichero / carpeta | Contenido |
|---|---|
| `settings.json` | Ajustes |
| `clammac.log` | Registro de actividad |
| `Quarantine/` | Ficheros apartados y sus metadatos |
| `Updates/`, `update.log` | Descargas y registro de actualizaciones de la app |
| `clamd.conf`, `clamd.sock`, `clamd.log` | `clamd` propio de la app |

El **token de Pushover** se guarda en el **llavero** de macOS.

## Integridad de la app y de las actualizaciones

- La app está **firmada con Developer ID** y **notarizada** por Apple.
- Las actualizaciones solo se instalan si pasan las comprobaciones: SHA-256, firma del equipo del desarrollador, notarización y versión esperada. Cualquier fallo cancela la instalación.
- El código es abierto: puedes revisarlo en el [repositorio](https://github.com/angelbonet/ClamMac).
