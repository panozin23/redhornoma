#!/bin/bash
# copia-cruzada.sh — Que cada centro guarde el respaldo del otro.
#
# Hoy el respaldo de un centro vive en el mismo edificio que la información
# que protege. Un incendio, un robo o un rayo se lleva las dos cosas a la vez.
# Con esto, cada centro guarda una copia del otro — y sale gratis, porque
# aprovecha el enlace de documentacion/UNIR-LOS-CENTROS.md.
#
# ── La decisión de seguridad, que es lo importante de este guion ──────
#
# Lo fácil sería una llave de administrador de un centro hacia el otro. Eso
# sería un error: esa llave podría LEER todo el otro centro, y si alguien se
# lleva un servidor tendría acceso completo al otro.
#
# Aquí la llave queda encerrada con «rrsync -wo»:
#
#     · solo puede ESCRIBIR, nunca leer
#     · solo dentro de UNA carpeta
#     · no abre sesión, ni túneles, ni nada más
#
# Cada centro protege al otro sin poder espiarlo.
#
# ── Uso, en dos pasos por servidor ────────────────────────────────────
#
#   sudo bash copia-cruzada.sh --paso1 --yo hornoma
#       crea la llave del administrador, prepara la carpeta donde recibir,
#       y ENSEÑA la llave pública para dársela al otro centro
#
#   sudo bash copia-cruzada.sh --paso2 --otro cochabamba \
#        --llave "ssh-ed25519 AAAA…" --destino flora@100.74.174.70
#       autoriza la llave del otro (encerrada) y apunta hacia allá
set -u

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }

PASO=""; YO=""; OTRO=""; LLAVE=""; DESTINO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --paso1)   PASO=1; shift ;;
    --paso2)   PASO=2; shift ;;
    --yo)      YO="${2:-}"; shift 2 ;;
    --otro)    OTRO="${2:-}"; shift 2 ;;
    --llave)   LLAVE="${2:-}"; shift 2 ;;
    --destino) DESTINO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "No entiendo «$1»"; exit 1 ;;
  esac
done

[ "$(id -u)" = "0" ] || { echo "Hace falta administrador:  sudo bash $0 …"; exit 1; }

RECIBIDOS=/var/lib/redhornoma/recibidos
CONF=/var/lib/redhornoma/respaldo.conf
# El usuario con el que entra el otro centro: el humano de esta máquina, no
# root. Así la llave del otro nunca tiene poder de administrador aquí.
USUARIO=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)

# ══ PASO 1 ════════════════════════════════════════════════════════════
if [ "$PASO" = "1" ]; then
  [ -n "$YO" ] || { mal "falta --yo NOMBRE-DE-ESTE-CENTRO"; exit 1; }
  titulo "PASO 1 · PREPARAR ESTE CENTRO ($YO)"

  # La llave del administrador, que es quien hace el respaldo.
  if [ ! -f /root/.ssh/id_ed25519 ]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    ssh-keygen -q -t ed25519 -N "" -C "respaldo-$YO" -f /root/.ssh/id_ed25519
    ok "llave del administrador creada"
  else
    nota "el administrador ya tenía llave, se conserva"
  fi

  # Dónde se reciben los respaldos del otro centro.
  mkdir -p "$RECIBIDOS"
  chown "$USUARIO":"$USUARIO" "$RECIBIDOS" 2>/dev/null
  chmod 750 "$RECIBIDOS"
  ok "carpeta para recibir: $RECIBIDOS  (de $USUARIO)"

  titulo "DÁSELE ESTA LLAVE AL OTRO CENTRO"
  echo
  cat /root/.ssh/id_ed25519.pub
  echo
  nota "es una llave PÚBLICA: se puede mandar por WhatsApp sin problema"
  nota "la privada se queda aquí y no sale nunca"
  echo
  exit 0
fi

# ══ PASO 2 ════════════════════════════════════════════════════════════
if [ "$PASO" = "2" ]; then
  [ -n "$OTRO" ]   || { mal "falta --otro NOMBRE-DEL-OTRO-CENTRO"; exit 1; }
  [ -n "$LLAVE" ]  || { mal "falta --llave \"ssh-ed25519 …\""; exit 1; }
  [ -n "$DESTINO" ]|| { mal "falta --destino usuario@direccion"; exit 1; }
  titulo "PASO 2 · AUTORIZAR A $OTRO Y APUNTAR HACIA ALLÁ"

  CARPETA="$RECIBIDOS/$OTRO"
  mkdir -p "$CARPETA"
  chown -R "$USUARIO":"$USUARIO" "$RECIBIDOS"
  ok "los respaldos de $OTRO llegarán a $CARPETA"

  # ── La llave, encerrada ──────────────────────────────────────────────
  # «command=» obliga a que esa llave SOLO pueda ejecutar rrsync, y «-wo»
  # deja rrsync en modo escritura dentro de esa carpeta. Aunque alguien se
  # lleve la llave, con ella no puede leer nada de este centro.
  AUTH="/home/$USUARIO/.ssh/authorized_keys"
  mkdir -p "/home/$USUARIO/.ssh"; chmod 700 "/home/$USUARIO/.ssh"
  touch "$AUTH"; chmod 600 "$AUTH"

  RRSYNC=$(command -v rrsync || echo /usr/share/rsync/scripts/rrsync)
  [ -x "$RRSYNC" ] || { mal "no encuentro rrsync, que es lo que encierra la llave"; exit 1; }

  # Se quita una autorización anterior del mismo centro, para no acumular.
  grep -v "respaldo-$OTRO" "$AUTH" > "$AUTH.nuevo" 2>/dev/null || true
  printf 'command="%s -wo %s",restrict %s\n' "$RRSYNC" "$CARPETA" "$LLAVE" >> "$AUTH.nuevo"
  mv "$AUTH.nuevo" "$AUTH"
  chown "$USUARIO":"$USUARIO" "$AUTH"; chmod 600 "$AUTH"
  ok "llave de $OTRO autorizada — solo puede DEPOSITAR en esa carpeta"

  # ── Apuntar el respaldo hacia el otro centro ────────────────────────
  touch "$CONF"
  grep -v "^otra_computadora=" "$CONF" > "$CONF.nuevo" 2>/dev/null || true
  printf 'otra_computadora=%s:/\n' "$DESTINO" >> "$CONF.nuevo"
  mv "$CONF.nuevo" "$CONF"
  ok "a partir de ahora este centro copiará su respaldo a $DESTINO"
  nota "la ruta va como «/» porque rrsync ya encierra el destino"

  titulo "COMPROBACIÓN"
  printf "   %-34s " "¿se llega al otro centro?"
  if timeout 20 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
       -o ConnectTimeout=10 "${DESTINO%%:*}" true 2>/dev/null; then
    printf "${VE}sí${V}\n"
  else
    printf "${AM}todavía no${V}\n"
    nota "normal si el otro centro aún no ha hecho su paso 2"
  fi

  echo
  nota "la próxima vez que se respalde, la copia viajará sola"
  nota "para probarlo ya:  sudo redhornoma-respaldo --ahora"
  echo
  exit 0
fi

mal "dime qué paso: --paso1 o --paso2"
echo "      $0 --help  para ver cómo"
exit 1
