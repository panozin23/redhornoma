#!/bin/bash
# instalar-tailscale.sh — Unir esta máquina al enlace entre centros.
#
# Sirve para las tres: el portátil, el servidor de Hornoma y el de Cochabamba.
# El plan completo y el porqué están en documentacion/UNIR-LOS-CENTROS.md.
#
# Por qué el repositorio y no el «curl | sh» que recomienda Tailscale:
#
#   Ese guion se descarga y se ejecuta sin que nadie lo lea. Aquí se añade el
#   repositorio firmado y se instala con apt, como cualquier otro paquete: se
#   puede declarar en la receta, se actualiza solo con el resto del sistema, y
#   se ve qué versión hay puesta. Es la misma decisión que se tomó con el
#   repositorio propio de RedHornoma.
#
# Uso:  sudo bash instalar-tailscale.sh --nombre respaldo-hornoma
set -u

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }

NOMBRE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --nombre) NOMBRE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "No entiendo «$1»"; exit 1 ;;
  esac
done

[ "$(id -u)" = "0" ] || { echo "Hace falta administrador:  sudo bash $0 --nombre NOMBRE"; exit 1; }
[ -n "$NOMBRE" ] || NOMBRE=$(cat /proc/sys/kernel/hostname 2>/dev/null)

titulo "UNIR ESTA MÁQUINA AL ENLACE ENTRE CENTROS"
nota "esta máquina se llamará «$NOMBRE» en el enlace"

# ── 1 · De qué Debian se trata ────────────────────────────────────────
# El repositorio de Tailscale va por versión de Debian, así que hay que
# acertar con el nombre.
#
# Y aquí hay una trampa que se vio el 11/08/2026: el portátil NO dice
# «trixie», dice «moderna», porque cursalialinux se pone su propio nombre:
#
#     portatil   ID=cursalialinux   VERSION_CODENAME=moderna
#     .101       ID=debian          VERSION_CODENAME=trixie
#
# Pidiendo «.../debian/moderna.noarmor.gpg» no hay nada. Lo que no miente en
# ninguna de las dos es /etc/debian_version, que dice 13.6 en las dos: de ahí
# se saca el nombre de verdad.
NUM=$(cut -d. -f1 /etc/debian_version 2>/dev/null)
case "$NUM" in
  13) CODIGO=trixie ;;
  12) CODIGO=bookworm ;;
  11) CODIGO=bullseye ;;
  *)  # Sistemas que sí dicen la verdad, y los futuros
      CODIGO=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}") ;;
esac
[ -n "$CODIGO" ] || { mal "no sé sobre qué Debian está montado esto"; exit 1; }
ok "montado sobre Debian $NUM ($CODIGO)"

# Que exista de verdad, antes de escribir nada en el sistema.
printf "   %-32s " "el repositorio existe"
if wget -q --spider "https://pkgs.tailscale.com/stable/debian/dists/$CODIGO/Release" 2>/dev/null \
   || curl -fsI "https://pkgs.tailscale.com/stable/debian/dists/$CODIGO/Release" >/dev/null 2>&1; then
  printf "${VE}sí${V}\n"
else
  printf "${RO}NO${V}\n"
  mal "Tailscale no publica paquetes para «$CODIGO»"
  exit 1
fi

# ── 2 · Bajar con lo que haya ─────────────────────────────────────────
# En el portátil no está curl —lo mismo que pasó el 08/08 al comprobar el
# repositorio— así que se usa lo que exista.
bajar(){  # url  destino
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  else wget -qO "$2" "$1"; fi
}

printf "\n   ${AZ}Añadiendo el repositorio${V}\n"
printf "   %-32s " "la llave que lo firma"
if bajar "https://pkgs.tailscale.com/stable/debian/$CODIGO.noarmor.gpg" \
         /usr/share/keyrings/tailscale-archive-keyring.gpg; then
  printf "${VE}puesta${V}\n"
else
  printf "${RO}falló${V}\n"; mal "sin llave no se puede instalar nada firmado"; exit 1
fi

printf "   %-32s " "la dirección del repositorio"
if bajar "https://pkgs.tailscale.com/stable/debian/$CODIGO.tailscale-keyring.list" \
         /etc/apt/sources.list.d/tailscale.list; then
  printf "${VE}puesta${V}\n"
else
  printf "${RO}falló${V}\n"; exit 1
fi

# ── 3 · Instalar ──────────────────────────────────────────────────────
# La salida NO se esconde.
#
# La primera versión llevaba «-qq» y «>/dev/null», y por internet rural bajar
# los 30 MB tarda varios minutos: la pantalla se queda muda y parece colgada.
# euflo lo vivió el 11/08/2026 y tuvo que preguntar si se había trabado.
#
# Una barra que avanza despacio tranquiliza; una pantalla muda, no. Y es el
# mismo error de esconder salidas que este proyecto lleva corrigiendo desde el
# 09/08.
printf "\n   ${AZ}Instalando${V}\n"
nota "son unos 30 MB — por internet rural puede tardar varios minutos"
nota "si ves que no avanza, dale tiempo: está bajando"
echo

apt-get update 2>&1 | grep -viE "^Get:|^Hit:|^Obj:|^Des:" | sed 's/^/      /'
if apt-get install -y tailscale 2>&1 | sed 's/^/      /'; then
  echo
  ok "tailscale $(tailscale version 2>/dev/null | head -1)"
else
  mal "no se pudo instalar"
  exit 1
fi

systemctl enable --now tailscaled >/dev/null 2>&1
printf "   %-32s " "el servicio en marcha"
systemctl is-active tailscaled >/dev/null 2>&1 && printf "${VE}sí${V}\n" || { printf "${RO}no${V}\n"; exit 1; }

# ── 4 · Unirse ────────────────────────────────────────────────────────
titulo "AHORA HAY QUE AUTORIZARLA"
cat <<FIN

   Abajo va a salir una dirección web. Ábrela en un navegador —da igual en
   qué computadora— y entra con la cuenta del proyecto.

   ${AM}Usa SIEMPRE la misma cuenta en las tres máquinas${V}, o no se verán entre ellas.

FIN

tailscale up --hostname="$NOMBRE" --accept-routes

# ── 5 · Comprobar de verdad ───────────────────────────────────────────
titulo "COMPROBACIÓN"
DIR=$(tailscale ip -4 2>/dev/null | head -1)
if [ -n "$DIR" ]; then
  ok "esta máquina es «$NOMBRE» y su dirección en el enlace es $DIR"
else
  mal "no consiguió unirse — vuelve a lanzar:  sudo tailscale up"
  exit 1
fi

echo
tailscale status 2>/dev/null | sed 's/^/   /'

titulo "⚠️  LO ÚLTIMO, Y ES IMPORTANTE"
cat <<FIN

   Tailscale CADUCA las llaves de cada máquina a los seis meses, y cuando
   pasa, la máquina se cae del enlace ${AM}sin avisar a nadie${V}.

   Un servidor de un centro rural no tiene quien lo note. Es exactamente el
   tipo de fallo callado que este proyecto lleva todo el año persiguiendo.

   Entra en  ${AZ}https://login.tailscale.com/admin/machines${V}
   busca «$NOMBRE», y en sus tres puntos elige:

       ${VE}Disable key expiry${V}

   Hazlo en los SERVIDORES sin falta. En el portátil da igual, porque ahí
   siempre hay alguien delante para volver a entrar.

FIN
