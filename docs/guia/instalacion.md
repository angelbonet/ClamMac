# Instalación

## 1. El motor antivirus ya va incluido

ClamMac lleva dentro el motor **ClamAV** (versión para Apple Silicon e Intel). **No tienes que instalar nada más**: ni Homebrew, ni Terminal.

La primera vez que abras ClamMac descargará las firmas de virus (unos 300 MB, 1-2 minutos). Si ya tenías ClamAV con Homebrew, ClamMac copia sus firmas para no descargarlas otra vez; el ClamAV de Homebrew se queda como estaba y ClamMac usa el suyo propio.

## 2. Instalar ClamMac

1. Descarga `ClamMac-x.y.z.dmg` de [Releases](https://github.com/angelbonet/ClamMac/releases/latest).
2. Ábrelo y **arrastra ClamMac** encima de la carpeta **Applications**.
3. Expulsa el disco «ClamMac» desde el Finder.
4. Abre **ClamMac** desde Aplicaciones. Aparecerá un **escudo en la barra de menú** y se abrirá su ventana.

El DMG incluye un `Léeme.html` con estos pasos.

!!! success "Sin avisos de seguridad"
    ClamMac está **firmada con Developer ID y notarizada por Apple**, así que se abre con doble clic sin el aviso de «no se puede verificar».

## 3. Conceder permisos

Imprescindible: [Acceso total al disco](permisos.md).

## 4. Comprobar que funciona

En **Estado**, pulsa **Probar protección**: ClamMac crea un fichero de prueba inofensivo y comprueba que lo detecta. Detalles en [Comprobar que funciona](prueba.md).

## 5. Ajustes recomendados

- **Firmas**: elige *Automática* o *Manual* y la frecuencia.
- **Vigilancia**: añade las carpetas que quieras proteger (Descargas ya viene activada).
- **Ajustes**: marca *Abrir ClamMac al iniciar sesión* para estar protegido desde el arranque.

## Si vienes de scripts propios (launchd)

Si ya analizabas Descargas con un script de `launchd`, **desactívalo** para no analizar dos veces:

```bash
launchctl bootout gui/$(id -u)/NOMBRE.DEL.AGENTE
```
