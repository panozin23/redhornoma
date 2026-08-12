#!/bin/bash
# construir-iso.sh — Genera la ISO de RedHornoma desde la receta.
#
# Todo lo que acabe dentro de la ISO sale de receta/. Nada se instala a mano.
# Ese es el principio del proyecto: la imagen se puede rehacer desde cero en
# cualquier momento, en cualquier equipo.
#
# Uso:  sudo bash scripts/construir-iso.sh
#
# La primera vez tarda entre 40 y 90 minutos y descarga unos 3 GB. Las
# siguientes, unos 12 minutos: los paquetes descargados se conservan.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RECETA="$BASE/receta"
ISOS="$BASE/isos"
VERSION=$(cat "$BASE/VERSION" 2>/dev/null || echo "0.1")
FECHA=$(date '+%Y%m%d')
NOMBRE="redhornoma-${VERSION}-${FECHA}-amd64.iso"

GR=$'\033[0;90m'; V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

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
  # Se enseñan las LÍNEAS DEL PROBLEMA, no el final del informe.
  #
  # Antes decía «hay paquetes con nombres que no existen» y pegaba las
  # últimas 20 líneas. El 09/08/2026 el fallo era otro —una herramienta
  # pedía «pkexec» y nadie lo había declarado en la receta— y esas 20
  # líneas eran justo el resumen, que decía «155 declarados, 155
  # encontrados» y una lista de faltantes VACÍA. El mensaje contradecía a
  # los números y la causa quedaba fuera de la pantalla.
  #
  # Un fallo que no enseña su motivo hace perder más tiempo que el fallo.
  mal "la receta tiene algo pendiente — esto es lo que falta:"
  echo
  grep -E '✖' /tmp/redhornoma-receta.txt | sed 's/^/   /'
  echo
  echo "      El informe completo:  /tmp/redhornoma-receta.txt"
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
  # «lb clean» a secas, NO «--purge».
  #
  # --purge activa RM_CACHE y hace «rm -rf cache»: borra los ~3 GB de
  # paquetes ya descargados. Cada construcción volvía a bajarlos enteros,
  # y por eso tardaba una hora y cada intento era una lotería con la red.
  # El 2026-08-05 se perdieron dos construcciones seguidas por eso.
  #
  # El sistema a medio construir (chroot, binary) sí hay que borrarlo: eso
  # es lo que ensucia. Los paquetes descargados no ensucian nada — llevan
  # su versión en el nombre, y si sale una más nueva, apt la baja igual.
  lb clean >/dev/null 2>&1
  rm -rf "$RECETA/chroot" "$RECETA/binary" "$RECETA/cache/stages"
  ok "limpio"
  GUARDADOS=$(ls -1 "$RECETA/cache/packages.chroot"/*.deb 2>/dev/null | wc -l)
  [ "$GUARDADOS" -gt 0 ] && ok "se conservan $GUARDADOS paquetes ya descargados"
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
  # Los de «chroot» tocan el sistema que se construye; los de «binary» tocan
  # la imagen ya armada —el menú de arranque, por ejemplo—. Hacen falta los
  # dos: el menú se escribe al final, cuando el chroot ya está cerrado.
  PROPIOS=0
  for tipo in chroot binary; do
    N=$(find "$RECETA/hooks-propios" -name "*.hook.$tipo" 2>/dev/null | wc -l)
    [ "$N" -gt 0 ] || continue
    cp -f "$RECETA/hooks-propios"/*."hook.$tipo" "$RECETA/config/hooks/normal/"
    chmod +x "$RECETA/config/hooks/normal"/*."hook.$tipo" 2>/dev/null
    PROPIOS=$(( PROPIOS + N ))
  done
  [ "$PROPIOS" -gt 0 ] && ok "$PROPIOS ajustes propios de RedHornoma añadidos"

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
  # Se pregunta por -f y no por -x: se ejecuta con «bash», que no necesita
  # permiso de ejecución, y git no siempre conserva ese permiso al clonar.
  # Con -x, un clon recién hecho pararía la construcción diciendo que falta
  # un archivo que está ahí delante.
  if [ -f "$BASE/scripts/construir-paquetes.sh" ]; then
    printf "\n      Construyendo las herramientas de RedHornoma…\n"
    if bash "$BASE/scripts/construir-paquetes.sh" >/tmp/redhornoma-paquetes.log 2>&1; then
      rm -f "$RECETA/config/packages.chroot"/redhornoma-*.deb
      mkdir -p "$RECETA/config/packages.chroot"
      cp -f "$BASE/paquetes/deb"/*.deb "$RECETA/config/packages.chroot/" 2>/dev/null
      # Devolver paquetes/deb/ a su dueño. Esto se ejecuta con sudo, así que
      # lo que construya queda a nombre de root, y después el usuario no puede
      # volver a construir sin sudo — un «permiso denegado» sin explicación en
      # su propia carpeta. Pasó el 2026-08-02.
      if [ -n "${SUDO_USER:-}" ]; then
        chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")" \
              "$BASE/paquetes/deb" 2>/dev/null || true
      fi

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

if [ "${GUARDADOS:-0}" -gt 100 ]; then
  TIEMPO="Con $GUARDADOS paquetes ya descargados, esto suele tardar unos 15 minutos."
else
  TIEMPO="La primera vez tarda entre 40 y 90 minutos y descarga unos 3 GB."
fi
cat <<AVISO

   $TIEMPO

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
  # ── El fallo de «target is busy» ────────────────────────────────────
  #
  # live-build monta /sys, /proc y /dev/pts dentro del sistema que
  # construye, y al terminar los desmonta. Si en ese preciso instante
  # cualquier programa está mirando dentro de receta/chroot, el desmontaje
  # falla y la construcción entera muere después de veinte minutos.
  #
  # Pasó el 2026-08-06: mientras el ISO se construía, se leyeron archivos
  # de receta/chroot para comprobar algo. Bastó eso. Un editor con la
  # carpeta abierta, un buscador de archivos o un antivirus harían igual.
  #
  # No es culpa de la receta ni hay nada roto: es cuestión de un segundo.
  # Por eso se reintenta una vez en lugar de mandar a empezar de cero.
  if grep -q 'target is busy' "$RECETA/build.log" 2>/dev/null; then
    avi "algo estaba mirando dentro de la construcción y no se pudo cerrar"
    echo
    echo "   No hay nada roto. Ocurre si un programa —un editor, un buscador—"
    echo "   tiene abierta la carpeta receta/chroot justo al terminar."
    echo
    echo "   Se vuelve a intentar una vez. Mientras tanto, NO abras esa carpeta."
    echo

    for i in 1 2 3; do
      umount -l "$RECETA/chroot/sys" 2>/dev/null
      umount -l "$RECETA/chroot/proc" 2>/dev/null
      umount -l "$RECETA/chroot/dev/pts" 2>/dev/null
      sleep 2
    done
    mount | grep -q "$RECETA/chroot" && avi "aún queda algo montado; puede volver a fallar"

    printf "   Reintentando a las %s…\n\n" "$(date '+%H:%M')"
    lb build >>"$RECETA/build.log" 2>&1 || true

    GENERADA=$(find "$RECETA" -maxdepth 1 -name 'live-image-amd64.hybrid.iso' -o \
                              -maxdepth 1 -name '*.iso' 2>/dev/null | head -1)
  fi
fi

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

# La huella se guarda CON el nombre del archivo al lado, que es el formato
# que entiende «sha256sum -c». Antes se guardaba el número a secas, y
# entonces la comprobación fallaba con «no properly formatted checksum
# lines found»: el archivo existía y parecía correcto, pero no servía para
# lo único que hace falta —comprobar que un pendrive se grabó entero—.
( cd "$ISOS" && sha256sum "$NOMBRE" > "$NOMBRE.sha256" )
chown "${SUDO_USER:-root}:${SUDO_USER:-root}" "$ISOS/$NOMBRE.sha256" 2>/dev/null

# Comprobarlo aquí mismo. Una huella que no verifica su propio archivo es
# peor que ninguna: da por buena una grabación que nadie ha comprobado.
HUELLA_OK=0
if ( cd "$ISOS" && sha256sum -c --quiet "$NOMBRE.sha256" >/dev/null 2>&1 ); then
  ok "huella comprobada contra la ISO"
  HUELLA_OK=1
else
  mal "la huella NO verifica la ISO — no te fíes de este archivo"
fi

# ── Las ISOs viejas se van solas ──────────────────────────────────────
# Cada construcción deja 2,7 GB y nada las borraba nunca: el 09/08/2026
# había cinco, 14 GB, y cuatro de ellas ya no las iba a instalar nadie.
# Los respaldos se podan solos desde el primer día; esto hacía lo contrario.
#
# Se quedan DOS: la recién hecha y la anterior. La anterior no está por
# nostalgia — es a lo que se vuelve si esta sale mal en una máquina de
# verdad, y eso ya ha pasado en este proyecto.
#
# Tres cosas que no se saltan, porque son las que hacen que esto sea seguro
# y no una manera elegante de perder trabajo:
#
#   · Solo se poda si la ISO nueva PASÓ su huella. Si no verifica, no hay
#     ISO buena que sustituya a las viejas y no se borra ninguna.
#   · Se dice en voz alta cuál desaparece. Una limpieza silenciosa se lee
#     como «aquí no había nada», y no es lo mismo.
#   · El histórico completo no vive aquí: vive fechado en el disco externo,
#     en ISO-COPY-X-FECHAS. Esta carpeta es para trabajar, no para guardar.
CONSERVAR=2
SOBRAN=$(ls -1t "$ISOS"/*.iso 2>/dev/null | tail -n +$((CONSERVAR + 1)))
if [ -n "$SOBRAN" ] && [ "$HUELLA_OK" = "1" ]; then
  printf "\n   ${AZ}Sitio recuperado${V}\n"
  LIBERADO=0
  while IFS= read -r v; do
    [ -f "$v" ] || continue
    LIBERADO=$(( LIBERADO + $(stat -c%s "$v") ))
    printf "      quitada  %s\n" "$(basename "$v")"
    rm -f "$v" "$v.sha256"
  done <<< "$SOBRAN"
  printf "   ${GR}se conservan las %s más recientes · %s libres${V}\n" \
         "$CONSERVAR" "$(numfmt --to=iec "$LIBERADO")"
elif [ -n "$SOBRAN" ]; then
  avi "hay ISOs viejas, pero NO se borra ninguna: la nueva no pasó su huella"
fi

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
