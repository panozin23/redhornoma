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

# ── Lo que piden nuestros propios paquetes ────────────────────────────
# Las herramientas de RedHornoma van dentro de la ISO, y necesitan cosas:
# mdbtools para abrir las bases de SALMI, python3-libvirt para escribir en
# Windows. Si no están declaradas en las listas, la ISO se construye igual
# y el fallo aparece meses después, en un centro, cuando el respaldo no
# puede comprobar nada.
#
# Se mira aquí, en veinte segundos, y no después de noventa minutos.
printf "\n${AZ}── lo que piden las herramientas de RedHornoma ──${V}\n"

DECLARADOS=$(cat "$LISTAS"/*.list.chroot 2>/dev/null | sed 's/#.*//; s/[[:space:]]//g' | grep -v '^$' | sort -u)
FALTAN_DEP=0

# Los esenciales de Debian vienen siempre: no hace falta declararlos.
ESENCIALES="coreutils findutils procps util-linux bash dash grep sed gawk tar dpkg passwd systemd"

for control in "$BASE"/paquetes/*/DEBIAN/control; do
  [ -f "$control" ] || continue
  PAQ=$(awk -F': ' '/^Package:/{print $2}' "$control")
  # tr -d '[:space:]' se comería también los saltos de línea y dejaría todas
  # las dependencias pegadas en una sola palabra. sed trabaja por líneas.
  DEPS=$(sed -n '/^Depends:/,/^[A-Z][a-z]*:/p' "$control" \
         | sed 's/^Depends://; /^[A-Z][a-z]*:/d' \
         | tr ',' '\n' | sed 's/(.*)//; s/[[:space:]]//g' | grep -v '^$')
  for dep in $DEPS; do
    case "$dep" in redhornoma-*) continue;; esac
    echo " $ESENCIALES " | grep -q " $dep " && continue
    if ! echo "$DECLARADOS" | grep -qx "$dep"; then
      printf "   ${RO}✖${V} %-28s lo pide %s y no está en ninguna lista\n" "$dep" "$PAQ"
      FALTAN_DEP=$((FALTAN_DEP+1))
    fi
  done
done

if [ "$FALTAN_DEP" -eq 0 ]; then
  printf "   ${VE}●${V} todo lo que piden está declarado\n"
else
  printf "\n   ${AM}Añádelos a la lista que les corresponda antes de construir.${V}\n"
fi

# ── ¿Y las ÓRDENES que las herramientas usan de verdad? ───────────────
#
# Lo de arriba comprueba lo que los paquetes DICEN que necesitan. Esto
# comprueba lo que las herramientas HACEN: cada orden que invocan tiene que
# poder venir de la receta.
#
# 🔴 Nació el 14/08/2026 y encontró cinco agujeros a la primera: psmisc,
# xdg-user-dirs, xorriso, genisoimage y tailscale. Los cinco estaban
# instalados de arrastre y ninguno declarado, así que una ISO reconstruida
# podía salir sin ellos y la herramienta fallaría sin decir por qué.
# Tailscale era el peor: se llevaba por delante el objetivo 11 entero.
#
# LA PARTE DIFÍCIL FUE NO GRITAR EN FALSO. La primera versión señaló once
# cosas y NINGUNA era un agujero: palabras sueltas de los comentarios,
# «import» de un guion de Python, y paquetes que sí están pero por otro
# camino. Un aviso que se equivoca se aprende a ignorar, así que se afinó
# hasta que solo queda lo real:
#
#   · se miran solo los guiones de bash, no los de Python
#   · y solo las palabras en POSICIÓN DE ORDEN — al principio, tras una
#     tubería, tras sudo… — no cualquier palabra suelta
#   · vale que el paquete esté declarado, que Debian lo traiga siempre, o
#     que venga de arrastre de algo declarado (se calcula el arrastre)
#   · las órdenes que se eligen por alternativas —«awk»— se comprueban
#     mirando a TODOS los que podrían darla
titulo "LAS ÓRDENES QUE USAN LAS HERRAMIENTAS"

# Terminales de repuesto: se prueban una tras otra y konsole, que sí está
# declarada, es la primera. Que las otras falten es lo normal, no un fallo.
OPCIONALES=" gnome-terminal xfce4-terminal xterm x-terminal-emulator "

# Palabras que PARECEN órdenes y no lo son. Se listan una a una, con su
# motivo, en vez de afinar el filtro: se intentó quitar todo lo que va
# entre comillas y el filtro empezó a comerse órdenes de verdad —bdeinfo,
# xorriso, mdb-tables— que sí hacen falta. Perder una de verdad es peor
# que arrastrar dos falsas, y una lista escrita se entiende de un vistazo.
#
#   import  · palabra de Python, dentro de los trozos de Python incrustados
#   docker  · parte de un patrón de búsqueda de nombres de interfaz de red,
#             en redhornoma-papel: (virbr[0-9]+|docker[0-9]+|...)
NO_SON_ORDENES=" import docker "

FALTAN_ORD=0
GUIONES=$(grep -rl '^#!.*\(bash\|/sh\)' "$BASE"/paquetes/*/usr/bin/ 2>/dev/null)

if [ -z "$GUIONES" ]; then
  printf "   ${AM}⚠️ ${V} no encuentro las herramientas: no se pudo comprobar\n"
else
  # Los que viajan por otro camino: bajados aparte a packages.chroot. No
  # están en ninguna lista de live-build y aun así entran en la ISO, así
  # que contarlos como «sin declarar» sería una falsa alarma. El archivo
  # explica el motivo de cada uno.
  APARTE=$(grep -vE '^\s*#|^\s*$' "$BASE/receta/config/paquetes-aparte.txt" 2>/dev/null | tr -d ' ')
  # Lo que Debian trae siempre no hace falta declararlo.
  BASICOS=$(dpkg-query -W -f='${Package} ${Priority}\n' 2>/dev/null \
            | awk '$2=="required"||$2=="important"||$2=="standard"{print $1}' | sort -u)
  # Y lo que viene de arrastre de lo declarado también vale. Se parte de
  # las listas MÁS los paquetes propios, que no van en ninguna lista
  # porque viajan como .deb dentro de la receta.
  PROPIOS=""
  for _d in "$BASE"/paquetes/redhornoma-*/; do
    [ -d "$_d" ] && PROPIOS="$PROPIOS $(basename "$_d")"
  done
  # shellcheck disable=SC2086
  ARRASTRE=$(apt-cache depends --recurse --installed --no-recommends --no-suggests \
               --no-conflicts --no-breaks --no-replaces --no-enhances \
               $DECLARADOS $PROPIOS 2>/dev/null | grep -oP '^\w[\w.+-]*' | sort -u)

  # De quién viene un archivo, sin que las desviaciones de dpkg estorben.
  de_quien(){ LC_ALL=C dpkg -S "$1" 2>/dev/null | grep -v 'diversion' | head -1 | cut -d: -f1; }
  vale(){ echo "$DECLARADOS" | grep -qx "$1" && return 0
          echo "$APARTE"     | grep -qx "$1" && return 0
          echo "$BASICOS"    | grep -qx "$1" && return 0
          echo "$ARRASTRE"   | grep -qx "$1" && return 0
          return 1; }

  ORDENES=$(grep -hoP '(^|[;&|]|\$\(|&&|\|\||\bsudo |\bpkexec |\bexec |\bcommand -v |\bthen |\bdo |\bif |\bxargs )[[:space:]]*\K[a-z][a-z0-9_-]{2,}\b' \
            $GUIONES 2>/dev/null | sort -u)
  REVISADAS=0
  for o in $ORDENES; do
    case "$o" in redhornoma-*) continue ;; esac
    echo "$OPCIONALES"     | grep -q " $o " && continue
    echo "$NO_SON_ORDENES" | grep -q " $o " && continue
    RUTA=$(command -v "$o" 2>/dev/null) || continue
    [ -x "$RUTA" ] || continue
    REVISADAS=$((REVISADAS+1))
    PAQ=$(de_quien "$RUTA")
    # Sin dueño = la elige el sistema de alternativas. Basta con que UNO de
    # los que podrían darla esté en la receta.
    if [ -z "$PAQ" ]; then
      # 🔴 Aquí ponía «break 2» para salir de los dos bucles de una vez, y
      # el 2 se llevaba por delante el bucle de FUERA: la comprobación
      # terminaba tras dos órdenes y daba un verde precioso habiendo mirado
      # el 1% . Es el fallo favorito de esta casa: no un rojo equivocado,
      # sino un verde barato. Ahora se usa una marca.
      RESUELTA=no
      for alt in $(update-alternatives --list "$o" 2>/dev/null); do
        vale "$(de_quien "$alt")" && { RESUELTA=si; break; }
      done
      [ "$RESUELTA" = "si" ] && continue
      PAQ=$(de_quien "$(readlink -f "$RUTA")")
    fi
    [ -n "$PAQ" ] || continue
    vale "$PAQ" && continue
    printf "   ${RO}✖${V} %-24s la usa «%s» y no puede venir de la receta\n" "$PAQ" "$o"
    FALTAN_ORD=$((FALTAN_ORD+1))
  done
  if [ "$REVISADAS" -lt 40 ]; then
    # No se puede cantar victoria habiendo mirado cuatro cosas. Las
    # herramientas usan del orden de 150 órdenes; si salen muchas menos, es
    # que la comprobación se rompió, no que todo esté bien.
    printf "   ${AM}⚠️ ${V} solo se pudieron revisar %s órdenes: la comprobación no sirve\n" "$REVISADAS"
    FALTAN_ORD=1
  elif [ "$FALTAN_ORD" -eq 0 ]; then
    printf "   ${VE}●${V} las %s órdenes revisadas vienen de la receta\n" "$REVISADAS"
  else
    printf "\n   ${AM}Declara esos paquetes en la lista que les toque.${V}\n"
  fi
fi

# ── Resumen ───────────────────────────────────────────────────────────
titulo "RESUMEN"
printf "   Paquetes declarados:  %s\n" "$TOTAL"
printf "   ${VE}Encontrados:          %s${V}\n" "$OK"
[ "$NO" -gt 0 ] && printf "   ${RO}Sin encontrar:        %s${V}\n" "$NO"

if [ "$NO" -eq 0 ] && [ "$FALTAN_DEP" -eq 0 ] && [ "$FALTAN_ORD" -eq 0 ]; then
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
