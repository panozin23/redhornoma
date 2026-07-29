#!/bin/bash
# limpiar-construccion.sh — Borra los restos que deja construir la ISO.
#
# Cada construcción deja unos 12 GB de archivos temporales. Las ISOs
# generadas NO se tocan nunca: están en isos/ y se quedan ahí.
#
# Uso:
#   bash limpiar-construccion.sh              → mira e informa
#   sudo bash limpiar-construccion.sh --aplicar
#
# Guardar la caché (--guardar-cache) hace que la siguiente construcción
# sea mucho más rápida, porque no vuelve a descargar los 3 GB.
set -u

APLICAR=0; GUARDAR_CACHE=0
for a in "$@"; do
  [ "$a" = "--aplicar" ] && APLICAR=1
  [ "$a" = "--guardar-cache" ] && GUARDAR_CACHE=1
done

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RECETA="$BASE/receta"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "${AZ} LIMPIAR LOS RESTOS DE LA CONSTRUCCIÓN${V}\n"
printf "${AZ}══════════════════════════════════════════════════════${V}\n\n"

printf "   Disco: %s\n\n" "$(df -h "$BASE" | tail -1 | awk '{print $4" libres de "$2}')"

# ── Qué hay ───────────────────────────────────────────────────────────
TOTAL=0
mostrar(){
  local ruta="$1" desc="$2" quitar="$3"
  [ -e "$ruta" ] || return
  local kb; kb=$(du -sk "$ruta" 2>/dev/null | cut -f1)
  TOTAL=$((TOTAL + kb))
  if [ "$quitar" = "si" ]; then
    printf "   ${AM}○${V} %-14s %8s   %s\n" "$(basename "$ruta")" "$(du -sh "$ruta" 2>/dev/null | cut -f1)" "$desc"
  else
    printf "   ${VE}●${V} %-14s %8s   %s\n" "$(basename "$ruta")" "$(du -sh "$ruta" 2>/dev/null | cut -f1)" "$desc"
  fi
}

echo "   Lo que se borra:"
mostrar "$RECETA/chroot"  "el sistema a medio construir" si
mostrar "$RECETA/binary"  "los archivos de la imagen"    si
mostrar "$RECETA/.build"  "marcas de las etapas"         si
[ "$GUARDAR_CACHE" = "0" ] && mostrar "$RECETA/cache" "los paquetes descargados" si

echo
echo "   Lo que NO se toca:"
mostrar "$BASE/isos" "las ISOs generadas" no
[ "$GUARDAR_CACHE" = "1" ] && mostrar "$RECETA/cache" "los paquetes descargados (se guardan)" no
mostrar "$RECETA/config" "la receta" no

LIBERA=$(( TOTAL / 1024 / 1024 ))
echo
printf "   ${AZ}Se liberarían unos %s GB${V}\n" "$LIBERA"

if [ "$APLICAR" = "0" ]; then
  cat <<FIN

   ${AZ}Para hacerlo:${V}

      sudo bash $0 --aplicar

   ${AZ}Guardando los paquetes descargados${V} (la próxima construcción
   tarda la mitad, pero se liberan 2 GB menos):

      sudo bash $0 --aplicar --guardar-cache

FIN
  exit 0
fi

[ "$(id -u)" = "0" ] || { printf "   ${RO}❌${V} hace falta sudo\n"; exit 1; }

echo
rm -rf "$RECETA/chroot" "$RECETA/binary" "$RECETA/.build"
[ "$GUARDAR_CACHE" = "0" ] && rm -rf "$RECETA/cache"
printf "   ${VE}✅${V} limpio\n"
printf "   Disco ahora: %s\n\n" "$(df -h "$BASE" | tail -1 | awk '{print $4" libres de "$2}')"
