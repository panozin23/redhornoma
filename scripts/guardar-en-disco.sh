#!/bin/bash
# guardar-en-disco.sh — Pone a salvo lo que no se puede rehacer.
#
# El proyecto ocupa 74 GB, pero casi todo se regenera solo: 45 GB son
# discos de las pruebas de compatibilidad, 14 GB son ISOs que se
# reconstruyen en doce minutos, y 13 GB son caché de paquetes bajados.
#
# Lo que NO se puede rehacer son unos pocos megas: el código de las 17
# herramientas, los guiones que construyen y publican, la receta, la
# documentación y las llaves que firman el repositorio. Si eso se pierde,
# el proyecto se pierde — y hasta hoy vivía en un solo disco.
#
# Por eso esto no copia 74 GB cada vez. Copia lo esencial SIEMPRE, y lo
# caro-de-rehacer solo si se pide.
#
# Uso:
#   guardar-en-disco.sh                lo esencial y los respaldos del centro
#   guardar-en-disco.sh --con-isos     además, las ISOs (14 GB, tarda)
#   guardar-en-disco.sh --donde RUTA   a otro sitio distinto del habitual
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
PROYECTOS="$(cd "$BASE/.." && pwd)"
DESTINO="/media/euflo/CURSAKIALINUX/RESPALDOS-CURSALIAS"
CON_ISOS=0
FECHA=$(date '+%Y%m%d-%H%M')

while [ $# -gt 0 ]; do
  case "$1" in
    --con-isos) CON_ISOS=1; shift ;;
    --donde)    DESTINO="${2:-}"; shift 2 ;;
    --ayuda|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "No entiendo «$1»"; exit 1 ;;
  esac
done

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }

FALLOS=0

titulo "GUARDAR LO QUE NO SE PUEDE REHACER"

# El disco tiene que estar enchufado. Decirlo claro es mejor que crear la
# carpeta en el disco interno y creer que hay copia donde no la hay.
if [ ! -d "$DESTINO" ]; then
  mal "no encuentro $DESTINO"
  echo "      ¿Está enchufado el disco externo?"
  echo "      Míralo con:  lsblk -o NAME,LABEL,MOUNTPOINT"
  exit 1
fi
PADRE=$(df -P "$DESTINO" 2>/dev/null | awk 'NR==2{print $6}')
if [ "$PADRE" = "/" ] || [ "$PADRE" = "/home" ]; then
  mal "$DESTINO está en el disco INTERNO, no en el externo"
  echo "      Una copia en el mismo disco no protege de nada."
  exit 1
fi
ok "destino: $DESTINO"
nota "en $PADRE · $(df -h "$DESTINO" | awk 'NR==2{print $4}') libres"

# ── 1 · Lo esencial ───────────────────────────────────────────────────
# Va comprimido y fechado, no como carpeta suelta: así cada copia es una
# foto completa de un momento, y se pueden guardar varias sin que se
# mezclen. Ocupa poco: son unos pocos megas.
titulo "1 · EL PROYECTO"
mkdir -p "$DESTINO/PROYECTO"
TAR="$DESTINO/PROYECTO/proyecto-$FECHA.tar.gz"

printf "   %-32s " "empaquetando lo irreemplazable"
# Se nombran las carpetas de cursalialinux una por una, en vez de meterla
# entera. Su carpeta «cocina» son 16 GB de construcción que se regeneran
# igual que el «chroot» de RedHornoma. El primer intento la metió entera y
# el empaquetado no terminaba: 09/08/2026.
if tar -czf "$TAR" -C "$PROYECTOS" \
     --exclude='*/receta/chroot' --exclude='*/receta/binary' \
     --exclude='*/receta/cache' --exclude='*/pruebas/*/disco.qcow2' \
     --exclude='*/isos' --exclude='*.iso' --exclude='*/cocina' \
     redhornoma/paquetes redhornoma/scripts redhornoma/receta \
     redhornoma/documentacion redhornoma/repositorio redhornoma/pruebas \
     redhornoma/HANDOFF.md redhornoma/VERSION \
     cursalialinux/paquetes cursalialinux/scripts cursalialinux/recetas \
     cursalialinux/documentacion cursalialinux/repositorio \
     cursalialinux/plasmoides cursalialinux/marca 2>/dev/null; then
  printf "${VE}%s${V}\n" "$(du -h "$TAR" | cut -f1)"
else
  printf "${RO}falló${V}\n"; FALLOS=$((FALLOS+1))
fi

# Un paquete sin comprobar no es un respaldo. Se abre para verificar.
printf "   %-32s " "comprobando que abre"
if tar -tzf "$TAR" >/dev/null 2>&1; then
  N=$(tar -tzf "$TAR" 2>/dev/null | wc -l)
  printf "${VE}%s archivos${V}\n" "$N"
else
  printf "${RO}NO ABRE${V}\n"; mal "ese paquete no sirve"; FALLOS=$((FALLOS+1))
fi

# Se conservan las 8 últimas. Ocupan poco, y tener varias fechas permite
# volver a un estado anterior si algo se rompió hace días y no se notó.
VIEJAS=$(ls -1t "$DESTINO/PROYECTO"/proyecto-*.tar.gz 2>/dev/null | tail -n +9)
if [ -n "$VIEJAS" ]; then
  echo "$VIEJAS" | while read -r f; do rm -f "$f"; done
  nota "se conservan las 8 copias más recientes"
fi

# ── 2 · Las llaves ────────────────────────────────────────────────────
# Sin la llave del repositorio no se puede volver a publicar un paquete
# firmado, y los centros rechazarían las actualizaciones. Es de las cosas
# que no se pueden rehacer de ninguna manera.
titulo "2 · LAS LLAVES"
mkdir -p "$DESTINO/LLAVES"
CLAVE=$(grep -oP '^CLAVE_GPG=\K.*' "$BASE/scripts/repositorio.conf" 2>/dev/null)
if [ -n "$CLAVE" ]; then
  printf "   %-32s " "llave del repositorio ($CLAVE)"
  if gpg --export "$CLAVE" > "$DESTINO/LLAVES/redhornoma-publica.gpg" 2>/dev/null \
     && gpg --export-secret-keys --armor "$CLAVE" > "$DESTINO/LLAVES/redhornoma-privada.asc" 2>/dev/null \
     && [ -s "$DESTINO/LLAVES/redhornoma-privada.asc" ]; then
    chmod 600 "$DESTINO/LLAVES/redhornoma-privada.asc" 2>/dev/null
    printf "${VE}guardada${V}\n"
  else
    printf "${RO}falló${V}\n"
    avi "si la llave pide contraseña, hay que exportarla a mano"
    FALLOS=$((FALLOS+1))
  fi
else
  avi "no encuentro CLAVE_GPG en scripts/repositorio.conf"
fi

for f in /home/euflo/llave-bitlocker-olivos.txt; do
  [ -f "$f" ] && cp -f "$f" "$DESTINO/LLAVES/" 2>/dev/null && ok "$(basename "$f")"
done

# ── 3 · Los respaldos del centro ──────────────────────────────────────
# Viven en el servidor y hoy solo tienen una copia fuera: la nube. Traerlos
# aquí les da una segunda, y en un disco que se puede llevar en la mano.
titulo "3 · LOS RESPALDOS DEL CENTRO"
SRV=flora@192.168.0.110
if timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$SRV" true 2>/dev/null; then
  mkdir -p "$DESTINO/DEL-SERVIDOR"
  printf "   %-32s " "trayendo del servidor"
  # El error NO se tira a la basura. La primera vez esto decía solo «falló» y
  # hubo que repetir el rsync a mano para enterarse de que el problema era un
  # único archivo sin permiso de lectura. Un fallo que no dice por qué obliga
  # a investigar dos veces: 09/08/2026.
  SALIDA=$(rsync -rt --no-perms --no-owner --no-group \
       "$SRV:/var/lib/redhornoma/respaldos/" "$DESTINO/DEL-SERVIDOR/" 2>&1)
  if [ $? -eq 0 ]; then
    printf "${VE}%s${V}\n" "$(du -sh "$DESTINO/DEL-SERVIDOR" | cut -f1)"
  else
    printf "${AM}con avisos${V}\n"
    echo "$SALIDA" | grep -v '^rsync error:' | head -4 | sed 's/^/      /'
    FALLOS=$((FALLOS+1))
  fi

  # No basta con que el rsync termine: se cuenta qué llegó. Una copia del
  # centro sin su archivo CORRECTO es una copia que el servidor ya había
  # dado por mala, y conviene verlo aquí y no el día que haga falta.
  # Las carpetas «antes-del-rescate-*» se cuentan aparte, no como dudosas.
  # No las hace el respaldo: son la foto de las bases VIVAS tomada justo
  # antes de restaurar, para poder deshacer la restauración. Nunca pasan por
  # la verificación, así que nunca llevan la marca — y contarlas como
  # sospechosas hacía saltar el aviso en cada ejecución. Un aviso que salta
  # siempre deja de leerse. Corregido el 09/08/2026.
  BUENAS=0; DUDOSAS=0; RESCATES=0
  for c in "$DESTINO/DEL-SERVIDOR"/*/; do
    [ -d "$c" ] || continue
    case "$(basename "$c")" in
      antes-del-rescate-*) RESCATES=$((RESCATES+1)); continue ;;
    esac
    if [ -f "$c/CORRECTO" ]; then BUENAS=$((BUENAS+1)); else DUDOSAS=$((DUDOSAS+1)); fi
  done
  nota "$BUENAS copias del centro verificadas${RESCATES:+ · $RESCATES fotos de antes de restaurar}"
  [ "$DUDOSAS" -gt 0 ] && avi "$DUDOSAS copias SIN verificar — mirar por qué"
else
  avi "el servidor no responde — los respaldos del centro no se traen esta vez"
  nota "no es grave si se hace otro día; el servidor conserva los suyos"
fi

# ── 4 · Las ISOs, solo si se piden ────────────────────────────────────
# Solo la ÚLTIMA, y en una carpeta con su fecha. Guardarlas todas sería
# acumular 14 GB de versiones que ya nadie va a instalar; guardar solo una
# sin fecha sería no saber cuál es. Con --con-isos van todas.
titulo "4 · LA ISO"
ULTIMA=$(ls -1t "$BASE"/isos/*.iso 2>/dev/null | head -1)
if [ -z "$ULTIMA" ]; then
  avi "no hay ninguna ISO construida todavía"
else
  # La fecha sale del nombre de la ISO, no del día de hoy: así la carpeta
  # dice cuándo se CONSTRUYÓ, que es lo que importa para saber qué lleva.
  FECHA_ISO=$(basename "$ULTIMA" | grep -oP '\d{8}' | head -1)
  [ -n "$FECHA_ISO" ] || FECHA_ISO=$(date -r "$ULTIMA" '+%Y%m%d')
  CARP="$DESTINO/ISO-COPY-X-FECHAS/$FECHA_ISO"
  mkdir -p "$CARP"
  printf "   %-32s " "$(basename "$ULTIMA") ($(du -h "$ULTIMA" | cut -f1))"
  # Se compara la HUELLA, nunca el tamaño.
  #
  # El 09/08/2026 se construyeron dos ISOs el mismo día: la segunda arreglaba
  # el menú de arranque de las máquinas antiguas. Mismo nombre —lleva la
  # fecha, no la hora— y **exactamente el mismo tamaño**: 2.843.770.880 bytes
  # las dos. Comparando tamaños, esto decía «ya estaba» y el disco externo se
  # habría quedado con la defectuosa para siempre, creyendo estar al día.
  # Un respaldo que miente sobre su contenido es peor que no tenerlo.
  #
  # No hace falta releer los 2,7 GB: construir-iso.sh deja la huella al lado
  # de la ISO, y aquí se guardó la de la copia. Se comparan los dos papeles.
  HUELLA_AQUI=$(cut -d' ' -f1 "$ULTIMA.sha256" 2>/dev/null)
  [ -n "$HUELLA_AQUI" ] || HUELLA_AQUI=$(sha256sum "$ULTIMA" | cut -d' ' -f1)
  HUELLA_ALLA=$(grep -F "$(basename "$ULTIMA")" "$CARP/SHA256SUMS" 2>/dev/null | cut -d' ' -f1)

  if [ -f "$CARP/$(basename "$ULTIMA")" ] && [ -n "$HUELLA_ALLA" ] \
     && [ "$HUELLA_AQUI" = "$HUELLA_ALLA" ]; then
    printf "${GR}ya estaba, misma huella${V}\n"
  elif rsync -t --no-perms "$ULTIMA" "$CARP/" 2>/dev/null; then
    printf "${VE}copiada${V}\n"
    printf "   %-32s " "comprobando la huella"
    ( cd "$CARP" && sha256sum "$(basename "$ULTIMA")" > SHA256SUMS 2>/dev/null )
    if ( cd "$CARP" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ); then
      printf "${VE}coincide${V}\n"
    else
      printf "${RO}NO coincide${V}\n"; mal "esa copia salió mal"; FALLOS=$((FALLOS+1))
    fi
  else
    printf "${RO}falló${V}\n"; FALLOS=$((FALLOS+1))
  fi
  nota "en ISO-COPY-X-FECHAS/$FECHA_ISO/"
fi

if [ "$CON_ISOS" = "1" ]; then
  printf "\n   %-32s " "y las demás (14 GB, tarda)"
  if rsync -rt --no-perms "$BASE/isos/" "$DESTINO/ISO-COPY-X-FECHAS/todas/" 2>/dev/null; then
    printf "${VE}hecho${V}\n"
    ( cd "$DESTINO/ISO-COPY-X-FECHAS/todas" && sha256sum *.iso > SHA256SUMS 2>/dev/null )
  else
    printf "${RO}falló${V}\n"; FALLOS=$((FALLOS+1))
  fi
fi

# ── Dejar constancia ──────────────────────────────────────────────────
{
  printf 'Guardado por RedHornoma\n'
  printf 'Fecha:     %s\n' "$(date '+%d de %B de %Y, %H:%M')"
  printf 'Desde:     %s\n' "$(cat /proc/sys/kernel/hostname)"
  printf '\nQué hay aquí:\n'
  printf '  PROYECTO/      el código, los guiones y la receta. Lo irreemplazable.\n'
  printf '  LLAVES/        la que firma el repositorio y la de BitLocker.\n'
  printf '  DEL-SERVIDOR/  los respaldos del centro traídos de Cochabamba.\n'
  printf '  ISO-COPY-X-FECHAS/  la última ISO, en una carpeta con su fecha.\n'
  printf '\nLo que NO se guarda, porque se regenera solo:\n'
  printf '  los discos de las pruebas (45 GB) y las cachés de la receta (13 GB).\n'
  printf '\nPara volver a tener el proyecto:\n'
  printf '  tar -xzf PROYECTO/proyecto-FECHA.tar.gz -C /donde/sea\n'
} > "$DESTINO/LEEME.txt"

titulo "RESULTADO"
if [ "$FALLOS" = "0" ]; then
  ok "todo guardado y comprobado"
else
  mal "$FALLOS parte(s) fallaron — míralo antes de fiarte de esta copia"
fi
printf "   %-22s %s\n" "ocupa en total:" "$(du -sh "$DESTINO" 2>/dev/null | cut -f1)"
printf "   %-22s %s\n" "queda libre:" "$(df -h "$DESTINO" | awk 'NR==2{print $4}')"
echo
[ "$FALLOS" = "0" ] || exit 1
