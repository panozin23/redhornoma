#!/bin/bash
# comprobar-receta.sh — Verifica la receta ANTES de construir.
#
# Construir la ISO tarda una hora y descarga 3 GB. Un solo nombre de paquete
# mal escrito la hace fallar al final. Esto lo comprueba en veinte segundos.
#
# Uso:  bash comprobar-receta.sh
#
# No necesita sudo.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
LISTAS="$BASE/receta/config/package-lists"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

titulo "COMPROBAR LA RECETA DE RedHornoma"

[ -d "$LISTAS" ] || { printf "   ${RO}❌${V} no encuentro %s\n" "$LISTAS"; exit 1; }

# ── ¿Podemos consultar el archivo de Debian desde aquí? ───────────────
AREAS=$(grep -rhoP '^(deb|Components:).*' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
        | grep -oE 'main|contrib|non-free-firmware|non-free' | sort -u | tr '\n' ' ')
printf "\n   Áreas del archivo visibles aquí: %s\n" "${AREAS:-ninguna}"

FALTA_AREA=""
for a in main contrib non-free non-free-firmware; do
  echo " $AREAS " | grep -q " $a " || FALTA_AREA="$FALTA_AREA $a"
done
if [ -n "$FALTA_AREA" ]; then
  printf "   ${AM}⚠️ ${V} este equipo no tiene habilitado:%s\n" "$FALTA_AREA"
  echo "      Los paquetes de esas áreas saldrán como «no encontrado» aunque"
  echo "      existan. La ISO sí los tendrá: la receta los habilita."
fi

# ── Recorrer las listas ───────────────────────────────────────────────
TOTAL=0; OK=0; NO=0
declare -a PERDIDOS=()

for lista in "$LISTAS"/*.list.chroot; do
  [ -f "$lista" ] || continue
  NOMBRE=$(basename "$lista" .list.chroot)
  printf "\n${AZ}── %s ──${V}\n" "$NOMBRE"

  while IFS= read -r linea; do
    linea="${linea%%#*}"
    linea="$(echo "$linea" | tr -d '[:space:]')"
    [ -z "$linea" ] && continue
    TOTAL=$((TOTAL+1))

    CAND=$(apt-cache policy "$linea" 2>/dev/null | awk '/Candidato:|Candidate:/{print $2}')
    if [ -n "$CAND" ] && [ "$CAND" != "(ninguno)" ] && [ "$CAND" != "(none)" ]; then
      OK=$((OK+1))
      printf "   ${VE}●${V} %-34s %s\n" "$linea" "$CAND"
    else
      NO=$((NO+1))
      PERDIDOS+=("$NOMBRE:$linea")
      printf "   ${RO}✖${V} %-34s no encontrado\n" "$linea"
    fi
  done < "$lista"
done

# ── Resumen ───────────────────────────────────────────────────────────
titulo "RESUMEN"
printf "   Paquetes declarados:  %s\n" "$TOTAL"
printf "   ${VE}Encontrados:          %s${V}\n" "$OK"
[ "$NO" -gt 0 ] && printf "   ${RO}Sin encontrar:        %s${V}\n" "$NO"

if [ "$NO" -eq 0 ]; then
  echo
  printf "   ${VE}✅ La receta está limpia. Se puede construir.${V}\n"
  echo
  printf "      ${AZ}sudo bash scripts/construir-iso.sh${V}\n"
  echo
  exit 0
fi

echo
printf "   ${AM}Los que no se encontraron:${V}\n"
for p in "${PERDIDOS[@]}"; do
  printf "      %s\n" "$p"
done

cat <<FIN

   ${AM}Qué puede estar pasando:${V}

   1. El nombre cambió en Debian 13 y hay que corregirlo en la lista
   2. El paquete está en un área que este equipo no tiene habilitada
      (mira el aviso de arriba)
   3. El paquete ya no existe y hay que buscar el que lo reemplaza

   Para averiguarlo:   apt-cache search NOMBRE

FIN
exit 1
