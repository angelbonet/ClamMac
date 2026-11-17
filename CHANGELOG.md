# Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [1.0.2] — 2026-11-17
### Añadido
- **Actualización con un clic**: la app descarga y verifica la versión nueva, se cierra, se sustituye y se vuelve a abrir sola. Si algo falla, restaura la anterior.
- Aviso al arrancar tras actualizarse («ClamMac se ha actualizado a X»).
### Cambiado
- El Léeme del DMG explica la actualización y deja de pedir «clic derecho › Abrir» (la app va notarizada).

## [1.0.1] — 2026-11-17
### Corregido
- La hora de la versión de firmas se mostraba con una hora de más (ClamAV ya la da en hora local).

## [1.0.0] — 2026-11-17
Primera versión.
- Vigilancia de carpetas (FSEvents), análisis rápido / de carpeta / programado, cuarentena con restaurar y eliminar.
- Biblioteca de amenazas con actualización automática o manual.
- `clamd` propio opcional para análisis instantáneo.
- Avisos del sistema y Pushover (token en el llavero).
- Búsqueda de versiones nuevas de la app en GitHub.
- Firmada con Developer ID y notarizada por Apple.
