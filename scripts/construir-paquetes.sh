#!/bin/bash
# construir-paquetes.sh — Convierte las carpetas de paquetes/ en .deb reales.
#
# Hasta ahora las herramientas de RedHornoma vivían como archivos sueltos
# dentro de paquetes/. Eso obliga a copiarlas a mano en cada equipo, y copiar
# a mano es justo lo que la regla del proyecto prohíbe.
#
# Este script las empaqueta. Lo que sale de aquí es lo que declara la receta,
# lo que se publica en el repositorio y lo que instala un centro.
#
# Uso:
#   bash scripts/construir-paquetes.sh            construye
#   bash scripts/construir-paquetes.sh --instalar construye e instala aquí
#
# Construir no necesita sudo. Instalar sí.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
FUENTE="$BASE/paquetes"
SALIDA="$BASE/paquetes/deb"

INSTALAR=0
[ "${1:-}" = "--instalar" ] && INSTALAR=1

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }
ok(){  printf "   ${VE}●${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }

titulo "CONSTRUIR LOS PAQUETES DE RedHornoma"

command -v dpkg-deb >/dev/null || { mal "falta dpkg-deb (paquete dpkg-dev)"; exit 1; }

# ── El orden importa: base primero, el metapaquete al final ───────────
ORDEN=(redhornoma-base redhornoma-virtualizacion redhornoma-red
       redhornoma-respaldo redhornoma-perifericos redhornoma-panel
       redhornoma-completo)

# Avisar de carpetas que existan pero no estén en la lista, en vez de
# saltárselas en silencio.
for d in "$FUENTE"/*/; do
  n=$(basename "$d")
  [ "$n" = "deb" ] && continue
  printf '%s\n' "${ORDEN[@]}" | grep -qx "$n" || avi "«$n» no está en la lista de construcción — no se empaqueta"
done

rm -rf "$SALIDA"; mkdir -p "$SALIDA"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
HECHOS=0; FALLOS=0
declare -a CONSTRUIDOS=()

for nombre in "${ORDEN[@]}"; do
  ORIG="$FUENTE/$nombre"
  printf "\n${AZ}── %s ──${V}\n" "$nombre"

  if [ ! -f "$ORIG/DEBIAN/control" ]; then
    mal "sin DEBIAN/control"; FALLOS=$((FALLOS+1)); continue
  fi

  VERSION=$(awk -F': ' '/^Version:/{print $2}' "$ORIG/DEBIAN/control")

  # Se construye sobre una copia: así los permisos que necesita el .deb no
  # tocan el árbol de trabajo ni ensucian el repositorio de git.
  ARBOL="$TMP/$nombre"
  rm -rf "$ARBOL"; cp -a "$ORIG" "$ARBOL"

  # Permisos que dpkg espera. Sin esto lintian se queja y algunos sistemas
  # instalan los programas sin permiso de ejecución.
  find "$ARBOL" -type d -exec chmod 755 {} +
  find "$ARBOL" -type f -exec chmod 644 {} +
  [ -d "$ARBOL/usr/bin"  ] && chmod 755 "$ARBOL"/usr/bin/*
  [ -d "$ARBOL/usr/sbin" ] && chmod 755 "$ARBOL"/usr/sbin/*
  chmod 755 "$ARBOL/DEBIAN"
  for g in preinst postinst prerm postrm; do
    [ -f "$ARBOL/DEBIAN/$g" ] && chmod 755 "$ARBOL/DEBIAN/$g"
  done

  # Comprobar que los programas no tengan errores de sintaxis ANTES de
  # empaquetarlos. Un .deb que instala un script roto es peor que no tenerlo.
  ROTO=0
  for f in "$ARBOL"/usr/bin/* "$ARBOL"/usr/sbin/*; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -q '^#!.*sh' || continue
    if ! bash -n "$f" 2>/dev/null; then
      mal "$(basename "$f") tiene un error de sintaxis"; ROTO=1
    fi
  done
  [ "$ROTO" = 1 ] && { FALLOS=$((FALLOS+1)); continue; }

  DEB="$SALIDA/${nombre}_${VERSION}_all.deb"
  if dpkg-deb --root-owner-group --build "$ARBOL" "$DEB" >/dev/null 2>"$TMP/err"; then
    N=$(dpkg-deb -c "$DEB" | grep -c '^-')
    ok "$(basename "$DEB")  —  $N archivos, $(du -h "$DEB" | cut -f1)"
    CONSTRUIDOS+=("$DEB")
    HECHOS=$((HECHOS+1))
  else
    mal "no se pudo construir"; sed 's/^/      /' "$TMP/err"; FALLOS=$((FALLOS+1))
  fi
done

titulo "RESUMEN"
printf "   construidos: %s      fallidos: %s\n" "$HECHOS" "$FALLOS"
printf "   quedaron en: %s\n" "$SALIDA"

[ "$FALLOS" -gt 0 ] && exit 1

if [ "$INSTALAR" = 1 ]; then
  titulo "INSTALAR EN ESTE EQUIPO"
  if [ "$(id -u)" != 0 ]; then
    echo "   Hace falta sudo. Ejecuta:"
    printf "\n      sudo apt install %s\n\n" "$SALIDA/*.deb"
    exit 0
  fi
  # apt install resuelve las dependencias solo; dpkg -i no.
  apt install -y "${CONSTRUIDOS[@]}"
fi

exit 0
