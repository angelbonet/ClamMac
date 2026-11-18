# Problemas frecuentes

## Aparece el aviso naranja «Falta Acceso total al disco»

Concédelo siguiendo la [guía de permisos](permisos.md). Después cierra y abre ClamMac.

## «ClamMac todavía NO te protege» (falta ClamAV)

Desde la 1.1.0 el motor va dentro de la app, así que no debería ocurrir. Si aparece, la copia de ClamMac está incompleta o dañada: descarga el DMG de [Releases](https://github.com/angelbonet/ClamMac/releases/latest) e instálalo de nuevo.

## La app tiene un icono de «prohibido» o no se abre

Tu Mac tiene un macOS anterior a **13 (Ventura)**. Mira *menú Apple → Acerca de este Mac*. Si no se puede actualizar, ClamMac no es compatible con ese equipo: [requisitos del sistema](requisitos.md).

## «Todavía no hay firmas de virus»

Pasa si la primera descarga falló por falta de internet. Conéctate y pulsa **Estado › Actualizar firmas**.

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

Pulsa **Estado › Probar protección**, o usa el fichero de prueba EICAR: [guía completa](prueba.md).

## La app no se actualiza sola

- Solo desde la 1.0.2; las anteriores se actualizan a mano (ver [Actualizaciones](actualizaciones.md)).
- Si ejecutas ClamMac desde el DMG o una carpeta sin permisos, no puede sustituirse; copia primero la app a *Aplicaciones*.

## Desinstalar

1. En **Ajustes**, desmarca *Abrir ClamMac al iniciar sesión*.
2. Cierra ClamMac (menú del escudo › *Salir*) y arrastra **ClamMac** de Aplicaciones a la Papelera.
3. Opcional: borra sus datos, incluida la cuarentena: `~/Library/Application Support/ClamMac`.
4. Opcional: quita su permiso en *Acceso total al disco*.

ClamAV no se desinstala: `brew uninstall clamav` si ya no lo quieres.
