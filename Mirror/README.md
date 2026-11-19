# Espejo de firmas de ClamAV (`https://clamav.abdatabase.com`)

Sirve `main/daily/bytecode.cvd` (+ `.sign` y `cdiff`) descargados con [`cvdupdate`](https://github.com/Cisco-Talos/cvdupdate),
la herramienta oficial de ClamAV para espejos privados. ClamMac ≥ 1.2.1 usa `PrivateMirror` y, si falla, el CDN oficial.

**Por qué:** el CDN de ClamAV limita por IP (429/403 + «cool-down» de horas). Varios Macs de una clínica instalando a la vez
(~300 MB cada uno) agotan el límite (incidencia Lorente, 2026-11-19). Con el espejo, el CDN solo ve una petición por hora: la del VPS.

> `tools.abdatabase.com` es solo la etiqueta del VPS: **no es un nombre DNS**. El espejo vive en un subdominio propio para no tocar los vhosts de xort ni de la firma.

## Instalar (lo ejecuta Ángel, con sudo, en el VPS Arsys)
0. DNS: registro **A** `clamav.abdatabase.com` → `94.143.142.237` (comprobar: `dig +short clamav.abdatabase.com`).
```
scp Mirror/deploy_mirror.sh <usuario>@94.143.142.237:/tmp/
ssh <usuario>@94.143.142.237 'sudo bash /tmp/deploy_mirror.sh'     # una sola conexión SSH (fail2ban)
```
Vhost propio + certificado Let's Encrypt, `nginx -t`, marcha atrás automática (retira el vhost si algo falla) y verificación (HTTP 200, tamaño, POST rechazado).
Quitar: `sudo bash deploy_mirror.sh --uninstall`. No toca xort ni la firma.

## Probar desde cualquier Mac con ClamMac
```
H=/Applications/ClamMac.app/Contents/Helpers; D=$(mktemp -d)
printf 'DatabaseDirectory %s\nPrivateMirror https://clamav.abdatabase.com\nDNSDatabaseInfo no\n' "$D" > $D/fc.conf
$H/freshclam --config-file=$D/fc.conf --cvdcertsdir=/Applications/ClamMac.app/Contents/Resources/certs
```
Debe terminar con `main.cvd updated`, `daily.cvd updated`, `bytecode.cvd updated` (firmas verificadas con el certificado de ClamAV).

## Operación
- `systemctl list-timers clamav-mirror.timer` · `journalctl -u clamav-mirror.service -n 30`
- Datos: `/var/lib/clamav-mirror/db` (~300 MB). Si `daily.cvd` lleva > 2 días sin cambiar, algo falla.
- No subir la frecuencia por encima de 1 vez/hora: el CDN oficial también limitaría al VPS.
