# ClamMac

Interfaz nativa para macOS (SwiftUI, barra de menú) del antivirus libre **ClamAV**. Equivalente para Mac de ClamGuard (Windows).

- **Vigilancia de carpetas** (FSEvents): analiza lo que entra en Descargas u otras carpetas, esperando a que termine la escritura.
- **Biblioteca de amenazas**: actualización automática (cada 1/4/12/24/168 h) o manual.
- **Análisis** rápido, de una carpeta o programado por día y hora.
- **Cuarentena** con restaurar y eliminar.
- **clamd propio** para análisis instantáneo (opcional).
- **Avisos**: notificaciones del sistema y Pushover (token en el llavero).
- **Actualización de la app con un clic** desde las *releases* de este repositorio: descarga verificada (SHA-256, firma Developer ID y notarización), se cierra, se sustituye y se vuelve a abrir sola; si algo falla restaura la versión anterior.

Requisitos: macOS 14 o superior y ClamAV (`brew install clamav`).

## Instalar
Descarga el `.dmg` de la [última release](https://github.com/angelbonet/ClamMac/releases/latest), ábrelo y arrastra **ClamMac** a **Aplicaciones**. Está firmado con Developer ID y notarizado por Apple.

⚠️ Después concede **Acceso total al disco** a ClamMac (Ajustes del Sistema › Privacidad y seguridad). Sin él macOS oculta carpetas al análisis en silencio. El DMG incluye un `Léeme.html` con los pasos.

## Compilar
```
swift test                    # tests (incluye detección EICAR con tu ClamAV)
./build_app.sh --install      # compila, firma (Developer ID) e instala en /Applications
./build_dmg.sh                # DMG firmado y notarizado (perfil de notarytool en el llavero)
./release.sh "Notas"          # publica la release en GitHub con el DMG y su SHA-256
```
Los scripts firman con el certificado de INNOVAORTO AIE; para compilar tu propia copia cambia `SIGN_HASH` y `NOTARY_PROFILE`.

Datos: `~/Library/Application Support/ClamMac/` (ajustes, cuarentena, registro).

## Créditos y marcas
Hecho por **Ángel Bonet · ABDatabase** · [abdatabase.com](https://abdatabase.com) · [☕ Invita un café](https://buymeacoffee.com/angelbonet)

ClamAV® y su mascota son marcas de Cisco Systems. ClamMac es un proyecto independiente, sin relación con Cisco ni con Apple; solo es una interfaz que usa el ClamAV de Homebrew.
