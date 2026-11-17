# Permisos

## Acceso total al disco (imprescindible)

!!! warning "Sin este permiso ClamMac no protege de verdad"
    macOS protege carpetas como **Descargas, Escritorio y Documentos** y no deja que las apps las lean sin permiso. Si falta, el análisis se salta esos ficheros **sin dar ningún error**: parece que todo está bien, pero no se ha revisado nada. Por eso ClamMac comprueba el permiso y lo avisa.

Solo hay que concederlo **una vez**:

1. Abre **Ajustes del Sistema › Privacidad y seguridad › Acceso total al disco**.
2. Si **ClamMac** aparece en la lista, **activa el interruptor**. Si no aparece, pulsa **`+`**, elige **ClamMac** en *Aplicaciones* y pulsa *Abrir*.
3. macOS pedirá tu **contraseña o Touch ID**.
4. Si propone *«Salir y reabrir»*, acepta. Si no, cierra ClamMac (menú del escudo › *Salir*) y ábrela de nuevo.

Acceso directo a esa pantalla: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`

### Cómo comprobar que funciona

En la ventana de ClamMac, pantalla **Estado**: **no debe aparecer** el aviso naranja *«Falta Acceso total al disco»*.

### Al actualizar ClamMac

Como la app va firmada siempre con el mismo certificado, el permiso **se conserva** al actualizar. Si macOS lo pidiera de nuevo, el aviso naranja lo indicará.

## Notificaciones

La primera vez, macOS pregunta si ClamMac puede enviar notificaciones. Acepta si quieres enterarte de las amenazas y de las actualizaciones. Puedes cambiarlo en **Ajustes del Sistema › Notificaciones › ClamMac**, y en la app (*Ajustes › Notificaciones del sistema*).

## Abrir al iniciar sesión

Se activa desde la propia app (*Ajustes › Abrir ClamMac al iniciar sesión*). macOS puede mostrar un aviso de «elemento de inicio añadido».

## Lo que ClamMac **no** pide

- No pide acceso a la cámara, el micrófono, la ubicación ni los contactos.
- No pide permisos de administrador ni instala nada con privilegios.
