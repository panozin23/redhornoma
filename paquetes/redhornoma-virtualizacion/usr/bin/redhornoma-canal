#!/bin/bash
# canal-windows-linux.sh — El canal entre Windows y Linux, en los DOS
#                          sentidos, en CUALQUIER centro.
#
# Sustituye a canal-completo.sh, arreglar-montajes.sh y limpiar-montajes.sh,
# que se escribieron de madrugada con las direcciones de Hornoma metidas
# dentro. Aquí no hay ninguna dirección escrita: se preguntan todas.
#
# QUÉ DEJA HECHO
#
#   1 · Una unidad Z: en Windows con la carpeta que comparten los dos.
#       No se mapea desde fuera: el agente invitado corre como SYSTEM y una
#       unidad suya NO LA VE NINGÚN USUARIO. Va como tarea al iniciar sesión.
#
#   2 · Iconos en el escritorio de todos: la carpeta de intercambio y, si
#       existe, «Documentos del centro».
#
#   3 · Las carpetas de los programas del Windows, montadas en /mnt/windows.
#       Desde ahí —y por tanto desde el portátil, esté donde esté— se puede
#       copiar dentro de SALMI, SOAPS o SNIS sin abrir la pantalla de Windows.
#
#   4 · Se comprueba CRUZANDO: se escribe de un lado y se mira del otro.
#
# LAS SEIS TRAMPAS QUE COSTARON LA MADRUGADA DEL 12/08, Y CÓMO SE EVITAN
#
#   · El archivo de credenciales con espacios alrededor del «=». smbclient
#     los perdona y mount.cifs NO: manda una contraseña con un espacio
#     dentro y contesta «permiso denegado», que es indistinguible de una
#     clave equivocada. → se escribe una copia limpia aparte.
#   · «BUILTIN\Users» no existe en un Windows en español, donde se llama
#     «Usuarios». → va el número del grupo, S-1-5-32-545.
#   · Test-Path a una carpeta de red desde el agente invitado da «acceso
#     denegado» aunque funcione: SYSTEM se identifica como la máquina.
#     → lo que se puede saber desde Linux, se pregunta en Linux.
#   · «mount … || ls carpeta»: ls sobre una carpeta vacía SALE BIEN y tapa
#     el fallo. → se comprueba con findmnt.
#   · findmnt devuelve DOS líneas con automontaje —autofs y encima cifs—:
#     compararlo con la palabra «cifs» falla aunque esté montado.
#     → se busca la línea, no se compara el bloque.
#   · Borrar del fstab contando líneas («,+3d») deja entradas huérfanas que
#     se duplican al repetir, y systemd se queda con la PRIMERA.
#     → se borra por lo que la línea ES, y el bloque va entre marcas.
#
# Uso:
#   sudo bash canal-windows-linux.sh              lo deja funcionando
#   sudo bash canal-windows-linux.sh --solo-mirar enseña qué haría
#   sudo bash canal-windows-linux.sh --soltar     lo deshace
set -u

CRED=/etc/redhornoma/windows.credenciales
CRED_CIFS=/etc/redhornoma/windows-cifs.credenciales
MONTAJE=/mnt/windows
MARCA="$(date '+%Y%m%d-%H%M')"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }
VIRSH="virsh -c qemu:///system"

SOLO_MIRAR=no; SOLTAR=no
case "${1:-}" in
  --solo-mirar) SOLO_MIRAR=si ;; --soltar) SOLTAR=si ;; "") ;;
  *) echo "Uso: $0 [--solo-mirar | --soltar]"; exit 1 ;;
esac

titulo "EL CANAL ENTRE WINDOWS Y LINUX"

# ══ Preguntarlo todo, no dar nada por sabido ══════════════════════════
VM=$(LC_ALL=C $VIRSH list --name --state-running 2>/dev/null | grep -v '^$' | head -1)
[ -n "$VM" ] || { mal "no hay ningún Windows encendido en este equipo"; exit 1; }
ok "su Windows: «$VM»"

# La dirección de ESTE Linux vista desde su Windows es la puerta de la red
# interna de libvirt, no su dirección del centro. Confundirlas cuesta una tarde.
IP_PUERTA=$(ip -4 addr show virbr0 2>/dev/null | grep -oP 'inet \K[\d.]+')
[ -n "$IP_PUERTA" ] || { mal "no encuentro la red interna de la virtualización"; exit 1; }
IP_LAN=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
ok "este Linux: $IP_LAN en el centro · $IP_PUERTA para su Windows"

MAC_NAT=$(LC_ALL=C $VIRSH domiflist "$VM" 2>/dev/null | awk '$2=="network"{print $NF}' | head -1)
[ -n "$MAC_NAT" ] || { mal "su Windows no tiene tarjeta interna — sin ella no hay canal"; exit 1; }
IP_WIN=$(LC_ALL=C $VIRSH net-dhcp-leases default 2>/dev/null \
         | awk -v m="$MAC_NAT" '$0 ~ m {print $5}' | cut -d/ -f1 | head -1)
[ -n "$IP_WIN" ] || { mal "su Windows aún no ha pedido dirección interna"; exit 1; }
ok "su Windows por dentro: $IP_WIN"

# 🔴 Se busca el ARCHIVO, no se pregunta al camino de búsqueda.
# «command -v mount.cifs» contesta que no existe cuando lo ejecuta un
# usuario normal, porque /usr/sbin solo está en el camino de root. El
# 12/08 eso hizo decir «falta cifs-utils» justo después de que apt
# contestara que ya estaba instalado.
[ -x /usr/sbin/mount.cifs ] || [ -x /sbin/mount.cifs ] || command -v mount.cifs >/dev/null 2>&1 \
  || { mal "falta cifs-utils"; echo "      Se instala con:  sudo apt install -y cifs-utils"; exit 1; }

# ══ Soltar ════════════════════════════════════════════════════════════
if [ "$SOLTAR" = "si" ]; then
  [ "$(id -u)" = "0" ] || { mal "hace falta sudo"; exit 1; }
  for d in "$MONTAJE"/*; do
    [ -d "$d" ] || continue
    systemctl stop "$(systemd-escape -p --suffix=automount "$d")" 2>/dev/null
    systemctl stop "$(systemd-escape -p --suffix=mount "$d")" 2>/dev/null
    umount -l "$d" 2>/dev/null
  done
  cp -f /etc/fstab "/etc/fstab.antes-de-soltar-$MARCA"
  awk -v m="$MONTAJE/" '$2 ~ ("^" m) {next} /^# >>> RedHornoma canal/ {d=1; next}
                        /^# <<< RedHornoma canal/ {d=0; next} d {next} {print}' \
    /etc/fstab > /tmp/fstab.n && cp -f /tmp/fstab.n /etc/fstab && rm -f /tmp/fstab.n
  systemctl daemon-reload
  ok "montajes soltados y quitados del /etc/fstab"
  exit 0
fi

# ══ La cuenta para entrar a su Windows ════════════════════════════════
#
# 🔴 Aquí había un mensaje que mandaba a buscar donde no era. Decía
# «no puedo leer el archivo (¿con sudo?)» — y el 12/08 en Cochabamba el
# problema era que **el archivo no existía**: ese servidor nunca necesitó
# una cuenta de red, porque su respaldo trabaja contra su propio Windows
# por la carpeta compartida. El de Hornoma sí la tenía, porque copiaba del
# .103.
#
# Un mensaje de error tiene que decir lo que se MIDIÓ, no lo que se
# sospecha. Y si falta un dato que solo tiene la persona, se le PIDE —
# comprobándolo antes de guardarlo— en vez de rendirse.
printf "\n   ${AZ}La cuenta para entrar a su Windows${V}\n"

if [ -f "$CRED" ] && [ ! -r "$CRED" ]; then
  mal "el archivo $CRED existe pero no lo puedo leer"
  echo "      Es de root. Ejecuta esto mismo con  sudo."
  exit 1
fi

if [ ! -f "$CRED" ]; then
  avi "este equipo no tiene guardada ninguna cuenta para su Windows"
  echo "      No es una avería: solo la necesita quien vaya a montar las"
  echo "      carpetas del Windows desde Linux, y aquí nunca se hizo."
  if [ "$SOLO_MIRAR" = "si" ]; then
    nota "al ejecutarlo de verdad te pediré el usuario y la contraseña"
  else
    [ -t 0 ] || { mal "hace falta escribirla, y esto no se está ejecutando en una terminal"
                  echo "      Ejecútalo con  ssh -t  ..."; exit 1; }
    echo
    printf "   Usuario de Windows [salmired]: "
    read -r U_NUEVO; U_NUEVO="${U_NUEVO:-salmired}"
    printf "   Su contraseña: "
    read -rs C_NUEVO; echo
    [ -n "$C_NUEVO" ] || { mal "sin contraseña no se puede entrar"; exit 1; }

    # Comprobarla ENTRANDO, antes de guardar nada. Si está mal, se dice
    # ahora y no dentro de tres pasos con un «permiso denegado» que no
    # explica de dónde viene.
    TMPC=$(mktemp); chmod 600 "$TMPC"
    printf 'username=%s\npassword=%s\n' "$U_NUEVO" "$C_NUEVO" > "$TMPC"
    printf "   %-30s " "probándola contra su Windows"
    if smbclient -L "//$IP_WIN" -A "$TMPC" -t 15 >/dev/null 2>&1; then
      printf "${VE}entra${V}\n"
      [ "$(id -u)" = "0" ] || { rm -f "$TMPC"; mal "hace falta sudo para guardarla"; exit 1; }
      mkdir -p /etc/redhornoma
      cp -f "$TMPC" "$CRED"; chmod 600 "$CRED"; chown root:root "$CRED"
      rm -f "$TMPC"
      ok "guardada en $CRED (solo la puede leer root)"
    else
      printf "${RO}no entra${V}\n"
      rm -f "$TMPC"
      mal "esa cuenta o esa contraseña no valen para $IP_WIN"
      echo "      No se ha guardado nada. Compruébala y vuelve a intentarlo."
      exit 1
    fi
  fi
else
  ok "usa la cuenta ya guardada en $CRED"
fi

# ══ Qué comparte su Windows ═══════════════════════════════════════════
# Se le pregunta a él, no se adivina: cada centro instala donde le toca.
printf "\n   ${AZ}Qué carpetas publica su Windows${V}\n"
RECURSOS=""
if [ -r "$CRED" ]; then
  RECURSOS=$(smbclient -L "//$IP_WIN" -A "$CRED" -t 15 2>/dev/null \
             | awk '/Disk/ && $1 !~ /\$$/ {print $1}' | grep -E '^(SALMI|SOAPS|SNIS)$' | sort -u)
fi
if [ -z "$RECURSOS" ]; then
  avi "no se ve ninguna carpeta de los programas todavía"
  nota "se montarán cuando existan: sudo bash programas-en-red.sh"
else
  for r in $RECURSOS; do printf "      %s\n" "$r"; done
fi

printf "\n   ${AZ}Lo que va a quedar${V}\n"
RUTA_Z='\\'"$IP_PUERTA"'\compartido'
printf "      %-28s %s\n" "Z: en Windows"  "$RUTA_Z, al iniciar sesión"
printf "      %-28s %s\n" "iconos"         "intercambio y, si existe, Documentos del centro"
for r in $RECURSOS; do printf "      %-28s %s\n" "$MONTAJE/$r" "desde Linux"; done

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi
[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo"; exit 1; }

# ══ Que la dirección interna no cambie nunca ══════════════════════════
printf "\n   ${AZ}Fijando la dirección interna de su Windows${V}\n"
if LC_ALL=C $VIRSH net-dumpxml default 2>/dev/null | grep -q "$MAC_NAT"; then
  ok "ya estaba reservada"
elif $VIRSH net-update default add-last ip-dhcp-host \
       "<host mac='$MAC_NAT' ip='$IP_WIN'/>" --live --config >/dev/null 2>&1; then
  ok "$IP_WIN reservada — ya no puede cambiar"
else
  avi "no se pudo reservar; podría cambiar y dejar los montajes apuntando a nadie"
fi

# ══ Credenciales limpias para el montaje ══════════════════════════════
USU=$(grep -aoP '^\s*username\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
CLA=$(grep -aoP '^\s*password\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
DOM=$(grep -aoP '^\s*domain\s*=\s*\K.*'   "$CRED" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
[ -n "$USU" ] && [ -n "$CLA" ] || { mal "no encuentro usuario y contraseña en $CRED"; exit 1; }
# 🔴 El umask se pone SOLO para escribir la contraseña, y se devuelve.
# El 12/08 se quedó puesto y las carpetas de /mnt/windows nacieron a 700:
# el panel, que corre como la persona y no como root, no podía ni mirarlas
# y decía que no había ninguna. Un permiso de más también es un fallo.
UMASK_ANTES=$(umask)
umask 077
{ printf 'username=%s\n' "$USU"; printf 'password=%s\n' "$CLA"
  [ -n "$DOM" ] && printf 'domain=%s\n' "$DOM"; } > "$CRED_CIFS"
chmod 600 "$CRED_CIFS"
umask "$UMASK_ANTES"
printf "\n   ${AZ}Credenciales${V}\n"
ok "copia limpia para el montaje ($USU) — el original no se toca"

# ══ Lado Windows ══════════════════════════════════════════════════════
printf "\n   ${AZ}Dentro de Windows${V}\n"
HAY_DOC=no; testparm -s 2>/dev/null | grep -q '^\[documentos\]' && HAY_DOC=si
GUION=$(mktemp /tmp/rh-canal-XXXXXX.ps1); chmod 600 "$GUION"
trap 'rm -f "$GUION"' EXIT
{ printf '$puerta = %s\n' "'$IP_PUERTA'"
  printf '$lan = %s\n'    "'$IP_LAN'"
  printf '$hayDoc = %s\n' "'$HAY_DOC'"; } > "$GUION"
cat >> "$GUION" <<'PS'
$ErrorActionPreference = 'Continue'
$tarea = 'RedHornoma - Carpeta de intercambio'
$ruta  = '\\' + $puerta + '\compartido'

# El grupo va por su NUMERO: en un Windows en español «BUILTIN\Users» se
# llama «Usuarios» y Register-ScheduledTask lo rechaza sin explicar nada.
$accion  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c net use Z: ' + $ruta + ' /persistent:no')
$cuando  = New-ScheduledTaskTrigger -AtLogOn
$quien   = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Unregister-ScheduledTask -TaskName $tarea -Confirm:$false -EA SilentlyContinue
Register-ScheduledTask -TaskName $tarea -Action $accion -Trigger $cuando -Principal $quien `
  -Settings $ajustes -Description 'Pone la Z: con la carpeta que comparten Windows y Linux' -EA SilentlyContinue | Out-Null
if (Get-ScheduledTask -TaskName $tarea -EA SilentlyContinue) { "OK  la Z: se pondra al iniciar sesion" }
else { "MAL no se pudo crear la tarea de la Z:" }

$esc = Join-Path $env:PUBLIC 'Desktop'
$w = New-Object -ComObject WScript.Shell
try { $s = $w.CreateShortcut((Join-Path $esc 'Carpeta de intercambio.lnk'))
      $s.TargetPath = $ruta
      $s.Description = 'Lo que se deja aqui lo ve el Linux del servidor, y al reves'
      $s.Save(); "OK  icono: Carpeta de intercambio" } catch { "MAL icono de intercambio" }

# Si «Documentos del centro» existe lo dice LINUX. Preguntarlo aqui con
# Test-Path no sirve: el agente es SYSTEM y da «acceso denegado» aunque
# cualquier persona entre sin problema.
if ($hayDoc -eq 'si') {
  try { $s = $w.CreateShortcut((Join-Path $esc 'Documentos del centro.lnk'))
        $s.TargetPath = '\\' + $lan + '\documentos'
        $s.Save(); "OK  icono: Documentos del centro" } catch { "AVISO icono de Documentos" }
} else { "AVISO Documentos del centro no existe - crealo con: sudo redhornoma-carpeta-compartida --documentos" }
PS
redhornoma-en-windows --maquina "$VM" --guion "$GUION" 2>&1 | sed 's/^/      /'
rm -f "$GUION"

# ══ Lado Linux: las carpetas del Windows ══════════════════════════════
if [ -n "$RECURSOS" ]; then
  printf "\n   ${AZ}Las carpetas del Windows, montadas aquí${V}\n"
  cp -f /etc/fstab "/etc/fstab.antes-del-canal-$MARCA" && ok "copia de /etc/fstab guardada"

  # Se borra por lo que la línea ES, no contando líneas.
  awk -v m="$MONTAJE/" '$2 ~ ("^" m) {next} /^# >>> RedHornoma canal/ {d=1; next}
                        /^# <<< RedHornoma canal/ {d=0; next} d {next}
                        /^# RedHornoma canal Windows/ {v=1; next} v && /^#/ {next} {v=0; print}' \
    /etc/fstab > /tmp/fstab.n
  QUEDAN=$(awk -v m="$MONTAJE/" '$2 ~ ("^" m)' /tmp/fstab.n | grep -c . || true)
  [ "$QUEDAN" = "0" ] || { mal "quedan $QUEDAN líneas viejas: no toco nada"; rm -f /tmp/fstab.n; exit 1; }

  U=$(id -u "${SUDO_USER:-$(getent passwd 1000 | cut -d: -f1)}" 2>/dev/null || echo 1000)
  G=$(id -g "${SUDO_USER:-$(getent passwd 1000 | cut -d: -f1)}" 2>/dev/null || echo 1000)
  { printf '\n# >>> RedHornoma canal Windows — NO editar entre las marcas.\n'
    for r in $RECURSOS; do
      printf '//%s/%s  %s/%s  cifs  credentials=%s,vers=3.0,noauto,x-systemd.automount,x-systemd.idle-timeout=300,uid=%s,gid=%s,file_mode=0664,dir_mode=0775,nofail  0  0\n' \
        "$IP_WIN" "$r" "$MONTAJE" "$r" "$CRED_CIFS" "$U" "$G"
    done
    printf '# <<< RedHornoma canal Windows\n'; } >> /tmp/fstab.n
  cp -f /tmp/fstab.n /etc/fstab; rm -f /tmp/fstab.n
  ok "una sola línea por carpeta"

  # Las carpetas de montaje TIENEN que poder mirarlas las personas:
  # el panel corre como la persona, no como root.
  mkdir -p "$MONTAJE"; chmod 755 "$MONTAJE"
  for r in $RECURSOS; do mkdir -p "$MONTAJE/$r"; chmod 755 "$MONTAJE/$r"; done
  systemctl daemon-reload
  for r in $RECURSOS; do
    systemctl start "$(systemd-escape -p --suffix=automount "$MONTAJE/$r")" 2>/dev/null
  done

  BIEN=0; TOTAL=0
  for r in $RECURSOS; do
    TOTAL=$((TOTAL+1)); printf "      %-8s " "$r"
    ls "$MONTAJE/$r" >/dev/null 2>&1; sleep 1
    # La línea, no el bloque: con automontaje findmnt devuelve autofs Y cifs.
    if findmnt -nro FSTYPE "$MONTAJE/$r" 2>/dev/null | grep -qx cifs; then
      printf "${VE}montada${V}  (%s elementos)\n" "$(ls -1 "$MONTAJE/$r" 2>/dev/null | wc -l)"
      BIEN=$((BIEN+1))
    else
      printf "${RO}NO${V}\n"
      systemctl status "$(systemd-escape -p --suffix=mount "$MONTAJE/$r")" --no-pager 2>&1 \
        | grep -iE "denied|error|failed" | head -2 | sed 's/^/         /'
    fi
  done
fi

# ══ Cruzar el canal, que es la única prueba que vale ══════════════════
printf "\n   ${AZ}Cruzando el canal${V}\n"
COMP=/var/lib/libvirt/compartido; mkdir -p "$COMP"
SELLO="prueba-canal-$MARCA.txt"

printf "      %-30s " "Linux → Windows"
echo "escrito a las $(date '+%H:%M:%S')" > "$COMP/$SELLO"
R=$(redhornoma-en-windows --maquina "$VM" --powershell \
     "if (Test-Path 'C:\\') { if (Test-Path '\\\\$IP_PUERTA\\compartido\\$SELLO') {'SI'} else {'NO'} }" 2>/dev/null | tr -d ' \r\n')
case "$R" in *SI*) printf "${VE}lo ve Windows${V}\n" ;; *) printf "${AM}Windows no lo ve${V}\n" ;; esac

printf "      %-30s " "Windows → Linux"
redhornoma-en-windows --maquina "$VM" --powershell \
  "Set-Content -Path '\\\\$IP_PUERTA\\compartido\\vuelta-$SELLO' -Value 'desde Windows'" >/dev/null 2>&1
sleep 2
[ -f "$COMP/vuelta-$SELLO" ] && printf "${VE}lo ve Linux${V}\n" || printf "${AM}Linux no lo ve${V}\n"
rm -f "$COMP/$SELLO" "$COMP/vuelta-$SELLO"

if [ -n "${RECURSOS:-}" ] && [ "${BIEN:-0}" -gt 0 ]; then
  PRIMERA=$(echo "$RECURSOS" | head -1)
  printf "      %-30s " "escribir dentro de $PRIMERA"
  if touch "$MONTAJE/$PRIMERA/.$SELLO" 2>/dev/null; then
    rm -f "$MONTAJE/$PRIMERA/.$SELLO"; printf "${VE}sí${V}\n"
  else printf "${AM}solo lectura${V}\n"; fi
fi

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   %s de %s carpetas del Windows, abiertas desde Linux.\n" "${BIEN:-0}" "${TOTAL:-0}"
printf "   La Z: aparece al INICIAR SESIÓN: si hay alguien dentro de\n"
printf "   Windows, tiene que cerrar sesión y volver a entrar.\n\n"
printf "   Para deshacerlo:  sudo bash %s --soltar\n\n" "$(basename "$0")"
