# Problemas frecuentes

## Aparece el aviso naranja «Falta Acceso total al disco»

Concédelo siguiendo la [guía de permisos](permisos.md). Después cierra y abre ClamMac.

## «ClamAV no está instalado»

```bash
brew install clamav
```

Después reabre ClamMac.

## «clamd no arrancó; se usará clamscan»

ClamMac sigue funcionando, pero cada análisis es más lento. Causas habituales:

- Las firmas aún no están descargadas: pulsa **Firmas › Actualizar ahora** y reabre la app.
- Poca memoria disponible: desactiva *Mantener clamd en marcha* en *Ajustes*.

## La actualización de firmas falla

- Comprueba la conexión a Internet.
- Mira el mensaje en *Registro*. Si dice que otro `freshclam` está en marcha, espera unos minutos.
- Prueba desde la terminal: `freshclam`

## Detectó un fichero que sé que es seguro (falso positivo)

Ve a **Cuarentena › Restaurar**. Si el fichero vuelve a detectarse en cada análisis, puedes desactivar *Mover amenazas a cuarentena automáticamente* en *Vigilancia* para que solo avise.

## No salen las notificaciones

**Ajustes del Sistema › Notificaciones › ClamMac** y activa *Permitir notificaciones*. Comprueba también que *Notificaciones del sistema* esté marcado en los ajustes de ClamMac.

## ¿Cómo sé que me protege?

Prueba con el fichero de test **EICAR** (inofensivo, reconocido por todos los antivirus). En una carpeta vigilada:

```bash
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ~/Downloads/eicar-test.com
```

En unos segundos debe desaparecer de Descargas y aparecer en **Cuarentena** como `Eicar-Test-Signature`. Elimínalo desde la app.

## La app no se actualiza sola

- Solo desde la 1.0.2; las anteriores se actualizan a mano (ver [Actualizaciones](actualizaciones.md)).
- Si ejecutas ClamMac desde el DMG o una carpeta sin permisos, no puede sustituirse; copia primero la app a *Aplicaciones*.

## Desinstalar

1. En **Ajustes**, desmarca *Abrir ClamMac al iniciar sesión*.
2. Cierra ClamMac (menú del escudo › *Salir*) y arrastra **ClamMac** de Aplicaciones a la Papelera.
3. Opcional: borra sus datos, incluida la cuarentena: `~/Library/Application Support/ClamMac`.
4. Opcional: quita su permiso en *Acceso total al disco*.

ClamAV no se desinstala: `brew uninstall clamav` si ya no lo quieres.
