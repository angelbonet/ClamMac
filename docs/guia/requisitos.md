# Requisitos del sistema

!!! warning "Antes de descargar: comprueba tu Mac"
    ClamMac necesita **macOS 13 (Ventura) o posterior**. En un Mac con una versión anterior (Monterey, Big Sur, Catalina…) **no se puede abrir**: verás el icono de «prohibido» sobre la app o un aviso de que necesitas una versión más reciente de macOS.

## Mínimos

| | Mínimo | Recomendado |
|---|---|---|
| **macOS** | **13 Ventura** | 14 Sonoma o posterior |
| **Mac** | Apple Silicon (M1 o posterior), o Intel compatible con Ventura (abajo) | — |
| **Espacio en disco** | ~500 MB (la app ocupa unos 150 MB y las firmas de virus 200-300 MB) | 1 GB libre |
| **Memoria (RAM)** | 4 GB | 8 GB o más (orientativo: el motor carga las firmas en memoria) |
| **Internet** | Para descargar las firmas (la primera vez ~300 MB) y actualizar | — |
| **Permisos** | *Acceso total al disco* (se concede una vez: [cómo](permisos.md)) | — |

No necesitas instalar nada más: el motor antivirus **ClamAV va incluido** (ver [Instalación](instalacion.md)).

## ¿Mi Mac es compatible con macOS 13?

Son compatibles con Ventura:

- **Todos los Mac con chip Apple Silicon** (M1, M2, M3, M4…).
- **Mac Intel** de estos modelos o posteriores: iMac (2017), iMac Pro (2017), MacBook (2017), MacBook Air (2018), MacBook Pro (2017), Mac mini (2018), Mac Pro (2019).

**No son compatibles** (su último macOS es anterior), por ejemplo: Mac mini de 2014 o anteriores, MacBook Pro de 2015 o 2016, MacBook Air de 2017 o anteriores, iMac de 2016 o anteriores.

## Cómo comprobarlo en 10 segundos

 menú Apple → **Acerca de este Mac**:

- Si pone **macOS Ventura 13 o más** → ClamMac funciona.
- Si pone otra cosa (Monterey, Big Sur, Catalina, Mojave…) → no es compatible. Si el Mac admite una actualización a Ventura o posterior (*Ajustes del Sistema → General → Actualización de software*), puedes actualizar.

## Mi Mac es demasiado antiguo, ¿qué hago?

ClamMac no puede ejecutarse en esos equipos, y tampoco hay una versión para ellos: la interfaz usa tecnologías de macOS 13 o posterior. Si el Mac no se puede actualizar, no es posible usar ClamMac en él.

## Procesador: Apple Silicon e Intel

Es **una sola app universal**: el mismo DMG sirve para los dos tipos de Mac y macOS usa la parte que corresponde. No hay que elegir nada.
