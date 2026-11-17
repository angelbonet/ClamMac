# Estructura del proyecto

Swift Package con dos destinos: una librería con la lógica (`ClamMacCore`, testeable) y la app SwiftUI (`ClamMac`).

```
ClamMac/
├── Package.swift
├── Sources/
│   ├── ClamMacCore/              # lógica, sin interfaz
│   │   ├── ClamPaths.swift       # localiza binarios de ClamAV y carpetas de datos
│   │   ├── Settings.swift        # ajustes (JSON, decodificación tolerante a versiones antiguas)
│   │   ├── Shell.swift           # ejecutar procesos sin bloquear
│   │   ├── Scanner.swift         # analiza con clamdscan / clamscan y parsea la salida
│   │   ├── ClamdManager.swift    # arranca y para el clamd propio (socket en Application Support)
│   │   ├── FolderWatcher.swift   # FSEvents + espera a que el fichero termine de escribirse
│   │   ├── Quarantine.swift      # apartar, listar, restaurar y eliminar
│   │   ├── Updater.swift         # freshclam y versión de las firmas
│   │   ├── UpdateChecker.swift   # busca/descarga/verifica versiones de la app en GitHub
│   │   ├── SelfUpdater.swift     # sustituye la app en ejecución y la reabre (con marcha atrás)
│   │   ├── Keychain.swift        # token de Pushover
│   │   └── Pushover.swift
│   └── ClamMac/                  # app SwiftUI
│       ├── ClamMacApp.swift      # barra de menú + ventana
│       ├── Engine.swift          # orquesta todo (ObservableObject)
│       └── Views.swift           # pantallas
├── Tests/ClamMacCoreTests/
├── Icon/                         # PNG de diseño y generador de .icns
├── Installer/Leeme.template.html      # Léeme del DMG
├── docs/ + mkdocs.yml            # esta documentación
├── build_app.sh  build_dmg.sh  release.sh
└── .github/workflows/docs.yml    # publica la documentación en GitHub Pages
```

## Cómo trabaja

1. `FolderWatcher` recibe eventos de FSEvents y espera a que cada fichero no cambie durante dos ciclos de 2 s (máximo 10 min). Descarta temporales y `.DS_Store`.
2. `Engine` pasa los ficheros a `Scanner`, que usa **clamd** (`clamdscan --fdpass`) si está vivo y, si no, `clamscan`.
3. Las amenazas van a `Quarantine` (movidas con permisos 000) y se avisa por notificación y, si procede, Pushover.
4. Un temporizador por minuto lanza la actualización de firmas, la búsqueda de versiones y el análisis programado cuando toca.

## Decisiones de diseño

- **Reutiliza el ClamAV de Homebrew** en vez de empaquetarlo: no duplica firmas (cientos de MB) y se actualiza con el sistema habitual.
- **Sin sandbox**: necesita leer carpetas del usuario y ejecutar `clamd`/`freshclam`; por eso pide *Acceso total al disco*.
- **Modo de lenguaje Swift 5** (`swiftLanguageModes: [.v5]`) para evitar fricción de concurrencia estricta.
