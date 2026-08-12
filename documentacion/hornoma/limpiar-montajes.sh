#!/bin/bash
# limpiar-montajes.sh — Dejar el /etc/fstab con UNA sola línea por carpeta
#                       del Windows, y comprobarlo montando de verdad.
#
# EL PORQUÉ
#
# El 12/08/2026 el /etc/fstab acabó con SOAPS y SNIS repetidas tres veces,
# y systemd se queda con la PRIMERA — que era la de las credenciales rotas.
# Por eso SALMI montaba y las otras dos no: SALMI había quedado una sola vez.
#
# La causa fue una limpieza escrita así:
#
#     sed '/# RedHornoma canal Windows/,+3d'
#
# «la línea del comentario y tres más». Pero el bloque tenía 3 líneas de
# comentario y 3 de montaje: se llevaba los comentarios y SALMI, y dejaba
# huérfanas a SOAPS y SNIS. Al volver a ejecutarlo se añadían otra vez.
#
# CONTAR LÍNEAS ES UNA FORMA FRÁGIL DE BORRAR. Basta con añadir un
# comentario para que se lleve por delante lo que no debía.
#
# Aquí se borra por lo que la línea ES —un montaje bajo /mnt/windows— y el
# bloque de comentarios se reconoce por su marca de principio y de fin.
#
# Uso:
#   sudo bash limpiar-montajes.sh
#   sudo bash limpiar-montajes.sh --solo-mirar
set -u

CRED_CIFS=/etc/redhornoma/windows-cifs.credenciales
MONTAJE=/mnt/windows
IP=192.168.122.226
MARCA="$(date '+%Y%m%d-%H%M')"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

SOLO_MIRAR=no
case "${1:-}" in --solo-mirar) SOLO_MIRAR=si ;; "") ;; *) echo "Uso: $0 [--solo-mirar]"; exit 1 ;; esac
[ "$(id -u)" = "0" ] || { echo "Hace falta sudo"; exit 1; }

titulo "UNA SOLA LÍNEA POR CARPETA EN EL FSTAB"

printf "\n   ${AZ}Cómo está ahora${V}\n"
for c in SALMI SOAPS SNIS; do
  N=$(awk -v p="$MONTAJE/$c" '$2==p' /etc/fstab 2>/dev/null | grep -c .)
  printf "      %-8s %s línea(s)%s\n" "$c" "$N" "$([ "$N" -gt 1 ] && echo "  ← repetida")"
done

[ -f "$CRED_CIFS" ] || { mal "falta $CRED_CIFS — ejecuta antes arreglar-montajes.sh"; exit 1; }
ok "credenciales limpias: $CRED_CIFS"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi

# ── Soltar lo que hubiera montado ─────────────────────────────────────
for c in SALMI SOAPS SNIS; do
  systemctl stop "$(systemd-escape -p --suffix=automount "$MONTAJE/$c")" 2>/dev/null
  systemctl stop "$(systemd-escape -p --suffix=mount     "$MONTAJE/$c")" 2>/dev/null
  umount -l "$MONTAJE/$c" 2>/dev/null
done

# ── Limpiar por LO QUE LA LÍNEA ES, no por cuántas hay ────────────────
printf "\n   ${AZ}Limpiando${V}\n"
cp -f /etc/fstab "/etc/fstab.antes-de-limpiar-$MARCA" && ok "copia guardada: /etc/fstab.antes-de-limpiar-$MARCA"

awk -v m="$MONTAJE/" '
  # Cualquier montaje cuyo destino cuelgue de /mnt/windows: fuera.
  $2 ~ ("^" m) { next }
  # El bloque de comentarios, reconocido por su marca de principio y fin.
  /^# >>> RedHornoma canal Windows/ { dentro=1; next }
  /^# <<< RedHornoma canal Windows/ { dentro=0; next }
  dentro { next }
  # Y los comentarios de las versiones viejas, que no llevaban marca.
  /^# RedHornoma canal Windows/ { viejo=1; next }
  viejo && /^#/ { next }
  { viejo=0; print }
' /etc/fstab > /tmp/fstab.nuevo

QUEDAN=$(awk -v m="$MONTAJE/" '$2 ~ ("^" m)' /tmp/fstab.nuevo | grep -c . || true)
[ "$QUEDAN" = "0" ] || { mal "todavía quedan $QUEDAN líneas: no toco nada"; rm -f /tmp/fstab.nuevo; exit 1; }
ok "no queda ninguna línea vieja"

UID_H=$(id -u hornoma); GID_H=$(id -g hornoma)
{
  printf '\n# >>> RedHornoma canal Windows — NO editar a mano entre las marcas.\n'
  printf '# Las carpetas del Windows de este equipo, vistas desde Linux.\n'
  printf '# Se montan solas al abrirlas, y no bloquean el arranque si está apagado.\n'
  for c in SALMI SOAPS SNIS; do
    printf '//%s/%s  %s/%s  cifs  credentials=%s,vers=3.0,noauto,x-systemd.automount,x-systemd.idle-timeout=300,uid=%s,gid=%s,file_mode=0664,dir_mode=0775,nofail  0  0\n' \
      "$IP" "$c" "$MONTAJE" "$c" "$CRED_CIFS" "$UID_H" "$GID_H"
  done
  printf '# <<< RedHornoma canal Windows\n'
} >> /tmp/fstab.nuevo

# Que systemd lo entienda ANTES de dejarlo puesto.
cp -f /tmp/fstab.nuevo /etc/fstab
rm -f /tmp/fstab.nuevo
for c in SALMI SOAPS SNIS; do
  N=$(awk -v p="$MONTAJE/$c" '$2==p' /etc/fstab | grep -c .)
  printf "      %-8s %s línea\n" "$c" "$N"
done

mkdir -p "$MONTAJE"/{SALMI,SOAPS,SNIS}
systemctl daemon-reload
for c in SALMI SOAPS SNIS; do
  systemctl start "$(systemd-escape -p --suffix=automount "$MONTAJE/$c")" 2>/dev/null
done

# ── Comprobar montando de verdad ──────────────────────────────────────
# 🔴 El tipo se comprueba con «grep cifs», no comparando con "cifs".
# Con automount hay DOS montajes apilados en la misma carpeta —el portero
# autofs y encima el de verdad— y findmnt devuelve las DOS líneas. Compararlo
# con la palabra suelta falla aunque esté perfectamente montado. Me pasó.
printf "\n   ${AZ}Comprobando${V}\n"
BIEN=0
for c in SALMI SOAPS SNIS; do
  printf "      %-8s " "$c"
  ls "$MONTAJE/$c" >/dev/null 2>&1; sleep 1     # tocar para que el portero abra
  if findmnt -nro FSTYPE "$MONTAJE/$c" 2>/dev/null | grep -q '^cifs$'; then
    printf "${VE}montada${V}  (%s elementos)\n" "$(ls -1 "$MONTAJE/$c" 2>/dev/null | wc -l)"
    BIEN=$((BIEN+1))
  else
    printf "${RO}NO${V}\n"
    systemctl status "$(systemd-escape -p --suffix=mount "$MONTAJE/$c")" --no-pager 2>&1 \
      | grep -iE "error|denied|failed" | head -2 | sed 's/^/         /'
  fi
done

# La prueba que no se puede fingir: escribir aquí y verlo allá.
printf "\n      %-32s " "escribir desde Linux"
SELLO=".canal-$MARCA"
if findmnt -nro FSTYPE "$MONTAJE/SALMI" 2>/dev/null | grep -q '^cifs$' \
   && touch "$MONTAJE/SALMI/$SELLO" 2>/dev/null; then
  VISTO=$(redhornoma-en-windows --powershell \
    "if (Test-Path 'C:\\SALMI-PN_Dispensacion_BO\\$SELLO') { 'SI' } else { 'NO' }" 2>/dev/null | tr -d ' \r\n')
  rm -f "$MONTAJE/SALMI/$SELLO"
  case "$VISTO" in *SI*) printf "${VE}y Windows lo ve${V}\n" ;;
                   *)    printf "${AM}escribió, pero Windows no lo ve${V}\n" ;; esac
else
  printf "${RO}no se puede${V}\n"
fi

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   %s de 3 carpetas del Windows, abiertas desde Linux.\n\n" "$BIEN"
[ "$BIEN" = "3" ] && printf "   Desde el portátil, a 100 km:\n      ssh hornoma@100.81.234.58 'ls %s/SOAPS'\n\n" "$MONTAJE"
