# Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [1.2.0] — 2026-11-18
### Añadido
- **Selección de idioma**: español, català, English, français y Deutsch. Por defecto sigue el idioma de macOS; se puede fijar en *Ajustes › Idioma* (se aplica al reiniciar). Traducidos menús, pantallas, avisos, registro y mensajes de error; fechas y horas según el idioma.
- Prueba automática de que las cinco traducciones están completas (mismas claves y marcadores).

## [1.1.2] — 2026-11-18
### Cambiado
- **Requisito mínimo: macOS 13 (Ventura)** en lugar de macOS 14: la app y el motor ClamAV se han recompilado con ese mínimo, lo que añade los Mac Intel de 2017 en adelante que se quedaron en Ventura.
### Añadido
- Página «Requisitos del sistema» (versiones de macOS, Macs compatibles, espacio, cómo comprobarlo) y aviso de requisitos en el Léeme del DMG, el README y la web.

## [1.1.1] — 2026-11-18
### Cambiado
- La app y el instalador se firman y notarizan con la cuenta de **Ángel Bonet (desarrollador independiente)**, ya no con INNOVAORTO AIE. Al instalarla por primera vez con esta firma macOS puede pedir de nuevo el permiso de *Acceso total al disco*.

## [1.1.0] — 2026-11-18
### Añadido
- **ClamAV incluido en la app** (universal, Apple Silicon + Intel): ya no hace falta Homebrew ni Terminal. Firmas propias en `Application Support/ClamMac/Database` (copia las de Homebrew la primera vez si existen) y descarga inicial automática.
- Verificación de la firma digital de las bases de ClamAV con el certificado incluido.
- Página de licencias y código fuente.

## [1.0.4] — 2026-11-18
### Añadido
- **Instalación guiada de ClamAV**: si falta el motor, *Estado* ofrece «Instalar ClamAV ahora» (con Homebrew) o, si no hay Homebrew, explica cómo instalarlo; ClamMac detecta la instalación solo.
- Crea `freshclam.conf` automáticamente tras instalar ClamAV.
### Corregido
- Sin ClamAV, la app decía «Vigilancia: Activa». Ahora muestra «Sin protección» en rojo (ventana, menú e icono) y desactiva análisis, firmas y prueba.

## [1.0.3] — 2026-11-17
### Corregido
- ClamMac ya no se queda en el Dock al cerrar la ventana: vuelve a ser solo icono de barra de menús.

## [1.0.2] — 2026-11-17
### Añadido
- **Binario universal** (Apple Silicon + Intel).
- **Botón «Probar protección»**: crea un fichero de prueba EICAR (inofensivo), comprueba que ClamMac lo detecta y lo aparta, y lo limpia. También en el menú del escudo.
- Guía «Comprobar que funciona» y ZIP descargable con el fichero de prueba y un LEEME explicativo.
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
