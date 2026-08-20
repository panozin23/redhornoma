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

  # ── Fuera lo que no es del paquete ─────────────────────────────────
  # Python deja un __pycache__ al lado de cualquier guion que se compruebe
  # con «py_compile», y los editores dejan lo suyo. Nada de eso pertenece
  # al programa, pero se copia igual y acaba dentro del .deb, subido al
  # repositorio y instalado en las máquinas de los centros.
  #
  # Pasó el 2026-08-05: un .pyc de 13 kB viajó hasta servidor-ciudad porque
  # se comprobó la sintaxis de una herramienta antes de empaquetarla. No
  # hacía daño, pero un paquete debe contener lo que dice contener.
  #
  # Se limpia aquí y no a mano: lo que depende de que alguien se acuerde,
  # tarde o temprano se olvida.
  find "$ARBOL" \( -name '__pycache__' -o -name '.mypy_cache' \) -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$ARBOL" \( -name '*.pyc' -o -name '*.pyo' -o -name '*~' \
                   -o -name '*.orig' -o -name '*.rej' -o -name '.DS_Store' \) \
       -type f -delete 2>/dev/null || true

  # Permisos que dpkg espera. Sin esto lintian se queja y algunos sistemas
  # instalan los programas sin permiso de ejecución.
  find "$ARBOL" -type d -exec chmod 755 {} +
  find "$ARBOL" -type f -exec chmod 644 {} +
  [ -d "$ARBOL/usr/bin"  ] && chmod 755 "$ARBOL"/usr/bin/*
  [ -d "$ARBOL/usr/sbin" ] && chmod 755 "$ARBOL"/usr/sbin/*

  # Los filtros de CUPS son binarios ELF, sin «#!»: la regla de más abajo
  # (que busca shebang) no los detecta y quedarían en 644, sin permiso de
  # ejecución. CUPS no puede lanzar lo que no es ejecutable — el mismo
  # fallo silencioso que tuvo roto pkexec el 09/08/2026, aquí con la
  # impresora en vez del botón «Arreglar».
  [ -d "$ARBOL/usr/lib/cups/filter" ] && chmod 755 "$ARBOL"/usr/lib/cups/filter/*

  # Y cualquier otro programa, esté donde esté. Se reconoce por su primera
  # línea: si empieza por «#!», es algo que se ejecuta.
  #
  # Antes solo se devolvía el permiso a usr/bin y usr/sbin, y el ayudante
  # que repara el centro vive en usr/lib/redhornoma. Salió del paquete sin
  # permiso de ejecución, y pkexec no puede lanzar lo que no es ejecutable:
  # el botón «Arreglar» habría fallado en cada centro, en silencio.
  # Descubierto mirando el .deb por dentro antes de publicarlo, 09/08/2026.
  while IFS= read -r f; do
    [ "$(head -c2 "$f" 2>/dev/null)" = '#!' ] && chmod 755 "$f"
  done < <(find "$ARBOL" -type f ! -path "$ARBOL/DEBIAN/*" \
                ! -path "$ARBOL/usr/bin/*" ! -path "$ARBOL/usr/sbin/*")

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

# ── ¿Alguno pisa un archivo que ya tiene dueño? ───────────────────────
#
# 🔴 EL 15/08/2026 ESTO REVENTÓ UNA ACTUALIZACIÓN A MEDIO CAMINO.
#
# redhornoma-red 1.1.5 traía /usr/share/keyrings/tailscale-archive-keyring.gpg
# —copiado tal cual de este equipo— y ese archivo YA ES de otro paquete, el
# «tailscale-archive-keyring», que está en toda máquina donde se instaló
# Tailscale a mano. Dos paquetes no pueden traer el mismo archivo, así que
# dpkg se planta:
#
#   trying to overwrite '...', which is also in package tailscale-archive-keyring
#
# Y no se planta en el equipo de quien construye: se planta EN EL CENTRO, a
# mitad de la actualización, dejando media docena de paquetes desempaquetados
# y sin configurar. En Hornoma, a 100 km, con euflo delante y de noche.
#
# Se comprueba aquí porque aquí no cuesta nada: preguntarle a dpkg de quién es
# cada archivo que vamos a repartir.
titulo "¿PISAMOS ARCHIVOS DE OTROS PAQUETES?"
CHOQUES=0
for d in "$FUENTE"/*/; do
  [ -d "$d" ] || continue
  P=$(basename "$d")
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    DUENO=$(LC_ALL=C dpkg -S "$f" 2>/dev/null | grep -v diversion | head -1 | cut -d: -f1)
    [ -n "$DUENO" ] && [ "$DUENO" != "$P" ] && {
      printf "   ${RO}✖${V} %s trae %s
" "$P" "$f"
      printf "       y ese archivo es de «%s»: dpkg lo va a rechazar
" "$DUENO"
      CHOQUES=$((CHOQUES+1)); }
  done <<< "$(find "$d" -type f -not -path '*/DEBIAN/*' -printf '/%P\n' 2>/dev/null)"
done
if [ "$CHOQUES" -eq 0 ]; then
  printf "   ${VE}●${V} ninguno pisa nada de otro paquete\n"
else
  printf "\n   ${AM}Cámbiale el nombre al archivo, o la ruta. Publicarlo así rompe\n"
  printf "   la actualización en los centros, no aquí.${V}\n"
  exit 1
fi

# ── ¿Alguno se rompe cuando lo lanza el sistema y no una persona? ─────
#
# 🔴 EL 18/08/2026 ESTO TUVO ROTO EL OBJETIVO 9 DESDE EL PRIMER DÍA.
#
# «redhornoma-aviso» es el que deja dicho en la nube «me apago» y «ya
# desperté». Probado a mano funcionaba perfectamente. Lanzado por systemd
# —que es EXACTAMENTE cuando tiene que funcionar— fallaba siempre, a los
# 39 milisegundos, sin llegar a intentar la nube.
#
# La causa: nombraba «$HOME». Una persona con sudo lleva HOME; systemd no
# se lo da a nadie. Y con «set -u» arriba, nombrar algo que no existe mata
# el guion en el acto.
#
# Es un fallo silencioso perfecto: no deja rastro donde se busca, y la
# prueba obvia —ejecutarlo a mano— da verde. Por eso se comprueba aquí.
#
# La regla: si un guion tiene «set -u» y puede lanzarlo el sistema, no
# puede nombrar «$HOME» a secas. Se escribe «${HOME:-/root}».
titulo "¿AGUANTAN QUE LOS LANCE EL SISTEMA?"
DESNUDOS=0
for d in "$FUENTE"/*/; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # Solo los que se plantan ante una variable que no existe.
    grep -qE '^set -[a-z]*u' "$f" 2>/dev/null || continue
    # Entre comillas SIMPLES no se expande aquí, sino en la otra máquina:
    # ese uso es legítimo y no cuenta.
    LINEAS=$(grep -nE '\$HOME[/"]' "$f" 2>/dev/null | grep -v '\${HOME:-' | grep -v "'.*\\\$HOME.*'")
    [ -n "$LINEAS" ] && {
      printf "   ${RO}✖${V} %s nombra \$HOME a secas:\n" "$(basename "$f")"
      printf '%s\n' "$LINEAS" | sed 's/^/       línea /'
      DESNUDOS=$((DESNUDOS+1)); }
  done <<< "$(find "$d" -type f \( -path '*/usr/bin/*' -o -path '*/usr/local/sbin/*' \) 2>/dev/null)"
done
if [ "$DESNUDOS" -eq 0 ]; then
  printf "   ${VE}●${V} ninguno se cae por falta de HOME\n"
else
  printf "\n   ${AM}Escríbelo «\${HOME:-/root}». Tal como está, funciona cuando lo\n"
  printf "   pruebas tú y falla cuando lo lanza la máquina sola.${V}\n"
  exit 1
fi

titulo "RESUMEN"
printf "   construidos: %s      fallidos: %s\n" "$HECHOS" "$FALLOS"
printf "   quedaron en: %s\n" "$SALIDA"

[ "$FALLOS" -gt 0 ] && exit 1

# ── Llevarlos a la receta ────────────────────────────────────────────
# Esto se hacía a mano, y el 2026-08-05 se descubrió que llevaba días sin
# hacerse: la receta seguía con respaldo 1.0.4 —la versión que decía «HECHO»
# con una base vacía— mientras el 1.0.6 corregido esperaba aquí. Un pendrive
# construido ese día habría instalado la versión rota.
#
# Construir un paquete y no llevarlo a la receta es no haberlo construido.
RECETA="$BASE/receta/config/packages.chroot"
if [ -d "$RECETA" ]; then
  titulo "LLEVARLOS A LA RECETA"
  QUITADOS=0; PUESTOS=0
  for DEB in "${CONSTRUIDOS[@]}"; do
    NOMBRE=$(basename "$DEB" | sed 's/_.*//')
    # Fuera las versiones viejas del mismo paquete: si quedaran las dos,
    # live-build instalaría cualquiera de ellas.
    for VIEJO in "$RECETA/${NOMBRE}"_*.deb; do
      [ -e "$VIEJO" ] || continue
      [ "$(basename "$VIEJO")" = "$(basename "$DEB")" ] && continue
      rm -f "$VIEJO"; QUITADOS=$((QUITADOS+1))
      printf "   quitado  %s\n" "$(basename "$VIEJO")"
    done
    cp -f "$DEB" "$RECETA/" && PUESTOS=$((PUESTOS+1))
  done

  # Comprobar de verdad, byte por byte. Un cp que falló en silencio deja la
  # receta atrasada igual que si no se hubiera copiado nada.
  for DEB in "${CONSTRUIDOS[@]}"; do
    if cmp -s "$DEB" "$RECETA/$(basename "$DEB")"; then
      ok "en la receta: $(basename "$DEB")"
    else
      mal "NO llegó a la receta: $(basename "$DEB")"
      exit 1
    fi
  done
  printf "\n   %s puestos, %s versiones viejas retiradas\n" "$PUESTOS" "$QUITADOS"
else
  mal "no encuentro la receta en $RECETA — los paquetes NO están en el pendrive"
  exit 1
fi

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
