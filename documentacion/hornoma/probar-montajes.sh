#!/bin/bash
# probar-montajes.sh — Por qué no se monta la carpeta del Windows, con las
#                      palabras exactas del sistema, y cuál es la manera
#                      que sí funciona.
#
# EL PORQUÉ
#
# Montar la carpeta de Windows desde Linux falla y el mensaje no se ve por
# ningún lado: el montaje lo hace systemd por su cuenta y su queja queda en
# el diario, que solo lee root.
#
# Y hay una trampa encima: con «x-systemd.automount» systemd pone un
# portero (autofs) en la carpeta. Ese portero SÍ aparece como montado
# aunque el montaje de verdad haya fallado. Comprobar con findmnt a secas
# da un verde falso; hay que mirar que el TIPO sea «cifs» y no «autofs».
#
# Este guion prueba las formas habituales una por una y dice cuál entra.
# No cambia nada: solo monta a mano, mira, y desmonta.
set -u

CRED=/etc/redhornoma/windows.credenciales
IP=192.168.122.226
PRUEBA=/mnt/prueba-canal

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

[ "$(id -u)" = "0" ] || { echo "Hace falta sudo: sin root no se lee el diario del sistema"; exit 1; }

titulo "POR QUÉ NO SE MONTA LA CARPETA DEL WINDOWS"

# ── Lo que dijo systemd cuando lo intentó ─────────────────────────────
printf "\n   ${AZ}Lo que dijo el sistema al intentarlo${V}\n"
journalctl -u mnt-windows-SALMI.mount --no-pager -n 15 2>/dev/null \
  | grep -v "^-- " | tail -10 | sed 's/^/      /'
DMESG=$(journalctl -k --since "-20 min" --no-pager 2>/dev/null | grep -i "cifs\|smb" | tail -8)
[ -n "$DMESG" ] && { echo "      — y el núcleo:"; printf '%s\n' "$DMESG" | sed 's/^/      /'; }

# ── Qué usuario lleva el archivo de credenciales ──────────────────────
USU=$(grep -oP '^\s*username\s*=\s*\K.*' "$CRED" 2>/dev/null | tr -d '\r')
DOM=$(grep -oP '^\s*domain\s*=\s*\K.*'   "$CRED" 2>/dev/null | tr -d '\r')
printf "\n   ${AZ}La cuenta que se está usando${V}\n"
printf "      %-12s %s\n" "usuario" "${USU:-(no hay)}"
printf "      %-12s %s\n" "dominio" "${DOM:-(no hay)}"
nota "la contraseña no se enseña"

# ── Probar formas, una por una ────────────────────────────────────────
printf "\n   ${AZ}Probando maneras de entrar${V}\n"
mkdir -p "$PRUEBA"
GANADORA=""

probar(){
  local nombre="$1"; shift
  local opciones="$1"
  printf "      %-34s " "$nombre"
  umount "$PRUEBA" 2>/dev/null
  SAL=$(mount -t cifs "//$IP/SALMI" "$PRUEBA" -o "$opciones" 2>&1)
  TIPO=$(findmnt -nro FSTYPE "$PRUEBA" 2>/dev/null)
  if [ "$TIPO" = "cifs" ]; then
    N=$(ls -1 "$PRUEBA" 2>/dev/null | wc -l)
    printf "${VE}ENTRA${V}  (%s elementos)\n" "$N"
    [ -z "$GANADORA" ] && GANADORA="$opciones"
    umount "$PRUEBA" 2>/dev/null
    return 0
  fi
  printf "${RO}no${V}  %s\n" "$(printf '%s' "$SAL" | head -1)"
  return 1
}

probar "como está ahora (vers=3.0)"    "credentials=$CRED,vers=3.0"
probar "sin decir la versión"          "credentials=$CRED"
probar "vers=2.1"                      "credentials=$CRED,vers=2.1"
probar "vers=3.0 + sec=ntlmssp"        "credentials=$CRED,vers=3.0,sec=ntlmssp"
probar "diciendo el nombre del equipo" "credentials=$CRED,vers=3.0,domain=SERVER-HORNOMA"
probar "sin dominio ninguno"           "credentials=$CRED,vers=3.0,domain="

umount "$PRUEBA" 2>/dev/null
rmdir "$PRUEBA" 2>/dev/null

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
if [ -n "$GANADORA" ]; then
  printf "   ${VE}La manera que funciona es:${V}\n\n"
  printf "      %s\n\n" "$GANADORA"
  printf "   Con eso arreglo el /etc/fstab y queda montado de verdad.\n\n"
else
  printf "   ${RO}Ninguna de las seis entró.${V}\n\n"
  printf "   Mira arriba lo que dijo el sistema en cada una: ahí está el\n"
  printf "   motivo, y no hace falta adivinarlo.\n\n"
fi
