# Licencias y código fuente

## ClamMac

Interfaz de ClamMac: licencia **MIT**, © Ángel Bonet · ABDatabase. Los iconos derivan de la mascota de ClamAV (marca de Cisco) y no están cubiertos por la MIT.

## Relación con ClamGuard (Windows)

ClamMac nace de la idea de [ClamGuard](https://github.com/davidcasascompetenciadigital-prog/ClamGuard), de **David Casas M** ([Competencia_Digital](https://www.youtube.com/@Competencia_Digital)), publicado bajo CC BY-SA 4.0. ClamMac **no es un fork ni una obra derivada**: está escrito desde cero en Swift y no incluye código, texto ni recursos de ClamGuard, por lo que mantiene su propia licencia MIT. Son proyectos hermanos: ClamGuard para Windows, ClamMac para macOS.

## Componentes incluidos

Desde la 1.1.0 ClamMac incluye el motor antivirus **ClamAV** sin modificar, compilado de forma estática para Apple Silicon e Intel:

| Componente | Versión | Licencia |
|------------|---------|----------|
| [ClamAV](https://www.clamav.net/) | 1.5.4 | GNU GPL v2 (con excepción OpenSSL) |
| UnRAR (parte de ClamAV) | — | Licencia UnRAR: permite redistribuir, no recrear el algoritmo RAR |
| OpenSSL | 3.5.9 | Apache 2.0 |
| PCRE2 | 10.49 | BSD |
| json-c | 0.19 | MIT |

Los textos completos están dentro de la app: `ClamMac.app/Contents/Resources/Licenses/`.

## Código fuente de ClamAV (GPLv2)

El código exacto incluido es el publicado por sus autores:

- [clamav-1.5.4.tar.gz](https://github.com/Cisco-Talos/clamav/releases/download/clamav-1.5.4/clamav-1.5.4.tar.gz) — SHA-256 `1af1117a228f1b5bc7fa91a0dabc37848a99e7d25188e9be8043332ce721dfd3`

No lleva parches. Para recompilarlo igual que va en ClamMac (estático y universal) usa el script [`Engine/build_clamav.sh`](https://github.com/angelbonet/ClamMac/blob/main/Engine/build_clamav.sh) del repositorio.

## Marcas

ClamAV es marca de Cisco. ClamMac es un proyecto independiente, **no afiliado ni respaldado por Cisco ni por el proyecto ClamAV**.
