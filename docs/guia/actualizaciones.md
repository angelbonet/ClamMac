# Actualizaciones

ClamMac se actualiza en dos niveles, que no hay que confundir.

## La biblioteca de amenazas (firmas)

Son las «definiciones de virus» de ClamAV. Se descargan con `freshclam` desde el espejo de abDatabase (`clamav.abdatabase.com`) y, si no responde, desde los servidores oficiales de ClamAV.

En la pantalla **Firmas**:

| Opción | Qué hace |
|---|---|
| **Automática** | Comprueba y descarga firmas según la frecuencia elegida: cada hora, 4 h, 12 h, diaria o semanal |
| **Manual** | Solo actualiza cuando pulsas **Actualizar ahora** |

La pantalla muestra la versión del motor, la versión y fecha de las firmas, y la última comprobación. Tras descargar firmas nuevas, ClamMac recarga `clamd` automáticamente.

!!! tip "Recomendación"
    Déjalo en **Automática**. Las firmas nuevas aparecen varias veces al día.

## La propia aplicación (ClamMac)

ClamMac busca versiones nuevas en las [releases de GitHub](https://github.com/angelbonet/ClamMac/releases) **una vez al día** (se desactiva en *Ajustes*, o pulsa *Buscar actualizaciones ahora*).

Cuando hay una versión nueva aparece un **aviso** (banner en *Estado*, entrada en el menú del escudo y notificación). Al pulsar **Actualizar y reiniciar**:

1. Descarga el DMG de la release.
2. **Verifica** que es auténtico: coincide con el SHA-256 publicado, está firmado por el equipo del desarrollador (`P4CY35PF88`) y notarizado por Apple, y la app del interior es la versión anunciada.
3. Se **cierra**, sustituye la app instalada y se **vuelve a abrir sola**, sin que tengas que hacer nada.
4. Si algo falla durante el cambio, **restaura la versión anterior**.
5. Al arrancar avisa: *«ClamMac se ha actualizado a X»*.

Durante el cambio hay unos segundos sin protección (mientras la app se reinicia).

!!! note "Copias que no pueden actualizarse solas"
    Si ClamMac se ejecuta desde el DMG o desde una carpeta sin permiso de escritura, no puede sustituirse a sí misma. En ese caso descarga y abre el DMG y te indica los pasos manuales (cerrar, arrastrar a Aplicaciones y abrir).

!!! info "Versiones 1.0.0 y 1.0.1"
    Las versiones anteriores a la 1.0.2 no incluyen la actualización automática. Para pasar de ellas a una más nueva hay que instalar a mano una vez (abrir el DMG y arrastrar).
