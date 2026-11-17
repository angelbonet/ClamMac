# Instalación

## 1. Instalar ClamAV (el motor)

ClamMac es la interfaz; el motor antivirus es **ClamAV**, que **no incluye**. Se instala con [Homebrew](https://brew.sh/):

```bash
brew install clamav
```

Si ya lo tienes, no hay nada que hacer: ClamMac usa el de Homebrew (`/opt/homebrew` o `/usr/local`) y reutiliza sus firmas. Si no lo encuentra, la pantalla *Estado* lo avisa.

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

## 4. Ajustes recomendados

- **Firmas**: elige *Automática* o *Manual* y la frecuencia.
- **Vigilancia**: añade las carpetas que quieras proteger (Descargas ya viene activada).
- **Ajustes**: marca *Abrir ClamMac al iniciar sesión* para estar protegido desde el arranque.

## Si vienes de scripts propios (launchd)

Si ya analizabas Descargas con un script de `launchd`, **desactívalo** para no analizar dos veces:

```bash
launchctl bootout gui/$(id -u)/NOMBRE.DEL.AGENTE
```
