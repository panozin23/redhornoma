#!/bin/bash
# habilitar-discos.sh — Que el Windows del .101 vea los discos externos.
#
# TEMPORAL, y se quita con:  sudo bash habilitar-discos.sh --quitar
#
# Por qué NO se le pasa el disco físico a Windows, que sería lo obvio:
#
#   · Linux lo perdería, y con él el respaldo del centro, que vive aquí.
#   · Si los dos sistemas tocan el mismo NTFS a la vez, se corrompe. No hay
#     aviso: se ve bien hasta el día que no se abre.
#
# Así que se comparten por red. Para Windows es lo mismo —se le pone una letra
# de unidad y se ve como un disco más— pero el disco sigue siendo de Linux.
#
# El SAMSUNG se monta de SOLO LECTURA, a propósito: tiene 6 sectores que no
# lee bien y hace clic. De ese disco se saca, no se mete.
set -u

[ "$(id -u)" = "0" ] || { echo "Hace falta administrador:  sudo bash $0"; exit 1; }

MARCA_INI="# ── RedHornoma · discos externos (temporal) ──"
MARCA_FIN="# ── fin discos externos ──"
CONF=/etc/samba/smb.conf
USUARIO=hornoma

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'

# Los mensajes van a la SALIDA DE ERRORES, no a la normal.
#
# Y no es un capricho: la función que monta devuelve su resultado por la
# salida normal, y quien la llama lo recoge con «$( )». La primera versión
# escribía los avisos ahí también, así que al recogerlos se los tragaba: el
# guion decía «Montando» y debajo no salía NADA, ni siquiera el error de que
# no encontraba los discos. Costó una ejecución entera a ciegas: 10/08/2026.
ok(){  printf "   ${VE}✅${V} %s\n" "$1" >&2; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1" >&2; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1" >&2; }
nota(){ printf "   ${GR}%s${V}\n" "$1" >&2; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n${AZ} %s${V}\n${AZ}══════════════════════════════════════════════════════${V}\n" "$1"; }

# ── Quitarlo ──────────────────────────────────────────────────────────
if [ "${1:-}" = "--quitar" ]; then
  titulo "QUITANDO LOS DISCOS COMPARTIDOS"
  if grep -q "RedHornoma · discos externos" "$CONF" 2>/dev/null; then
    sed -i '/RedHornoma · discos externos/,/fin discos externos/d' "$CONF"
    systemctl restart smbd 2>/dev/null
    ok "ya no se comparten"
  else
    nota "no había nada que quitar"
  fi
  for m in "/media/$USUARIO/SANSUNG1" "/media/$USUARIO/SANSUNG2"; do
    umount "$m" 2>/dev/null && ok "desmontado $m"
  done
  echo
  exit 0
fi

titulo "DISCOS EXTERNOS PARA EL WINDOWS DEL SERVIDOR"

UID_H=$(id -u "$USUARIO" 2>/dev/null) || { mal "no existe el usuario $USUARIO"; exit 1; }
GID_H=$(id -g "$USUARIO")

# ── Buscar un disco por su ETIQUETA ───────────────────────────────────
# Por etiqueta y no por letra: las letras cambian según el orden en que se
# enchufan los discos, la etiqueta no.
#
# Con lsblk y NO con «blkid -L»: blkid necesita permisos para leer su caché y
# devuelve vacío en silencio cuando no los tiene.
buscar(){  # etiqueta → /dev/sdXN
  lsblk -nrpo NAME,LABEL 2>/dev/null | awk -v e="$1" '$2 == e { print $1; exit }'
}

montar(){  # etiqueta  modo(ro|rw) → imprime el punto de montaje
  local etq="$1" modo="$2" dev punto
  dev=$(buscar "$etq")
  if [ -z "$dev" ]; then
    avi "no hay ningún disco con la etiqueta «$etq» — ¿está enchufado?"
    return 1
  fi

  punto=$(findmnt -nro TARGET "$dev" 2>/dev/null | head -1)
  if [ -n "$punto" ]; then
    nota "«$etq» ($dev) ya estaba montado en $punto"
    printf '%s\n' "$punto"
    return 0
  fi

  punto="/media/$USUARIO/$etq"
  mkdir -p "$punto"
  if mount -t ntfs3 -o "$modo,uid=$UID_H,gid=$GID_H,umask=0022" "$dev" "$punto" 2>/dev/null; then
    ok "«$etq» ($dev) montado en $punto — $([ "$modo" = ro ] && echo 'SOLO LECTURA' || echo 'lectura y escritura')"
    printf '%s\n' "$punto"
    return 0
  fi

  # Si el primer intento falla, se enseña POR QUÉ. Un montaje que no dice su
  # motivo obliga a probar a ciegas.
  mal "no pude montar «$etq» ($dev):"
  mount -t ntfs3 -o "$modo,uid=$UID_H,gid=$GID_H,umask=0022" "$dev" "$punto" 2>&1 | head -2 | sed 's/^/      /' >&2
  rmdir "$punto" 2>/dev/null
  return 1
}

printf "\n   ${AZ}Montando${V}\n"
P_TOSHIBA=$(montar CURSAKIALINUX rw) || P_TOSHIBA=""
P_SANS1=$(montar SANSUNG1 ro)        || P_SANS1=""
P_SANS2=$(montar SANSUNG2 ro)        || P_SANS2=""

if [ -z "$P_TOSHIBA$P_SANS1$P_SANS2" ]; then
  mal "no se montó ningún disco: no hay nada que compartir"
  echo
  exit 1
fi

# ── Compartirlos, solo hacia la máquina virtual ───────────────────────
# «hosts allow» limitado a 192.168.122. — la red interna entre este Linux y
# su Windows. Nadie del centro ni de fuera llega a estos discos.
printf "\n   ${AZ}Compartiendo${V}\n"
sed -i '/RedHornoma · discos externos/,/fin discos externos/d' "$CONF" 2>/dev/null

compartir(){  # nombre  ruta  soloLectura(yes|no)
  [ -n "$2" ] && [ -d "$2" ] || { nota "«$1» no se comparte: no está montado"; return 0; }
  {
    printf '\n[%s]\n' "$1"
    printf '   comment = Disco externo %s\n' "$1"
    printf '   path = %s\n' "$2"
    printf '   browseable = yes\n'
    printf '   read only = %s\n' "$3"
    printf '   guest ok = yes\n'
    printf '   force user = %s\n' "$USUARIO"
    printf '   hosts allow = 192.168.122. 127.\n'
    printf '   hosts deny = 0.0.0.0/0\n'
  } >> "$CONF"
  ok "$1 → $2"
}

echo "$MARCA_INI" >> "$CONF"
compartir TOSHIBA  "$P_TOSHIBA" no
compartir SANSUNG1 "$P_SANS1"   yes
compartir SANSUNG2 "$P_SANS2"   yes
printf '\n%s\n' "$MARCA_FIN" >> "$CONF"

# ── Comprobar de verdad ───────────────────────────────────────────────
# No basta con escribir la configuración: si tiene un error, smbd arranca
# igual y las carpetas no aparecen.
printf "\n   %-32s " "revisando la configuración"
if testparm -s "$CONF" >/dev/null 2>&1; then
  printf "${VE}correcta${V}\n"
else
  printf "${RO}TIENE ERRORES${V}\n"
  testparm -s "$CONF" 2>&1 | grep -i error | head -3 | sed 's/^/      /'
  mal "no se recarga samba: quedaría peor que antes"
  exit 1
fi

systemctl restart smbd 2>/dev/null
sleep 2
printf "   %-32s " "samba en marcha"
systemctl is-active smbd >/dev/null 2>&1 && printf "${VE}sí${V}\n" || { printf "${RO}no${V}\n"; exit 1; }

printf "   %-32s " "carpetas que se ven"
VISTAS=$(smbclient -N -L 127.0.0.1 2>/dev/null | awk '/Disk/{print $1}' | grep -E 'TOSHIBA|SANSUNG|compartido' | tr '\n' ' ')
if [ -n "$VISTAS" ]; then printf "${VE}%s${V}\n" "$VISTAS"; else printf "${RO}ninguna${V}\n"; fi

titulo "CÓMO SE ABREN DESDE WINDOWS"
cat <<FIN

   En el explorador de Windows, escribe arriba:

      \\\\192.168.122.1\\TOSHIBA        el disco de 1 TB, se puede escribir
      \\\\192.168.122.1\\SANSUNG1       solo lectura
      \\\\192.168.122.1\\SANSUNG2       solo lectura
      \\\\192.168.122.1\\compartido     donde dejé los instaladores

   Para que quede como una unidad con letra:
      clic derecho en «Este equipo» → «Conectar a unidad de red»
      y pega una de esas rutas.

   El SAMSUNG va de solo lectura a propósito: tiene 6 sectores dañados.
   De ese disco se saca, no se mete.

   Para quitar todo esto cuando ya no haga falta:
      sudo bash $0 --quitar

FIN
