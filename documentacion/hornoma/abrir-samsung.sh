#!/bin/bash
# abrir-samsung.sh — Abrir el disco Samsung en el .101, y si no se deja,
#                    decir POR QUÉ con sus palabras exactas.
#
# EL PORQUÉ
#
# El disco está enchufado y el /etc/fstab lo tiene bien apuntado, pero al
# pedir «mount» no monta. El motivo no se puede adivinar: hay que leer el
# mensaje del núcleo, y eso solo lo puede hacer root. Sin permiso, el
# diario sale VACÍO — y un vacío se lee como «no dijo nada», que es
# exactamente lo contrario de la verdad.
#
# Las tres causas normales, y las tres se distinguen por su mensaje:
#
#   1. El disco viene SUCIO de Windows. Es lo más frecuente. Windows 10 y
#      11 traen el «inicio rápido» encendido de fábrica: al apagar no
#      cierran del todo, dejan el disco marcado como en uso, y el
#      controlador ntfs3 se niega a escribir en él para no estropearlo.
#      Hace bien: montar a la fuerza un NTFS a medio cerrar es la forma
#      más típica de perder archivos.
#
#   2. El controlador ntfs3 no se lleva bien con ese disco concreto. Para
#      eso está ntfs-3g, que es más lento pero más tolerante.
#
#   3. El disco tiene daño de verdad. Este Samsung lleva 6 sectores que no
#      consigue leer bien y hace «clac clac» — así que hay que mirarlo.
#
# Uso:
#   sudo bash abrir-samsung.sh              intenta abrirlo y explica qué pasa
#   sudo bash abrir-samsung.sh --arreglar   además, limpia la marca de «en uso»
#   sudo bash abrir-samsung.sh --soltar     lo desmonta para desenchufarlo
#
# «--arreglar» ESCRIBE en el disco. Por eso va aparte: primero se mira,
# después se decide. Ver la regla de los dos pasos del proyecto.
set -u

MODELO='HN-M101ABB'
USUARIO=hornoma

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

ARREGLAR=no; SOLTAR=no
case "${1:-}" in
  --arreglar) ARREGLAR=si ;;
  --soltar)   SOLTAR=si ;;
  "")         ;;
  *) echo "Uso: $0 [--arreglar | --soltar]"; exit 1 ;;
esac

[ "$(id -u)" = "0" ] || { mal "hace falta sudo — sin root no se leen los mensajes del núcleo"; exit 1; }

# ── Encontrar el disco por su MODELO, nunca por la letra ──────────────
# «sdb» hoy puede ser «sdc» mañana según el orden en que se enchufen las
# cosas. El modelo no cambia.
DISCO=""
for d in /dev/sd?; do
  [ -b "$d" ] || continue
  MOD=$(lsblk -dno MODEL "$d" 2>/dev/null)
  case "$MOD" in *$MODELO*|*"M3 Portable"*) DISCO="$d"; break ;; esac
done

titulo "ABRIR EL DISCO SAMSUNG"

if [ -z "$DISCO" ]; then
  mal "el disco Samsung no está enchufado a esta computadora"
  echo "      Se buscó por su modelo ($MODELO) entre todos los discos."
  exit 1
fi
ok "encontrado en $DISCO"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISCO" | sed 's/^/      /'

PARTES=$(lsblk -lno NAME,FSTYPE "$DISCO" | awk '$2=="ntfs"{print $1}')
[ -n "$PARTES" ] || { mal "no tiene ninguna partición NTFS que abrir"; exit 1; }

# ── Soltar ────────────────────────────────────────────────────────────
if [ "$SOLTAR" = "si" ]; then
  printf "\n   ${AZ}Soltándolo${V}\n"
  for p in $PARTES; do
    PUNTO=$(findmnt -nro TARGET "/dev/$p" 2>/dev/null)
    [ -n "$PUNTO" ] || { nota "/dev/$p no estaba montada"; continue; }
    if umount "/dev/$p" 2>/dev/null; then ok "$p soltada ($PUNTO)"
    else mal "$p no se deja soltar — alguien la está usando"
         fuser -vm "$PUNTO" 2>&1 | sed 's/^/      /'; fi
  done
  echo; nota "Ya se puede desenchufar."
  exit 0
fi

# ── Intentar abrir cada partición, y guardar el error EXACTO ──────────
printf "\n   ${AZ}Intentando abrir${V}\n"

SUCIO=0
for p in $PARTES; do
  ETIQ=$(lsblk -dno LABEL "/dev/$p" 2>/dev/null); ETIQ="${ETIQ:-$p}"
  PUNTO="/media/$USUARIO/$ETIQ"

  if findmnt -nro TARGET "/dev/$p" >/dev/null 2>&1; then
    ok "$ETIQ ya estaba abierta en $(findmnt -nro TARGET "/dev/$p")"
    continue
  fi

  mkdir -p "$PUNTO"

  # Marca de dónde empezamos a mirar, para no leer errores de hace un rato.
  ANTES=$(date '+%Y-%m-%d %H:%M:%S')
  sleep 1

  ERR1=$(mount -t ntfs3 -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO"),windows_names \
           "/dev/$p" "$PUNTO" 2>&1)
  if [ -z "$ERR1" ] && findmnt -nro TARGET "/dev/$p" >/dev/null 2>&1; then
    ok "$ETIQ abierta con ntfs3 en $PUNTO"
    continue
  fi

  printf "   ${AM}⚠️ ${V} %s\n" "$ETIQ no se dejó abrir con ntfs3. Lo que dijo:"
  printf '%s\n' "$ERR1" | sed 's/^/         /'
  # ESTO es lo que no se puede leer sin root, y es donde está la razón.
  DMESG=$(journalctl -k --since "$ANTES" --no-pager 2>/dev/null | grep -i -E "ntfs|$p" | tail -6)
  [ -n "$DMESG" ] && { echo "         — y el núcleo:"; printf '%s\n' "$DMESG" | sed 's/^/         /'; }

  case "$ERR1$DMESG" in
    *[Dd]irty*|*"volume is dirty"*|*unclean*|*hibernat*|*"was not shut down"*)
      SUCIO=1
      avi "$ETIQ viene marcada como EN USO por Windows" ;;
  esac

  # ── Segundo intento: ntfs-3g, más lento pero más tolerante ──────────
  printf "   %-30s " "probando con ntfs-3g"
  ERR2=$(mount -t ntfs-3g -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO") \
           "/dev/$p" "$PUNTO" 2>&1)
  if [ -z "$ERR2" ] && findmnt -nro TARGET "/dev/$p" >/dev/null 2>&1; then
    printf "${VE}abierta${V}\n"
    nota "Va con ntfs-3g. Es más lento que ntfs3, pero se lee y se escribe igual."
    continue
  fi
  printf "${RO}tampoco${V}\n"
  printf '%s\n' "$ERR2" | sed 's/^/         /'
  case "$ERR2" in
    *[Dd]irty*|*unclean*|*hibernat*|*"was not shut down"*|*"Metadata kept"*) SUCIO=1 ;;
  esac

  # ── Tercer intento, solo si se pidió arreglar ───────────────────────
  if [ "$ARREGLAR" = "si" ]; then
    printf "   %-30s " "limpiando la marca de «en uso»"
    SAL=$(ntfsfix -d "/dev/$p" 2>&1)
    printf "\n"; printf '%s\n' "$SAL" | sed 's/^/         /'
    if mount -t ntfs3 -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO"),windows_names \
         "/dev/$p" "$PUNTO" 2>/dev/null \
       || mount -t ntfs-3g -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO") \
         "/dev/$p" "$PUNTO" 2>/dev/null; then
      ok "$ETIQ abierta después de limpiarla"
    else
      mal "$ETIQ sigue sin abrirse"
    fi
  fi
done

# ── Cómo quedó ────────────────────────────────────────────────────────
printf "\n   ${AZ}Cómo queda${V}\n"
ABIERTAS=0
for p in $PARTES; do
  PUNTO=$(findmnt -nro TARGET "/dev/$p" 2>/dev/null)
  if [ -n "$PUNTO" ]; then
    ABIERTAS=$((ABIERTAS+1))
    printf "      %-12s %s\n" "$p" "$PUNTO  ·  $(df -h "$PUNTO" | tail -1 | awk '{print $2" total, "$4" libres"}')"
    printf "      %-12s %s\n" "" "$(ls -1 "$PUNTO" 2>/dev/null | head -4 | tr '\n' ' ')…"
  else
    printf "      %-12s %s\n" "$p" "cerrada"
  fi
done

if [ "$ABIERTAS" = "0" ] && [ "$SUCIO" = "1" ] && [ "$ARREGLAR" = "no" ]; then
  printf "\n${AM}══════════════════════════════════════════════════════${V}\n"
  printf "   El disco viene marcado como EN USO por Windows.\n\n"
  printf "   No está roto: es el «inicio rápido» de Windows, que al apagar\n"
  printf "   no cierra del todo el disco. Linux se niega a escribir en él\n"
  printf "   para no estropear lo que haya dentro, y hace bien.\n\n"
  printf "   Se limpia con:\n\n"
  printf "      sudo bash %s --arreglar\n\n" "$(basename "$0")"
  printf "   Eso ESCRIBE en el disco: solo quita la marca, no toca ningún\n"
  printf "   archivo. Por eso va en un comando aparte y no automático.\n\n"
fi

# ── La salud del disco, como información ──────────────────────────────
# Este disco lleva 6 sectores pendientes y hace «clac clac». Se enseña
# siempre, pero no frena nada: es decisión de euflo.
if command -v smartctl >/dev/null 2>&1; then
  PEND=$(smartctl -A "$DISCO" 2>/dev/null | awk '/Current_Pending_Sector/{print $10}')
  if [ -n "$PEND" ] && [ "$PEND" != "0" ]; then
    printf "\n   ${AM}Salud del disco:${V} %s sectores que no consigue leer bien.\n" "$PEND"
    nota "No frena nada. Pero lo que solo esté aquí, no está a salvo."
  fi
fi
echo
