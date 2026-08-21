#!/bin/bash
# Prepara una máquina Debian 13 para intentar correr los programas del
# Ministerio SIN Windows.
#
# EL PORQUÉ — 21/08/2026, idea de euflo:
#
#   «Lo que nos interesa es poder ver desde Cochabamba el SOAPS, SALMI y
#    SNIS de Hornoma, trabajar ahí, editar. La impresión es UNA VEZ AL MES
#    y es el último día; no se imprime todos los días.»
#
# Eso parte el problema en dos, y por eso vale la pena intentarlo:
#
#   todos los días   meter datos y consultar   ← si Wine puede con esto, gana
#   una vez al mes   el 301/302 con Excel      ← eso se hace en UNA máquina
#                                                 Windows, y ya está probado
#
# 🔴 LO QUE ESTE GUION NO HACE: no instala ningún programa del Ministerio y
# no toca ninguna base de datos. Solo deja la máquina preparada. Nada de lo
# que hace aquí puede perder información de un centro.
set -u

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "      ${GR}%s${V}\n" "$1"; }

[ "$(id -u)" = "0" ] || { mal "hace falta sudo"; exit 1; }
QUIEN="${SUDO_USER:-}"
[ -n "$QUIEN" ] || { mal "ejecútalo con sudo desde tu cuenta, no como root a secas"; exit 1; }
CASA=$(getent passwd "$QUIEN" | cut -d: -f6)

titulo "PREPARAR ESTA MÁQUINA PARA PROGRAMAS DE WINDOWS"
nota "cuenta: $QUIEN   ·   carpeta: $CASA"

# ── 1 · La sección «contrib» ─────────────────────────────────────────
# Ahí vive «winetricks», que es quien instala las piezas de Visual Basic 6.
# Sin él habría que buscarlas a mano una por una.
echo
# 🔴 «Candidato:» lleva DOS espacios, y en inglés se llama «Candidate:».
# Un grep con un solo espacio dice que no hay paquete cuando sí lo hay, y
# eso fue exactamente lo que pasó el 21/08 en rosi: contrib SÍ se había
# puesto bien y el guion dijo que no. La comprobación mentía, no el sistema.
hay_winetricks(){ apt-cache policy winetricks 2>/dev/null | grep -qE 'Candidat[eo]: +[0-9]'; }
if hay_winetricks; then
  ok "«contrib» ya estaba disponible"
else
  # 🔴 HAY DOS FORMATOS, Y EL DE DEBIAN SUELE SER EL VIEJO — 21/08/2026
  #
  # La primera versión de esto solo miraba los «.sources» del formato
  # nuevo. En el portátil de euflo el único «.sources» era el de VS Code:
  # le habría añadido «contrib» a Microsoft y dejado a Debian igual. Se
  # descubrió probándolo EN SECO antes de ejecutarlo.
  #
  # Se tocan solo las líneas de los repositorios de Debian, y solo las que
  # no tengan ya «contrib».
  TOCADOS=0
  for F in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [ -f "$F" ] || continue
    grep -qE '^deb.*debian\.org' "$F" || continue
    cp -n "$F" "$F.antes-de-wine"
    sed -i -E '/^deb.*debian\.org/ { /contrib/! s/$/ contrib/ }' "$F"
    TOCADOS=$((TOCADOS+1))
  done
  for F in /etc/apt/sources.list.d/*.sources; do
    [ -f "$F" ] || continue
    grep -qE 'debian\.org' "$F" || continue          # solo los de Debian
    grep -q '^Components:.*contrib' "$F" && continue
    cp -n "$F" "$F.antes-de-wine"
    sed -i 's/^\(Components:.*\)$/\1 contrib/' "$F"
    TOCADOS=$((TOCADOS+1))
  done
  [ "$TOCADOS" -gt 0 ] || { mal "no encuentro el repositorio de Debian"; exit 1; }
  nota "archivos ajustados: $TOCADOS (se guardó copia como *.antes-de-wine)"
  apt-get update -qq
  # 🔴 «Candidato:» lleva DOS espacios, y en inglés se llama «Candidate:».
# Un grep con un solo espacio dice que no hay paquete cuando sí lo hay, y
# eso fue exactamente lo que pasó el 21/08 en rosi: contrib SÍ se había
# puesto bien y el guion dijo que no. La comprobación mentía, no el sistema.
hay_winetricks(){ apt-cache policy winetricks 2>/dev/null | grep -qE 'Candidat[eo]: +[0-9]'; }
if hay_winetricks; then
    ok "«contrib» habilitado"
  else
    mal "no consigo llegar a «winetricks»"
    nota "se guardó copia de los archivos como *.antes-de-wine"
    exit 1
  fi
fi

# ── 2 · El 32 bits ───────────────────────────────────────────────────
# 🔴 SOAPS y SALMI están escritos en Visual Basic 6, que es de 32 bits.
# Sin esto, Wine se instala, arranca… y no abre ninguno de los dos.
echo
if dpkg --print-foreign-architectures 2>/dev/null | grep -qx i386; then
  ok "el 32 bits ya estaba habilitado"
else
  dpkg --add-architecture i386 && apt-get update -qq
  if dpkg --print-foreign-architectures 2>/dev/null | grep -qx i386; then
    ok "32 bits habilitado"
  else
    mal "no se pudo habilitar el 32 bits — sin eso no tiene sentido seguir"; exit 1
  fi
fi

# ── 3 · Wine y sus ayudantes ─────────────────────────────────────────
echo
nota "instalando… esto baja bastante, ten paciencia"
apt-get install -y --no-install-recommends wine wine64 winetricks cabextract >/dev/null 2>&1
apt-get install -y wine32:i386 >/dev/null 2>&1 || apt-get install -y wine32 >/dev/null 2>&1

# El resultado, no el código de salida.
FALLA=0
for C in wine winetricks cabextract; do
  if command -v "$C" >/dev/null 2>&1; then ok "$C: $(command -v $C)"
  else mal "falta $C"; FALLA=1; fi
done
if dpkg -l 2>/dev/null | grep -qE '^ii +wine32'; then ok "wine de 32 bits instalado"
else mal "NO quedó el wine de 32 bits — los programas del Ministerio no abrirían"; FALLA=1; fi
[ "$FALLA" = "0" ] || { echo; mal "falta algo — no sigo"; exit 1; }

nota "versión de Wine: $(sudo -u "$QUIEN" wine --version 2>/dev/null)"

# ── 4 · Un «Windows de mentira» de 32 bits ───────────────────────────
# Wine guarda cada entorno por separado. Se hace uno propio, de 32 bits, y
# así lo que se pruebe aquí no estorba a nada más. Borrarlo es borrar una
# carpeta: no deja rastro en el sistema.
echo
PREFIJO="$CASA/.wine-ministerio"
if [ -d "$PREFIJO" ]; then
  ok "ya existía el entorno en $PREFIJO"
else
  sudo -u "$QUIEN" env WINEPREFIX="$PREFIJO" WINEARCH=win32 WINEDLLOVERRIDES="mscoree,mshtml=" \
       wineboot -u >/dev/null 2>&1
  if [ -d "$PREFIJO/drive_c" ]; then ok "entorno creado en $PREFIJO"
  else mal "no se pudo crear el entorno de 32 bits"; exit 1; fi
fi

# ── 5 · Las piezas de Visual Basic 6 ─────────────────────────────────
# Son las mismas que hubo que registrar a mano el 06/08 para que SOAPS
# funcionara desde otro puesto. Aquí las pone winetricks de una vez.
#
#   vb6run   el motor de Visual Basic 6
#   mdac28   por donde los programas hablan con las bases de datos
#   jet40    el motor de Access, que es lo que usa SALMI
#   mfc42    librerías que dan por hechas los programas de esa época
echo
nota "poniendo las piezas de Visual Basic 6 (esto tarda unos minutos)"
sudo -u "$QUIEN" env WINEPREFIX="$PREFIJO" WINEARCH=win32 \
     winetricks -q vb6run mdac28 jet40 mfc42 >/dev/null 2>&1

PUESTAS=0
for P in vb6run mdac28 jet40 mfc42; do
  if grep -qx "$P" "$PREFIJO/winetricks.log" 2>/dev/null; then
    ok "$P"; PUESTAS=$((PUESTAS+1))
  else
    avi "$P no consta como instalado"
  fi
done

titulo "CÓMO QUEDÓ"
printf "   piezas puestas: %s de 4\n" "$PUESTAS"
echo
if [ "$PUESTAS" -ge 3 ]; then
  ok "la máquina está preparada para intentar abrir SALMI"
  echo
  nota "el entorno está en: $PREFIJO"
  nota "para deshacerlo entero:  rm -rf $PREFIJO"
else
  avi "faltan piezas — puede que algún programa no abra"
  nota "no es un fallo grave: se pueden volver a intentar"
fi
echo
nota "SIGUIENTE PASO: traer SALMI y probar a abrirlo"
echo
