# Comprobar que funciona (fichero de prueba EICAR)

¿Cómo sabes que tu antivirus **realmente** funciona? Probándolo. Para eso existe el **fichero de prueba EICAR**: un fichero **inofensivo** que todos los antivirus detectan a propósito.

!!! success "Es completamente seguro"
    El fichero EICAR **no es un virus ni malware**. No contiene código dañino ni puede ejecutarse en macOS: es una **cadena de texto de 68 caracteres**. Puedes crearlo, descargarlo y abrirlo sin ningún riesgo.

## Qué es EICAR

- Lo crearon el **EICAR** (*European Institute for Computer Antivirus Research*) y la **CARO** (*Computer Antivirus Research Organization*) como forma estándar de probar antivirus sin usar malware real.
- Por **convenio de la industria**, todos los antivirus (ClamAV, XProtect, Defender, Kaspersky…) lo detectan como «amenaza de prueba». No es un fallo ni un falso positivo: es lo que debe pasar.
- Técnicamente es un programa de DOS inofensivo que solo imprime un mensaje. En macOS no se puede ejecutar.
- ClamAV lo identifica como **`Eicar-Test-Signature`**.

### Cómo verificar que es el fichero oficial

El fichero EICAR de 68 bytes tiene siempre esta huella **SHA-256**, publicada por el propio EICAR:

```
275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f
```

Puedes comprobarlo con `shasum -a 256 fichero`. Más información oficial: [eicar.org](https://www.eicar.org/download-anti-malware-testfile/).

## Tres formas de hacer la prueba

### 1. Con el botón de ClamMac (la más fácil)

1. Abre ClamMac y ve a **Estado**.
2. En **«Comprobar que funciona»** pulsa **Probar protección** (también está en el menú del escudo).
3. ClamMac crea un fichero de prueba en una carpeta vigilada y espera a detectarlo. En unos **5-10 segundos** verás:

    > ✅ *Todo funciona: ClamMac detectó el fichero de prueba y lo apartó a cuarentena.*

El fichero de prueba se **borra solo** al terminar y no te envía avisos por Pushover. Si algo va mal, el mensaje te dice qué revisar.

| Resultado | Significa |
|---|---|
| ✅ Verde | La protección funciona de punta a punta |
| 🟠 Naranja | El motor detecta, pero la **vigilancia está desactivada**: no protegería automáticamente |
| 🔴 Rojo | No lo detectó: revisa el [permiso de disco](permisos.md), que la carpeta esté vigilada y que haya firmas |

### 2. Creándolo con la Terminal

Copia esta línea en la Terminal. Crea el fichero en **Descargas** (que ClamMac vigila por defecto):

```bash
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ~/Downloads/eicar-test.com
```

En unos segundos el fichero **desaparece de Descargas** y aparece en **Cuarentena** como `Eicar-Test-Signature`, con una notificación de «Amenaza detectada». Para limpiar: **Cuarentena › Eliminar**.

### 3. Descargándolo

Para probar el caso real de «bajar algo de Internet»:

- **[⬇️ Descargar ClamMac-prueba-EICAR.zip](../descargas/ClamMac-prueba-EICAR.zip)** (1 KB; contiene `eicar.com` y un `LEEME.txt` que explica lo que es).
- O bájalo de la web oficial: [eicar.org](https://www.eicar.org/download-anti-malware-testfile/) (ficheros `.com`, `.txt` y `.zip`).

Guárdalo en **Descargas**. ClamMac lo analiza al terminar la descarga, lo detecta (ClamAV mira **dentro de los ZIP**) y lo aparta a **Cuarentena**.

!!! note "Es normal que el navegador o el sistema protesten"
    Safari puede descomprimir el ZIP solo y Chrome puede avisar de «archivo peligroso». También puede saltar otro antivirus que tengas. **No es un problema**: es exactamente lo que se espera de un fichero de prueba, y confirma que esas protecciones funcionan.

## Qué debería pasar

1. El fichero se **analiza al terminar de escribirse** (unos segundos).
2. ClamMac lo **detecta** como `Eicar-Test-Signature`.
3. Lo **aparta a Cuarentena** (si tienes activada la cuarentena automática) y te **avisa**.
4. Lo ves en **Cuarentena**. Pulsa **Eliminar** para borrarlo.

Si lo desactivaste, con *Mover amenazas a cuarentena automáticamente* apagado solo recibirás el aviso y el fichero se quedará donde está.

## Si no pasa nada

Casi siempre es una de estas tres causas:

1. **Falta el permiso de «Acceso total al disco»** → [cómo concederlo](permisos.md). Sin él macOS oculta la carpeta y ClamMac no ve el fichero.
2. **La carpeta no está vigilada** (o la vigilancia está desactivada) → pantalla *Vigilancia*.
3. **No hay firmas** o ClamAV no está bien instalado → pantalla *Firmas › Actualizar ahora*, y `brew install clamav`.

Más ayuda en [Problemas frecuentes](problemas.md).

## Avisos importantes

!!! warning "Si tu Mac lo gestiona una empresa"
    Un antivirus corporativo (EDR) o el departamento de informática pueden recibir una **alerta** al detectar el fichero EICAR. Es inofensivo, pero avisa antes de hacer la prueba en equipos gestionados.

- Las pruebas **1** y **2/3** no son iguales: el botón de la app no envía Pushover; si creas o descargas el fichero a mano, ClamMac lo trata como una amenaza real y **sí avisa** por todos los canales que tengas activados.
- No hace falta repetir la prueba a menudo. Es útil **tras instalar**, tras **cambiar de Mac**, y si dudas de si el permiso de disco sigue concedido.
