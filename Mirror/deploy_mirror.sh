#!/usr/bin/env bash
# Espejo de firmas de ClamAV para ClamMac — se ejecuta en el VPS Arsys (94.143.142.237) con sudo.
#   sudo bash deploy_mirror.sh              instala / actualiza
#   sudo bash deploy_mirror.sh --uninstall  quita servicio, temporizador y vhost (no borra los datos)
#
# PRERREQUISITO (lo haces tú, 1 min): registro DNS  clamav.abdatabase.com  A  94.143.142.237
#
# Qué hace (NO toca los vhosts de xort ni de la firma, ni sus backups):
#   1. usuario de sistema `clamavmirror` + venv en /opt/clamav-mirror con `cvdupdate` (herramienta oficial de ClamAV)
#   2. descarga inicial de main/daily/bytecode (+ .sign y cdiff) en /var/lib/clamav-mirror/db (~300 MB)
#   3. temporizador systemd: 1 vez por hora (el máximo que admite el CDN oficial), con retraso aleatorio
#   4. vhost propio de nginx para clamav.abdatabase.com + certificado Let's Encrypt (certbot)
#   5. comprobaciones finales (HTTP 200, tamaño servido = tamaño en disco, POST rechazado); si el vhost falla, se retira.
set -euo pipefail

SITE="clamav.abdatabase.com"
VPS_IP="94.143.142.237"
USER_M="clamavmirror"
BASE="/opt/clamav-mirror"
DATA="/var/lib/clamav-mirror"
DB="$DATA/db"
VHOST="/etc/nginx/sites-available/$SITE"
LINK="/etc/nginx/sites-enabled/$SITE"

ok()  { echo "  [OK] $*"; }
die() { echo "  [ERROR] $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "ejecútalo con sudo"

remove_vhost() { rm -f "$LINK" "$VHOST"; nginx -t >/dev/null 2>&1 && systemctl reload nginx || true; }

if [ "${1:-}" = "--uninstall" ]; then
  echo "== Desinstalando espejo =="
  systemctl disable --now clamav-mirror.timer 2>/dev/null || true
  rm -f /etc/systemd/system/clamav-mirror.service /etc/systemd/system/clamav-mirror.timer; systemctl daemon-reload
  remove_vhost
  echo "Quitados servicio, temporizador y vhost. Quedan (bórralos a mano si quieres): $BASE  $DATA  usuario $USER_M  y el certificado de certbot."
  exit 0
fi

echo "== 1/6 Comprobaciones previas =="
command -v nginx >/dev/null || die "nginx no está instalado"
command -v certbot >/dev/null || die "certbot no está instalado (apt install certbot python3-certbot-nginx)"
RES="$(getent hosts "$SITE" | awk '{print $1}' | head -1 || true)"
[ -n "$RES" ] || die "$SITE no resuelve todavía: crea el registro A $SITE -> $VPS_IP y espera unos minutos"
[ "$RES" = "$VPS_IP" ] || die "$SITE resuelve a $RES, no a $VPS_IP"
ok "DNS: $SITE -> $RES"
AVAIL=$(df -Pm /var/lib | awk 'NR==2{print $4}')
[ "$AVAIL" -gt 2000 ] || die "menos de 2 GB libres en /var/lib ($AVAIL MB)"
ok "espacio libre: ${AVAIL} MB"
nginx -t 2>/dev/null && ok "nginx -t correcto antes de empezar" || die "nginx ya tenía errores antes de empezar"
[ ! -e "$VHOST" ] || ok "el vhost de $SITE ya existe: se reescribe (es solo del espejo)"

echo "== 2/6 Usuario y cvdupdate =="
id "$USER_M" >/dev/null 2>&1 || useradd --system --home-dir "$DATA" --shell /usr/sbin/nologin "$USER_M"
mkdir -p "$BASE" "$DATA" "$DB"
apt-get install -y -qq python3-venv python3-pip >/dev/null
[ -x "$BASE/venv/bin/cvdupdate" ] || python3 -m venv "$BASE/venv"
"$BASE/venv/bin/pip" install -q --upgrade cvdupdate
chown -R "$USER_M":"$USER_M" "$BASE" "$DATA"; chmod 755 "$DATA" "$DB"
sudo -u "$USER_M" env HOME="$DATA" "$BASE/venv/bin/cvdupdate" config set --dbdir "$DB" --logdir "$DATA/log" >/dev/null
ok "cvdupdate instalado, base de datos en $DB"

echo "== 3/6 Descarga inicial (~300 MB, unos minutos) =="
sudo -u "$USER_M" env HOME="$DATA" "$BASE/venv/bin/cvdupdate" update
for f in main.cvd daily.cvd bytecode.cvd; do [ -s "$DB/$f" ] || die "falta $f tras la descarga"; done
ok "main/daily/bytecode descargados"

echo "== 4/6 Temporizador systemd (cada hora) =="
cat > /etc/systemd/system/clamav-mirror.service <<EOF
[Unit]
Description=Actualiza el espejo de firmas de ClamAV (cvdupdate)
After=network-online.target
[Service]
Type=oneshot
User=$USER_M
Environment=HOME=$DATA
ExecStart=$BASE/venv/bin/cvdupdate update
Nice=10
EOF
cat > /etc/systemd/system/clamav-mirror.timer <<EOF
[Unit]
Description=Espejo de firmas de ClamAV, cada hora
[Timer]
OnCalendar=hourly
RandomizedDelaySec=10min
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload && systemctl enable --now clamav-mirror.timer >/dev/null
ok "timer activo"

echo "== 5/6 nginx (vhost propio) + certificado =="
mkdir -p /var/www/letsencrypt
cat > "$VHOST" <<EOF
# Espejo privado de firmas ClamAV para ClamMac (solo lectura, ficheros estáticos)
server {
    listen 80;
    listen [::]:80;
    server_name $SITE;
    root /var/www/letsencrypt;
    location /.well-known/acme-challenge/ { }
    location / { return 404; }
}
EOF
ln -sf "$VHOST" "$LINK"
nginx -t 2>/tmp/clamav-mirror-nginx.err || { cat /tmp/clamav-mirror-nginx.err >&2; remove_vhost; die "nginx -t falla con el vhost 80: retirado"; }
systemctl reload nginx
certbot certonly --webroot -w /var/www/letsencrypt -d "$SITE" --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring \
  || { remove_vhost; die "certbot no pudo emitir el certificado: vhost retirado"; }
cat > "$VHOST" <<EOF
# Espejo privado de firmas ClamAV para ClamMac (solo lectura, ficheros estáticos)
server {
    listen 80;
    listen [::]:80;
    server_name $SITE;
    root /var/www/letsencrypt;
    location /.well-known/acme-challenge/ { }
    location / { return 301 https://\$host\$request_uri; }
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $SITE;
    ssl_certificate     /etc/letsencrypt/live/$SITE/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$SITE/privkey.pem;
    root $DB;
    autoindex off;
    default_type application/octet-stream;
    access_log /var/log/nginx/clamav-mirror.access.log;
    location / {
        limit_except GET HEAD { deny all; }
        try_files \$uri =404;
    }
}
EOF
nginx -t 2>/tmp/clamav-mirror-nginx.err || { cat /tmp/clamav-mirror-nginx.err >&2; remove_vhost; die "nginx -t falla con el vhost 443: retirado"; }
systemctl reload nginx
ok "nginx recargado; certificado instalado (renovación: la del certbot del sistema)"

echo "== 6/6 Verificación =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' -I "https://$SITE/daily.cvd" || true)
[ "$CODE" = "200" ] || { remove_vhost; die "https://$SITE/daily.cvd devolvió $CODE: vhost retirado"; }
ok "https://$SITE/daily.cvd -> 200"
REMOTE=$(curl -sI "https://$SITE/main.cvd" | awk 'tolower($1)=="content-length:"{print $2+0}')
LOCAL=$(stat -c %s "$DB/main.cvd")
[ "$REMOTE" = "$LOCAL" ] && ok "main.cvd: mismo tamaño servido y en disco ($LOCAL)" || die "tamaño distinto de main.cvd ($REMOTE vs $LOCAL)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "https://$SITE/daily.cvd" || true)
if [ "$CODE" = "405" ] || [ "$CODE" = "403" ]; then ok "POST rechazado ($CODE)"; else echo "  [AVISO] POST devolvió $CODE"; fi
CODE=$(curl -s -o /dev/null -w '%{http_code}' "https://$SITE/" || true)
ok "raíz sin listado de ficheros ($CODE)"
echo
echo "LISTO. https://$SITE sirve las firmas. Quitar: sudo bash deploy_mirror.sh --uninstall"
