#!/bin/bash
# montar-samsung.sh — Abrir el disco Samsung, igual que el Toshiba.
#
# Lo monta con lectura y escritura, lo deja en /media/<usuario>/ con su
# etiqueta, y opcionalmente lo apunta para que se abra solo al arrancar.
#
# Muestra de paso la salud del disco: es solo información, no impide nada.
#
# Uso:
#   sudo bash montar-samsung.sh            lo monta ahora
#   sudo bash montar-samsung.sh --siempre  además, que se monte solo al arrancar
#   sudo bash montar-samsung.sh --soltar   lo desmonta para poder desenchufarlo
set -u

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }

SIEMPRE=no; SOLTAR=no
for a in "$@"; do
  case "$a" in
    --siempre) SIEMPRE=si ;;
    --soltar)  SOLTAR=si ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "No entiendo «$a»"; exit 1 ;;
  esac
done
[ "$(id -u)" = "0" ] || { echo "Hace falta administrador:  sudo bash $0"; exit 1; }

USUARIO=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)
BASE=/media/$USUARIO

# ── Encontrar el disco por su modelo, no por la letra ─────────────────────
# «sdb» hoy puede ser «sdc» mañana según el orden en que se enchufen. El
# modelo no cambia.
DISCO=""
for d in /dev/sd?; do
  [ -b "$d" ] || continue
  MOD=$(lsblk -dno MODEL "$d" 2>/dev/null)
  case "$MOD" in *HN-M101ABB*|*M3\ Portable*) DISCO="$d"; break ;; esac
done

# ══ SOLTAR ════════════════════════════════════════════════════════════════
if [ "$SOLTAR" = "si" ]; then
  titulo "SOLTANDO EL SAMSUNG"
  [ -n "$DISCO" ] || { mal "no lo encuentro enchufado"; exit 1; }
  N=0
  for p in $(lsblk -lno NAME "$DISCO" 2>/dev/null | tail -n +2); do
    PUNTO=$(findmnt -nro TARGET -S "/dev/$p" 2>/dev/null)
    [ -n "$PUNTO" ] || continue
    sync
    if umount "/dev/$p" 2>/dev/null; then ok "soltado: $PUNTO"; N=$((N+1))
    else mal "no se pudo soltar $PUNTO — hay algo abierto ahí dentro"; fi
  done
  [ "$N" = "0" ] && nota "no estaba montado"
  echo; nota "ya puedes desenchufarlo"; echo
  exit 0
fi

# ══ 1 · ¿ESTÁ EL DISCO? ═══════════════════════════════════════════════════
titulo "1 · BUSCANDO EL SAMSUNG"
if [ -z "$DISCO" ]; then
  mal "no encuentro el Samsung enchufado a esta máquina"
  nota "comprueba el cable USB y vuelve a intentarlo"
  exit 1
fi
ok "encontrado en $DISCO  ($(lsblk -dno MODEL "$DISCO"), $(lsblk -dno SIZE "$DISCO"))"

# ══ 2 · SALUD (solo para saberlo) ═════════════════════════════════════════
titulo "2 · CÓMO ESTÁ DE SALUD"
if command -v smartctl >/dev/null 2>&1; then
  SM=$(smartctl -H -A -d sat "$DISCO" 2>/dev/null)
  [ -n "$SM" ] || SM=$(smartctl -H -A "$DISCO" 2>/dev/null)
  VER=$(printf '%s\n' "$SM" | grep -i "overall-health" | sed 's/.*: *//')
  PEND=$(printf '%s\n' "$SM" | awk '/Current_Pending_Sector/{print $10}')
  REAL=$(printf '%s\n' "$SM" | awk '/Reallocated_Sector_Ct/{print $10}')
  INCO=$(printf '%s\n' "$SM" | awk '/Offline_Uncorrectable/{print $10}')
  HORA=$(printf '%s\n' "$SM" | awk '/Power_On_Hours/{print $10}')
  printf "   %-32s %s\n" "veredicto del propio disco:"   "${VER:-no lo dice}"
  printf "   %-32s %s\n" "sectores esperando ser malos:" "${PEND:-?}"
  printf "   %-32s %s\n" "sectores ya dados por malos:"  "${REAL:-?}"
  printf "   %-32s %s\n" "sectores ilegibles:"           "${INCO:-?}"
  [ -n "${HORA:-}" ] && printf "   %-32s %s\n" "horas encendido en su vida:" "$HORA"
else
  nota "no está smartctl, no puedo ver la salud"
fi

# ══ 3 · MONTAR ════════════════════════════════════════════════════════════
titulo "3 · ABRIENDO EL DISCO"
mkdir -p "$BASE"
MONTADAS=0
for p in $(lsblk -lno NAME "$DISCO" 2>/dev/null | tail -n +2); do
  ETIQ=$(lsblk -no LABEL "/dev/$p" 2>/dev/null | tr -d ' ')
  [ -n "$ETIQ" ] || ETIQ="$p"
  PUNTO="$BASE/$ETIQ"

  YA=$(findmnt -nro TARGET -S "/dev/$p" 2>/dev/null)
  if [ -n "$YA" ]; then ok "$ETIQ ya estaba abierto en $YA"; MONTADAS=$((MONTADAS+1)); continue; fi

  mkdir -p "$PUNTO"
  # uid/gid para poder usarlo sin ser administrador, igual que el Toshiba.
  # Si el Windows lo dejó hibernado, ntfs3 se niega; entonces entra ntfs-3g.
  if mount -t ntfs3 -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO"),windows_names "/dev/$p" "$PUNTO" 2>/dev/null \
  || mount -t ntfs-3g -o rw,uid=$(id -u "$USUARIO"),gid=$(id -g "$USUARIO") "/dev/$p" "$PUNTO" 2>/dev/null; then
    if touch "$PUNTO/.prueba" 2>/dev/null; then rm -f "$PUNTO/.prueba"; COMO="se puede leer y escribir"
    else COMO="solo lectura (el disco o el Windows no dejan escribir)"; fi
    ok "$ETIQ abierto en $PUNTO — $COMO"
    MONTADAS=$((MONTADAS+1))
  else
    mal "$ETIQ no se dejó abrir"
    nota "$(mount -t ntfs3 "/dev/$p" "$PUNTO" 2>&1 | head -2)"
    rmdir "$PUNTO" 2>/dev/null
  fi
done

[ "$MONTADAS" = "0" ] && { echo; mal "no se pudo abrir ninguna parte del disco"; exit 1; }

# ══ 4 · SIEMPRE (opcional) ════════════════════════════════════════════════
if [ "$SIEMPRE" = "si" ]; then
  titulo "4 · QUE SE ABRA SOLO AL ARRANCAR"
  for p in $(lsblk -lno NAME "$DISCO" 2>/dev/null | tail -n +2); do
    UUID=$(lsblk -no UUID "/dev/$p" 2>/dev/null | tr -d ' ')
    ETIQ=$(lsblk -no LABEL "/dev/$p" 2>/dev/null | tr -d ' '); [ -n "$ETIQ" ] || ETIQ="$p"
    [ -n "$UUID" ] || { avi "$ETIQ no tiene identificador, se salta"; continue; }
    grep -q "$UUID" /etc/fstab 2>/dev/null && { nota "$ETIQ ya estaba apuntado"; continue; }
    # «nofail» es imprescindible: sin eso, arrancar con el disco desenchufado
    # dejaría la máquina parada pidiendo auxilio, y nadie va a ir a Hornoma.
    printf 'UUID=%s  %s/%s  ntfs3  rw,nofail,x-systemd.device-timeout=10,uid=%s,gid=%s  0  0\n' \
      "$UUID" "$BASE" "$ETIQ" "$(id -u "$USUARIO")" "$(id -g "$USUARIO")" >> /etc/fstab
    ok "$ETIQ se abrirá solo al arrancar"
  done
  systemctl daemon-reload 2>/dev/null
  nota "con «nofail»: si algún día no está el disco, la máquina arranca igual"
fi

# ══ 5 · QUÉ HAY DENTRO ════════════════════════════════════════════════════
titulo "QUÉ HAY DENTRO"
for PUNTO in "$BASE"/*; do
  findmnt -nro SOURCE "$PUNTO" 2>/dev/null | grep -q "$DISCO" || continue
  echo
  printf "   ${AZ}%s${V}   (%s libres)\n" "$PUNTO" "$(df -h --output=avail "$PUNTO" 2>/dev/null | tail -1 | tr -d ' ')"
  ls -1 "$PUNTO" 2>/dev/null | head -25 | sed 's/^/      /'
  TOT=$(ls -1 "$PUNTO" 2>/dev/null | wc -l)
  [ "$TOT" -gt 25 ] && nota "   … y $((TOT-25)) cosas más"
done

echo
nota "para desenchufarlo:  sudo bash $0 --soltar"
echo
