#!/bin/bash
# construir-iso.sh — Genera la ISO de RedHornoma desde la receta.
#
# Todo lo que acabe dentro de la ISO sale de receta/. Nada se instala a mano.
# Ese es el principio del proyecto: la imagen se puede rehacer desde cero en
# cualquier momento, en cualquier equipo.
#
# Uso:  sudo bash scripts/construir-iso.sh
#
# Tarda entre 40 y 90 minutos y descarga unos 3 GB.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RECETA="$BASE/receta"
ISOS="$BASE/isos"
VERSION=$(cat "$BASE/VERSION" 2>/dev/null || echo "0.1")
FECHA=$(date '+%Y%m%d')
NOMBRE="redhornoma-${VERSION}-${FECHA}-amd64.iso"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }

titulo "CONSTRUIR RedHornoma $VERSION"

# ── Comprobaciones previas ────────────────────────────────────────────
[ "$(id -u)" = "0" ] || { mal "hace falta sudo"; echo "      sudo bash $0"; exit 1; }

command -v lb >/dev/null 2>&1 || {
  mal "live-build no está instalado"
  echo "      Ejecuta antes:  sudo bash scripts/preparar-equipo.sh --aplicar"
  exit 1; }
ok "live-build $(lb --version 2>/dev/null | head -1)"

LIBRE=$(df -BG --output=avail "$BASE" | tail -1 | tr -dc '0-9')
if [ "${LIBRE:-0}" -lt 30 ]; then
  mal "hacen falta 30 GB libres y hay $LIBRE GB"
  exit 1
fi
ok "$LIBRE GB libres"

# La receta, antes de gastar una hora
printf "\n   Comprobando los nombres de los paquetes…\n"
if bash "$BASE/scripts/comprobar-receta.sh" >/tmp/redhornoma-receta.txt 2>&1; then
  ok "la receta está limpia — $(grep -c '●' /tmp/redhornoma-receta.txt) paquetes"
else
  mal "hay paquetes con nombres que no existen"
  echo
  tail -20 /tmp/redhornoma-receta.txt
  echo
  echo "      Corrige las listas y vuelve a intentarlo."
  exit 1
fi

# ── Limpiar lo anterior ───────────────────────────────────────────────
titulo "1 · LIMPIAR LA CONSTRUCCIÓN ANTERIOR"

cd "$RECETA" || exit 1

if [ -d "$RECETA/chroot" ] || [ -d "$RECETA/binary" ]; then
  echo "   Hay restos de una construcción anterior."
  echo "   Se borran para empezar limpio (las ISOs ya generadas no se tocan)."
  echo
  lb clean --purge >/dev/null 2>&1
  rm -rf "$RECETA/chroot" "$RECETA/binary" "$RECETA/cache/stages"
  ok "limpio"
else
  ok "no había nada que limpiar"
fi

# ── Configurar ────────────────────────────────────────────────────────
titulo "2 · LEER LA RECETA"

chmod +x "$RECETA/auto/config"
if lb config >/tmp/redhornoma-config.log 2>&1; then
  ok "receta leída"

  # Los ajustes propios se copian DESPUÉS de lb config, porque lb config
  # rehace config/hooks/ desde cero con los enlaces de live-build.
  PROPIOS=$(find "$RECETA/hooks-propios" -name '*.hook.chroot' 2>/dev/null | wc -l)
  if [ "$PROPIOS" -gt 0 ]; then
    cp -f "$RECETA/hooks-propios"/*.hook.chroot "$RECETA/config/hooks/normal/"
    chmod +x "$RECETA/config/hooks/normal"/*.hook.chroot 2>/dev/null
    ok "$PROPIOS ajustes propios de RedHornoma añadidos"
  fi

  # ── Las herramientas de RedHornoma van DENTRO de la ISO ─────────────
  # Una ISO que no trae RedHornoma es Debian con virtualización, y ya. Todo
  # el valor del proyecto está en estas herramientas: el informe, el papel,
  # el respaldo, el panel.
  #
  # Se construyen aquí, en cada ISO, a partir del código de paquetes/. Así
  # la ISO nunca lleva un .deb viejo que alguien construyó hace meses y
  # nadie recuerda de qué versión salió.
  #
  # live-build instala solo lo que encuentre en config/packages.chroot/.
  if [ -x "$BASE/scripts/construir-paquetes.sh" ]; then
    printf "\n      Construyendo las herramientas de RedHornoma…\n"
    if bash "$BASE/scripts/construir-paquetes.sh" >/tmp/redhornoma-paquetes.log 2>&1; then
      rm -f "$RECETA/config/packages.chroot"/redhornoma-*.deb
      mkdir -p "$RECETA/config/packages.chroot"
      cp -f "$BASE/paquetes/deb"/*.deb "$RECETA/config/packages.chroot/" 2>/dev/null
      N=$(ls "$RECETA/config/packages.chroot"/redhornoma-*.deb 2>/dev/null | wc -l)
      if [ "$N" -gt 0 ]; then
        ok "$N paquetes de RedHornoma irán dentro de la ISO"
        for p in "$RECETA/config/packages.chroot"/redhornoma-*.deb; do
          printf "         %s\n" "$(basename "$p")"
        done
      else
        mal "no se copió ningún paquete — la ISO saldría SIN RedHornoma"
        exit 1
      fi
    else
      mal "no se pudieron construir las herramientas de RedHornoma"
      tail -20 /tmp/redhornoma-paquetes.log
      exit 1
    fi
  else
    mal "falta scripts/construir-paquetes.sh — la ISO saldría sin RedHornoma"
    exit 1
  fi

  printf "      Debian:       %s\n" "$(grep -oP 'LB_DISTRIBUTION="\K[^"]+' "$RECETA/config/bootstrap" 2>/dev/null)"
  printf "      Áreas:        %s\n" "$(grep -oP 'LB_PARENT_ARCHIVE_AREAS="\K[^"]+' "$RECETA/config/bootstrap" 2>/dev/null)"
  printf "      Listas:       %s\n" "$(ls "$RECETA/config/package-lists"/*.list.chroot 2>/dev/null | wc -l)"
else
  mal "la receta tiene un error"
  tail -20 /tmp/redhornoma-config.log
  exit 1
fi

# ── Construir ─────────────────────────────────────────────────────────
titulo "3 · CONSTRUIR"

cat <<AVISO

   Esto tarda entre 40 y 90 minutos y descarga unos 3 GB.

   Puedes dejarlo trabajando. Si se corta la luz o cierras la terminal,
   se puede volver a lanzar desde el principio sin problema.

   El registro completo queda en:
      $RECETA/build.log

AVISO

INICIO=$(date +%s)
printf "   ${AZ}Comenzando a las %s…${V}\n\n" "$(date '+%H:%M')"

if lb build 2>&1 | tee "$RECETA/build.log" | \
   grep --line-buffered -E '^P: (Begin|Setting|Installing|Creating|Building)' | \
   sed 's/^P: /   /'; then
  RESULTADO=0
else
  RESULTADO=1
fi

MINUTOS=$(( ($(date +%s) - INICIO) / 60 ))

# ── Recoger la ISO ────────────────────────────────────────────────────
titulo "4 · RESULTADO"

GENERADA=$(find "$RECETA" -maxdepth 1 -name 'live-image-amd64.hybrid.iso' -o \
                          -maxdepth 1 -name '*.iso' 2>/dev/null | head -1)

if [ -z "$GENERADA" ] || [ ! -f "$GENERADA" ]; then
  mal "no se generó ninguna ISO  (${MINUTOS} minutos)"
  echo
  echo "   Últimas líneas del registro:"
  tail -25 "$RECETA/build.log" | sed 's/^/      /'
  echo
  echo "   El registro completo:  $RECETA/build.log"
  exit 1
fi

mkdir -p "$ISOS"

# Una sola ISO, con su versión y su fecha en el nombre. Nunca dos con el
# mismo nombre en carpetas distintas: eso ya nos costó una noche.
mv "$GENERADA" "$ISOS/$NOMBRE"
chown "${SUDO_USER:-root}:${SUDO_USER:-root}" "$ISOS/$NOMBRE" 2>/dev/null

BYTES=$(stat -c%s "$ISOS/$NOMBRE")
sha256sum "$ISOS/$NOMBRE" | awk '{print $1}' > "$ISOS/$NOMBRE.sha256"
chown "${SUDO_USER:-root}:${SUDO_USER:-root}" "$ISOS/$NOMBRE.sha256" 2>/dev/null

ok "ISO generada en ${MINUTOS} minutos"
echo
printf "   %-16s %s\n" "Archivo:"  "$NOMBRE"
printf "   %-16s %s  (%s bytes)\n" "Tamaño:" "$(numfmt --to=iec "$BYTES")" "$BYTES"
printf "   %-16s %s\n" "Carpeta:"  "$ISOS"
printf "   %-16s %s\n" "Huella:"   "$(cat "$ISOS/$NOMBRE.sha256")"

titulo "✅ LISTO — CÓMO PROBARLA"

cat <<FIN

   ${AZ}Sin arriesgar nada — en una máquina virtual${V}

      qemu-system-x86_64 -m 4096 -enable-kvm \\
        -cdrom "$ISOS/$NOMBRE"

   ${AZ}En un pendrive${V}

      ${RO}Mira PRIMERO qué letra tiene el pendrive:${V}

         lsblk -o NAME,SIZE,LABEL,TRAN,MODEL

      Las letras cambian según qué discos estén conectados. Escribir en el
      disco equivocado borra lo que haya. Comprueba el tamaño y el modelo
      antes de teclear nada.

      Después, con la letra correcta:

         sudo dd if="$ISOS/$NOMBRE" of=/dev/sdX bs=4M status=progress conv=fsync

FIN
exit $RESULTADO
