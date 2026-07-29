#!/bin/bash
# preparar-equipo.sh — Deja este equipo listo para construir RedHornoma.
#
# Instala las herramientas que hacen falta para generar la ISO desde la receta.
# Se ejecuta UNA sola vez por equipo.
#
# Uso:
#   bash preparar-equipo.sh              → mira e informa, no toca nada
#   sudo bash preparar-equipo.sh --aplicar
set -u

APLICAR=0
[ "${1:-}" = "--aplicar" ] && APLICAR=1

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }

# Lo que hace falta para construir la ISO
NECESARIO="live-build debootstrap squashfs-tools xorriso isolinux syslinux-common \
grub-pc-bin grub-efi-amd64-bin mtools dosfstools rsync ca-certificates \
dpkg-dev apt-utils gnupg"

titulo "PREPARAR ESTE EQUIPO PARA CONSTRUIR RedHornoma"
if [ "$APLICAR" = "1" ]; then
  printf "   Modo: ${RO}INSTALANDO${V}\n"
  [ "$(id -u)" != "0" ] && { mal "para instalar hace falta sudo"; exit 1; }
else
  printf "   Modo: ${VE}solo mirar${V}\n"
fi

# ── Sistema base ──────────────────────────────────────────────────────
titulo "1 · ESTE EQUIPO"

DEB=$(cat /etc/debian_version 2>/dev/null)
printf "   %-24s %s\n" "Debian:" "${DEB:-desconocido}"
printf "   %-24s %s\n" "Arquitectura:" "$(dpkg --print-architecture)"

case "$DEB" in
  13*) ok "Debian 13 — es la base de RedHornoma" ;;
  *)   avi "RedHornoma se construye sobre Debian 13. Aquí hay: ${DEB:-?}"
       echo "      Puede funcionar igual, pero no está probado." ;;
esac

LIBRE=$(df -BG --output=avail /home | tail -1 | tr -dc '0-9')
printf "   %-24s %s GB libres\n" "Espacio en /home:" "$LIBRE"
if [ "${LIBRE:-0}" -lt 30 ]; then
  mal "hacen falta al menos 30 GB para construir la ISO"
  echo "      Libera espacio antes de seguir."
  [ "$APLICAR" = "1" ] && exit 1
else
  ok "espacio suficiente"
fi

# ── Herramientas ──────────────────────────────────────────────────────
titulo "2 · HERRAMIENTAS DE CONSTRUCCIÓN"

FALTAN=""
for p in $NECESARIO; do
  if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then
    printf "   ${VE}●${V} %s\n" "$p"
  else
    printf "   ${AM}○${V} %s\n" "$p"
    FALTAN="$FALTAN $p"
  fi
done

echo
if [ -z "$FALTAN" ]; then
  ok "no falta ninguna herramienta"
else
  N=$(echo $FALTAN | wc -w)
  avi "faltan $N herramientas"
fi

# ── Internet ──────────────────────────────────────────────────────────
titulo "3 · CONEXIÓN"

if timeout 8 getent hosts deb.debian.org >/dev/null 2>&1; then
  ok "se alcanza el archivo de Debian"
else
  mal "no se llega a deb.debian.org"
  echo "      Construir la ISO descarga unos 3 GB. Hace falta internet."
fi

# ── Aplicar ───────────────────────────────────────────────────────────
if [ "$APLICAR" = "0" ]; then
  titulo "PARA INSTALARLO"
  if [ -z "$FALTAN" ]; then
    printf "   ${VE}Este equipo ya está listo. No hay nada que hacer.${V}\n"
    echo
    echo "   Siguiente paso:"
    printf "      ${AZ}sudo bash scripts/construir-iso.sh${V}\n"
  else
    echo "   Ejecuta lo mismo añadiendo --aplicar:"
    echo
    printf "      ${AZ}sudo bash %s --aplicar${V}\n" "$0"
    echo
    echo "   Descargará unos 200 MB de herramientas."
  fi
  exit 0
fi

titulo "4 · INSTALANDO"

if [ -z "$FALTAN" ]; then
  ok "no hacía falta instalar nada"
else
  echo "   Actualizando la lista de paquetes…"
  apt-get update -qq || { mal "no se pudo actualizar la lista"; exit 1; }
  echo
  echo "   Instalando:$FALTAN"
  echo
  if apt-get install -y $FALTAN; then
    echo
    ok "herramientas instaladas"
  else
    mal "falló la instalación"
    exit 1
  fi
fi

titulo "✅ EQUIPO LISTO"
cat <<FIN

   Ya puedes construir la ISO de RedHornoma:

      ${AZ}sudo bash scripts/construir-iso.sh${V}

   Tarda entre 40 y 90 minutos y descarga unos 3 GB.

FIN
