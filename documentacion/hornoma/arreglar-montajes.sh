#!/bin/bash
# arreglar-montajes.sh — Que las carpetas del Windows se monten de verdad
#                        en Linux, y saber POR QUÉ no lo hacían.
#
# EL PORQUÉ
#
# El montaje falla con STATUS_LOGON_FAILURE — «esa contraseña no vale»—
# mientras que smbclient entra con EL MISMO archivo de credenciales. Los
# dos leen el mismo archivo y uno pasa y el otro no.
#
# La razón es que no lo leen igual:
#
#   smbclient    tolerante: «username = salmired» y «username=salmired»
#                le dan lo mismo
#   mount.cifs   estricto: todo lo que va después del «=» ES el valor,
#                espacios incluidos. Un espacio de más y manda una
#                contraseña que no es, sin decir nada más que
#                «permiso denegado»
#
# Y ese error no se distingue de una contraseña equivocada de verdad, así
# que se pierde el rato buscando donde no es.
#
# QUÉ HACE
#
#   1 · Mira el archivo de credenciales y dice qué le pasa, SIN enseñar
#       la contraseña: si tiene espacios, retornos de Windows o comillas.
#   2 · Escribe una copia limpia, en el formato estricto que quiere el
#       montaje, con permisos cerrados.
#   3 · Prueba a montar con ella. Si entra, arregla el /etc/fstab.
#   4 · COMPRUEBA que el tipo montado sea «cifs».
#
#       🔴 Esto último no es un detalle. Con «x-systemd.automount»,
#       systemd deja un portero (autofs) en la carpeta que SÍ aparece
#       montado aunque el montaje real haya fallado. Preguntar «¿está
#       montado?» da que sí. Hay que preguntar «¿de qué tipo?».
#       Me engañó dos veces seguidas el 12/08/2026.
#
# Uso:
#   sudo bash arreglar-montajes.sh
#   sudo bash arreglar-montajes.sh --solo-mirar
set -u

CRED=/etc/redhornoma/windows.credenciales
CRED_CIFS=/etc/redhornoma/windows-cifs.credenciales
MONTAJE=/mnt/windows
IP=192.168.122.226
MARCA="$(date '+%Y%m%d-%H%M')"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

SOLO_MIRAR=no
case "${1:-}" in --solo-mirar) SOLO_MIRAR=si ;; "") ;; *) echo "Uso: $0 [--solo-mirar]"; exit 1 ;; esac
[ "$(id -u)" = "0" ] || { echo "Hace falta sudo"; exit 1; }

titulo "ARREGLAR EL MONTAJE DE LAS CARPETAS DE WINDOWS"

# ── 1 · Qué le pasa al archivo de credenciales ────────────────────────
printf "\n   ${AZ}El archivo de credenciales, por dentro${V}\n"
[ -r "$CRED" ] || { mal "no encuentro $CRED"; exit 1; }

# Se mira línea a línea sin enseñar nunca el valor.
while IFS= read -r linea; do
  CAMPO="${linea%%=*}"; VALOR="${linea#*=}"
  case "$linea" in *=*) ;; *) continue ;; esac
  PROBLEMAS=""
  case "$CAMPO" in *[[:space:]]) PROBLEMAS="$PROBLEMAS espacio-antes-del-igual" ;; esac
  case "$VALOR" in [[:space:]]*) PROBLEMAS="$PROBLEMAS espacio-despues-del-igual" ;; esac
  case "$VALOR" in *[[:space:]]) PROBLEMAS="$PROBLEMAS espacio-al-final" ;; esac
  case "$linea" in *$'\r'*) PROBLEMAS="$PROBLEMAS retorno-de-Windows" ;; esac
  case "$VALOR" in \"*|\'*) PROBLEMAS="$PROBLEMAS entre-comillas" ;; esac
  NOMBRE=$(printf '%s' "$CAMPO" | tr -d '[:space:]')
  if [ -n "$PROBLEMAS" ]; then
    printf "      %-12s %s\n" "$NOMBRE" "${RO}←$PROBLEMAS${V}"
  else
    printf "      %-12s %s\n" "$NOMBRE" "${VE}limpio${V}"
  fi
done < "$CRED"

USU=$(grep -aoP '^\s*username\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
CLA=$(grep -aoP '^\s*password\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
DOM=$(grep -aoP '^\s*domain\s*=\s*\K.*'   "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
[ -n "$USU" ] && [ -n "$CLA" ] || { mal "no encuentro usuario y contraseña dentro"; exit 1; }

printf "\n      %-24s %s\n" "usuario"              "$USU"
printf "      %-24s %s\n"   "letras de la clave"   "${#CLA}"
printf "      %-24s %s\n"   "dominio"              "${DOM:-(ninguno)}"
nota "la contraseña no se enseña ni se registra en ningún sitio"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi

# ── 2 · Una copia limpia, en el formato estricto ──────────────────────
printf "\n   ${AZ}Escribiendo una copia limpia para el montaje${V}\n"
umask 077
{ printf 'username=%s\n' "$USU"
  printf 'password=%s\n' "$CLA"
  [ -n "$DOM" ] && printf 'domain=%s\n' "$DOM"
} > "$CRED_CIFS"
chmod 600 "$CRED_CIFS"
ok "$CRED_CIFS  (solo la puede leer root)"
nota "el archivo original no se toca: lo usa el respaldo y funciona bien"

# ── 3 · Probar a montar ───────────────────────────────────────────────
printf "\n   ${AZ}Probando a montar con ella${V}\n"
PRUEBA=/mnt/prueba-canal; mkdir -p "$PRUEBA"
GANADORA=""
probar(){
  printf "      %-32s " "$1"
  umount "$PRUEBA" 2>/dev/null
  SAL=$(mount -t cifs "//$IP/SALMI" "$PRUEBA" -o "$2" 2>&1)
  # El TIPO, no «¿está montado?». Ver la nota de arriba.
  if [ "$(findmnt -nro FSTYPE "$PRUEBA" 2>/dev/null)" = "cifs" ]; then
    printf "${VE}ENTRA${V}  (%s elementos)\n" "$(ls -1 "$PRUEBA" 2>/dev/null | wc -l)"
    [ -z "$GANADORA" ] && GANADORA="$2"
    umount "$PRUEBA" 2>/dev/null; return 0
  fi
  printf "${RO}no${V}  %s\n" "$(printf '%s' "$SAL" | head -1)"; return 1
}

probar "credenciales limpias"        "credentials=$CRED_CIFS,vers=3.0"
[ -z "$GANADORA" ] && probar "limpias, sin dominio"  "credentials=$CRED_CIFS,vers=3.0,domain="
[ -z "$GANADORA" ] && probar "limpias, con el equipo" "credentials=$CRED_CIFS,vers=3.0,domain=SERVER-HORNOMA"
[ -z "$GANADORA" ] && probar "limpias, sin versión"   "credentials=$CRED_CIFS"
umount "$PRUEBA" 2>/dev/null; rmdir "$PRUEBA" 2>/dev/null

if [ -z "$GANADORA" ]; then
  printf "\n   ${RO}Sigue sin entrar.${V} Entonces no era el archivo.\n"
  echo "      La cuenta «$USU» existe en Windows pero rechaza esa clave."
  echo "      Se arregla volviéndola a poner desde Linux:"
  echo "         sudo bash ~/programas-en-red.sh"
  echo
  exit 1
fi
ok "la forma que entra: $GANADORA"

# ── 4 · Dejarlo puesto en el fstab ────────────────────────────────────
printf "\n   ${AZ}Dejándolo puesto para siempre${V}\n"
cp -f /etc/fstab "/etc/fstab.antes-de-montajes-$MARCA" && ok "copia de /etc/fstab guardada"
sed -i '/# RedHornoma canal Windows/,+3d' /etc/fstab 2>/dev/null
sed -i '\|//'"$IP"'/\(SALMI\|SOAPS\|SNIS\)|d' /etc/fstab 2>/dev/null

UID_H=$(id -u hornoma); GID_H=$(id -g hornoma)
EXTRA="${GANADORA#credentials=$CRED_CIFS}"; EXTRA="${EXTRA#,}"
{
  printf '\n# RedHornoma canal Windows — las carpetas del Windows de este equipo.\n'
  printf '# Se montan solas la primera vez que alguien las abre, y no bloquean\n'
  printf '# el arranque si el Windows está apagado.\n'
  for c in SALMI SOAPS SNIS; do
    printf '//%s/%s  %s/%s  cifs  credentials=%s,%s,noauto,x-systemd.automount,x-systemd.idle-timeout=300,uid=%s,gid=%s,file_mode=0664,dir_mode=0775,nofail  0  0\n' \
      "$IP" "$c" "$MONTAJE" "$c" "$CRED_CIFS" "$EXTRA" "$UID_H" "$GID_H"
  done
} >> /etc/fstab

for c in SALMI SOAPS SNIS; do mkdir -p "$MONTAJE/$c"; done
systemctl daemon-reload
for c in SALMI SOAPS SNIS; do
  systemctl start "$(systemd-escape -p --suffix=automount "$MONTAJE/$c")" 2>/dev/null
done

# ── 5 · Comprobarlo de verdad ─────────────────────────────────────────
printf "\n   ${AZ}Cómo queda${V}\n"
BIEN=0
for c in SALMI SOAPS SNIS; do
  printf "      %-8s " "$c"
  ls "$MONTAJE/$c" >/dev/null 2>&1     # tocar, para que el portero abra
  if [ "$(findmnt -nro FSTYPE "$MONTAJE/$c" 2>/dev/null)" = "cifs" ]; then
    printf "${VE}montada${V}  (%s elementos)\n" "$(ls -1 "$MONTAJE/$c" 2>/dev/null | wc -l)"
    BIEN=$((BIEN+1))
  else
    printf "${RO}NO montada${V}  (tipo: %s)\n" "$(findmnt -nro FSTYPE "$MONTAJE/$c" 2>/dev/null || echo ninguno)"
  fi
done

# La prueba final: escribir desde Linux y que lo vea Windows.
printf "\n      %-32s " "escribir desde Linux"
SELLO=".canal-$MARCA"
if [ "$(findmnt -nro FSTYPE "$MONTAJE/SALMI" 2>/dev/null)" = "cifs" ] \
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
printf "   Desde el portátil, a 100 km:\n"
printf "      ssh hornoma@100.81.234.58 'ls %s/SALMI'\n\n" "$MONTAJE"
