#!/bin/bash
# reapuntar-respaldo.sh — Decirle al respaldo del .101 que el servidor
#                         ahora es ÉL MISMO, y no el .103.
#
# EL PORQUÉ
#
# El 3 de agosto se montó RedHornoma en el .101 para proteger al .103, que
# era donde vivían los programas del centro. La configuración quedó así:
#
#     windows_red=//192.168.1.103/SALMI
#
# El 4 de agosto euflo decidió que el servidor pasaba a ser el .101, y el
# 10 de agosto se instaló dentro SOAPS 7 con la historia del centro:
# 113.456 registros desde 2019. **La configuración nunca se cambió.**
#
# Desde entonces el respaldo va cada día a buscar SALMI a una computadora
# que ya no es el servidor, no lo encuentra, y lo anota:
#
#     2026-08-10 12:34  FALLÓ: no se llega a //192.168.1.103/SALMI
#     2026-08-11 13:32  FALLÓ: no se llega a //192.168.1.103/SALMI
#     2026-08-12 01:30  FALLÓ: no se llega a //192.168.1.103/SALMI
#
# Y hay un efecto peor, que es el que trae este guion: mientras
# «windows_red» tenga algo escrito, el respaldo cree que el Windows del
# centro es una máquina FÍSICA de la red. Un Windows físico no tiene agente
# invitado, así que «--preparar-programas» se niega a hacer nada y manda ir
# con el ratón. Por eso los 113.456 registros de SOAPS siguen SIN NINGUNA
# COPIA: la orden correcta se rechazaba por una línea de configuración.
#
# QUÉ CAMBIA
#
#   windows_red=          se aparta  → el respaldo pasa a modo «virtual» y
#                                      trabaja contra salud-servidor, el
#                                      Windows que vive DENTRO del .101
#   windows_extra=        se aparta  → apuntaba a la carpeta del .103
#   programas_carpeta=    se añade   → dónde deja el Windows sus copias de
#                                      SOAPS y SNIS. Es la carpeta
#                                      compartida, que YA ES un directorio
#                                      de este Linux: recogerlas no cuesta
#                                      ni una transferencia
#
# Nada se borra. La configuración anterior queda guardada con su fecha, y
# «--deshacer» la devuelve entera.
#
# Uso:
#   sudo bash reapuntar-respaldo.sh              mira y cambia
#   sudo bash reapuntar-respaldo.sh --solo-mirar solo enseña, no toca nada
#   sudo bash reapuntar-respaldo.sh --deshacer   vuelve a la de antes
set -u

CONF=/var/lib/redhornoma/respaldo.conf
CARPETA_PROGRAMAS=/var/lib/libvirt/compartido/RESPALDOS
MARCA="$(date '+%Y%m%d-%H%M')"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

SOLO_MIRAR=no; DESHACER=no
case "${1:-}" in
  --solo-mirar) SOLO_MIRAR=si ;;
  --deshacer)   DESHACER=si ;;
  "")           ;;
  *) echo "Uso: $0 [--solo-mirar | --deshacer]"; exit 1 ;;
esac

[ -f "$CONF" ] || { mal "no encuentro $CONF"; exit 1; }

# ── Deshacer ──────────────────────────────────────────────────────────
if [ "$DESHACER" = "si" ]; then
  titulo "DEVOLVER LA CONFIGURACIÓN ANTERIOR"
  ANTERIOR=$(ls -1t "$CONF".antes-de-reapuntar-* 2>/dev/null | head -1)
  [ -n "$ANTERIOR" ] || { mal "no hay ninguna copia guardada que devolver"; exit 1; }
  cp -f "$ANTERIOR" "$CONF" && ok "devuelta: $(basename "$ANTERIOR")"
  echo; grep -vE '^\s*(#|$)' "$CONF" | sed 's/^/      /'
  exit 0
fi

# ── Mirar cómo está ───────────────────────────────────────────────────
titulo "EL RESPALDO DEL .101 APUNTA AL SERVIDOR EQUIVOCADO"

printf "\n   ${AZ}Cómo está ahora${V}\n"
grep -vE '^\s*(#|$)' "$CONF" | sed 's/^/      /'

ACTUAL=$(grep -oP '^windows_red=\K.*' "$CONF" 2>/dev/null | head -1)
if [ -z "$ACTUAL" ]; then
  ok "ya está en modo virtual — no hay nada que reapuntar"
  exit 0
fi
avi "busca los programas en: $ACTUAL"
echo "      Esa es la .103. El servidor es esta misma máquina desde el 4 de agosto."

# ¿Existe de verdad el Windows de dentro? Preguntárselo, no suponerlo.
printf "\n   ${AZ}El Windows que vive dentro de este equipo${V}\n"
MAQ=$(LC_ALL=C virsh -c qemu:///system list --all --name 2>/dev/null | grep -v '^$' | head -1)
if [ -z "$MAQ" ]; then
  mal "no hay ninguna máquina virtual en este equipo"
  echo "      Sin ella, reapuntar no sirve de nada. No se toca nada."
  exit 1
fi
ESTADO=$(LC_ALL=C virsh -c qemu:///system domstate "$MAQ" 2>/dev/null)
ok "«$MAQ» — $ESTADO"

if LC_ALL=C virsh -c qemu:///system qemu-agent-command "$MAQ" \
     '{"execute":"guest-ping"}' 2>/dev/null | grep -q return; then
  ok "su agente invitado contesta — se puede preparar desde aquí"
else
  mal "su agente invitado NO contesta"
  echo "      Sin él, «--preparar-programas» tampoco podrá hacer nada."
  echo "      Enciende la máquina y vuelve a intentarlo. No se toca nada."
  exit 1
fi

# ── Lo que va a cambiar ───────────────────────────────────────────────
printf "\n   ${AZ}Lo que va a cambiar${V}\n"
printf "      %-24s %s\n" "windows_red"      "se aparta  (era $ACTUAL)"
printf "      %-24s %s\n" "windows_extra"    "se aparta  (era la carpeta del .103)"
printf "      %-24s %s\n" "programas_carpeta" "$CARPETA_PROGRAMAS"
printf "\n      %s\n" "Con eso el respaldo pasa a trabajar contra «$MAQ»."

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"
  exit 0
fi

[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo para cambiarlo"; exit 1; }

# ── Cambiarlo ─────────────────────────────────────────────────────────
printf "\n   ${AZ}Cambiándolo${V}\n"

GUARDADA="$CONF.antes-de-reapuntar-$MARCA"
cp -f "$CONF" "$GUARDADA" && ok "la de antes queda en $(basename "$GUARDADA")"

# Apartadas, no borradas: quien lea este archivo dentro de un año verá de
# dónde venía el centro y por qué cambió.
sed -i \
  -e "s|^windows_red=|# apartado el $(date '+%d/%m/%Y'): el servidor pasó a ser esta misma máquina — windows_red=|" \
  -e "s|^windows_extra=|# apartado el $(date '+%d/%m/%Y'): era la carpeta del .103 — windows_extra=|" \
  "$CONF"

grep -q '^programas_carpeta=' "$CONF" \
  || printf '\n# Dónde deja el Windows de dentro sus copias de SOAPS y SNIS.\nprogramas_carpeta=%s\n' \
       "$CARPETA_PROGRAMAS" >> "$CONF"

mkdir -p "$CARPETA_PROGRAMAS"
chgrp libvirt "$CARPETA_PROGRAMAS" 2>/dev/null
chmod 2775    "$CARPETA_PROGRAMAS" 2>/dev/null
ok "carpeta de copias lista: $CARPETA_PROGRAMAS"

# Comprobar que de verdad quedó en modo virtual, en vez de confiar.
if grep -qP '^windows_red=' "$CONF"; then
  mal "sigue habiendo un «windows_red» activo — algo no salió"
  exit 1
fi
ok "el respaldo queda en modo virtual"

printf "\n   ${AZ}Cómo queda${V}\n"
grep -vE '^\s*(#|$)' "$CONF" | sed 's/^/      /'

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   Ahora sí se puede poner en marcha la copia de SOAPS:\n\n"
printf "      sudo redhornoma-respaldo --preparar-programas\n\n"
printf "   Deja el guion dentro de Windows, programa la tarea de cada\n"
printf "   noche a las 2, y la ejecuta una vez para verla funcionar.\n"
printf "   Tarda hasta 10 minutos: está esperando a que el paquete se\n"
printf "   termine de escribir, y luego lo abre para comprobarlo.\n\n"
printf "   ${AM}Aviso honesto:${V} el respaldo diario seguirá fallando hasta\n"
printf "   que SALMI esté instalado dentro — pero ahora dirá la verdad\n"
printf "   («no encuentro SALMI en esa máquina») en vez de culpar al .103.\n"
printf "   Las copias de SOAPS y SNIS sí empiezan esta noche.\n\n"
