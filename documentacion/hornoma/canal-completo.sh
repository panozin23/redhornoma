#!/bin/bash
# canal-completo.sh — El canal entre Windows y Linux, en los DOS sentidos
#                     y sin que nadie tenga que escribir una ruta.
#
# EL PORQUÉ
#
# El canal ya existía, pero era de un solo sentido y sin puerta:
#
#   · Windows podía llegar a las carpetas del Linux SI alguien escribía
#     \\192.168.122.1\compartido a mano. Con barras invertidas, que en un
#     teclado español piden Alt+92. En la práctica, eso es no poder.
#   · Linux no podía entrar en el disco de Windows. Solo mandarle órdenes
#     sueltas por el agente invitado: ver un archivo sí, copiar no.
#
# LO QUE DEJA HECHO
#
#   1 · La dirección interna del Windows, FIJA. Hoy se la da el sorteo
#       (DHCP) y caduca cada hora. Si cambia, los montajes de abajo
#       apuntarían a nadie. Se reserva por su dirección física.
#
#   2 · UNA UNIDAD Z: en Windows, puesta al iniciar sesión. No se puede
#       mapear desde el agente invitado: ese corre como SYSTEM y una unidad
#       suya NO LA VE NINGÚN USUARIO —está apuntado en el traspaso como
#       error ya cometido—. Va como tarea que se ejecuta al entrar la
#       persona, con su propia cuenta.
#
#   3 · LAS CARPETAS DEL WINDOWS, montadas en Linux bajo /mnt/windows.
#       Desde aquí —y por tanto desde el portátil, a 100 km— se puede
#       copiar dentro de SALMI, SOAPS o SNIS sin abrir la pantalla de
#       Windows. Ese es el camino que faltaba.
#
#   4 · SE COMPRUEBA EN LOS DOS SENTIDOS: se deja un archivo desde Linux y
#       se lee desde Windows, y al revés. Un canal que no se ha cruzado en
#       ambas direcciones no está probado.
#
# Uso:
#   sudo bash canal-completo.sh               lo deja funcionando
#   sudo bash canal-completo.sh --solo-mirar  enseña qué haría
#   sudo bash canal-completo.sh --soltar      desmonta y quita el fstab
set -u

VM=salud-servidor
CRED=/etc/redhornoma/windows.credenciales
COMPARTIDA=/var/lib/libvirt/compartido
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

SOLO_MIRAR=no; SOLTAR=no
case "${1:-}" in
  --solo-mirar) SOLO_MIRAR=si ;;
  --soltar)     SOLTAR=si ;;
  "") ;;
  *) echo "Uso: $0 [--solo-mirar | --soltar]"; exit 1 ;;
esac

titulo "EL CANAL ENTRE WINDOWS Y LINUX, EN LOS DOS SENTIDOS"

# ── Soltar ────────────────────────────────────────────────────────────
if [ "$SOLTAR" = "si" ]; then
  [ "$(id -u)" = "0" ] || { mal "hace falta sudo"; exit 1; }
  for c in SALMI SOAPS SNIS; do
    umount "$MONTAJE/$c" 2>/dev/null && ok "$c desmontada"
  done
  sed -i '/# RedHornoma canal Windows/,+3d' /etc/fstab 2>/dev/null
  systemctl daemon-reload
  ok "quitado de /etc/fstab"
  exit 0
fi

# ── La máquina ────────────────────────────────────────────────────────
ESTADO=$(LC_ALL=C virsh -c qemu:///system domstate "$VM" 2>/dev/null | tr -d '\n')
[ "$ESTADO" = "running" ] || { mal "el Windows «$VM» no está encendido"; exit 1; }
ok "«$VM» encendido"

MAC_NAT=$(LC_ALL=C virsh -c qemu:///system domiflist "$VM" 2>/dev/null | awk '$2=="network"{print $NF}' | head -1)
IP_NAT=$(LC_ALL=C virsh -c qemu:///system net-dhcp-leases default 2>/dev/null \
         | awk -v m="$MAC_NAT" '$0 ~ m {print $5}' | cut -d/ -f1 | head -1)
[ -n "$IP_NAT" ] || { mal "no consigo saber la dirección interna del Windows"; exit 1; }
ok "su dirección interna: $IP_NAT  (tarjeta $MAC_NAT)"

command -v mount.cifs >/dev/null 2>&1 || { mal "falta cifs-utils"
  echo "      Instálalo con:  sudo apt install -y cifs-utils"; exit 1; }
ok "el sistema sabe montar carpetas de Windows"

[ -r "$CRED" ] || { mal "no puedo leer $CRED (¿con sudo?)"; exit 1; }

printf "\n   ${AZ}Lo que va a quedar${V}\n"
printf "      %-26s %s\n" "$IP_NAT" "reservada para siempre a esa tarjeta"
printf "      %-26s %s\n" "Z: en Windows" "\\\\\\\\192.168.122.1\\\\compartido, al iniciar sesión"
printf "      %-26s %s\n" "$MONTAJE/SALMI" "la carpeta de SALMI, desde Linux"
printf "      %-26s %s\n" "$MONTAJE/SOAPS" "la de SOAPS"
printf "      %-26s %s\n" "$MONTAJE/SNIS"  "la de SNIS"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi
[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo"; exit 1; }

# ── 1 · Que la dirección interna no cambie nunca ──────────────────────
# Sin esto, el sorteo puede darle otra mañana y los montajes de abajo
# apuntarían a una máquina que no existe. Y el error diría «no se llega»,
# igual que el que nos tuvo nueve días sin respaldo apuntando al .103.
printf "\n   ${AZ}Fijando su dirección interna${V}\n"
if LC_ALL=C virsh -c qemu:///system net-dumpxml default 2>/dev/null | grep -q "$MAC_NAT"; then
  ok "ya estaba reservada"
else
  if virsh -c qemu:///system net-update default add-last ip-dhcp-host \
       "<host mac='$MAC_NAT' name='SERVER-HORNOMA' ip='$IP_NAT'/>" --live --config >/dev/null 2>&1; then
    ok "$IP_NAT reservada para $MAC_NAT — ya no puede cambiar"
  else
    avi "no se pudo reservar; seguimos, pero la dirección podría cambiar"
  fi
fi

# ── 2 · La unidad Z: dentro de Windows ────────────────────────────────
printf "\n   ${AZ}La unidad Z: dentro de Windows${V}\n"
GUION=$(mktemp /tmp/rh-canal-XXXXXX.ps1); chmod 600 "$GUION"
trap 'rm -f "$GUION"' EXIT
# Lo pregunta LINUX, que sí puede saberlo, y se lo dice a Windows.
HAY_DOC=no
testparm -s 2>/dev/null | grep -q '^\[documentos\]' && HAY_DOC=si
printf '$hayDocumentos = %s\n' "'$HAY_DOC'" > "$GUION"
cat >> "$GUION" <<'PS'
$ErrorActionPreference = 'Continue'
$tarea = 'RedHornoma - Carpeta de intercambio'

# La unidad NO se mapea desde aqui: este guion lo lanza el agente invitado,
# que es SYSTEM, y una unidad de SYSTEM no la ve ningun usuario. Se deja
# programada para que la ponga CADA PERSONA al iniciar sesion.
$accion  = New-ScheduledTaskAction -Execute 'cmd.exe' `
             -Argument '/c net use Z: \\192.168.122.1\compartido /persistent:no'
$cuando  = New-ScheduledTaskTrigger -AtLogOn
# 🔴 Va el NÚMERO del grupo, no su nombre. Este Windows está en español y
# ahí «BUILTIN\Users» se llama «Usuarios»: Register-ScheduledTask lo
# rechaza sin explicar por qué. El S-1-5-32-545 es el mismo grupo en
# cualquier idioma. Es el mismo fallo que virsh contestando «ejecutando».
$quien   = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Unregister-ScheduledTask -TaskName $tarea -Confirm:$false -EA SilentlyContinue
Register-ScheduledTask -TaskName $tarea -Action $accion -Trigger $cuando `
  -Principal $quien -Settings $ajustes `
  -Description 'Pone la Z: con la carpeta que comparten Windows y Linux' -EA SilentlyContinue | Out-Null

if (Get-ScheduledTask -TaskName $tarea -EA SilentlyContinue) { "OK  tarea creada: se pondra la Z: al iniciar sesion" }
else { "MAL no se pudo crear la tarea de la Z:" }

# Un icono en el escritorio de TODOS, que funciona aunque la Z: no este.
$esc = Join-Path $env:PUBLIC 'Desktop'
$w = New-Object -ComObject WScript.Shell
try {
  $s = $w.CreateShortcut((Join-Path $esc 'Carpeta de intercambio.lnk'))
  $s.TargetPath = '\\192.168.122.1\compartido'
  $s.Description = 'Lo que se deja aqui lo ve el Linux del servidor, y al reves'
  $s.Save(); "OK  icono puesto: Carpeta de intercambio"
} catch { "MAL no se pudo poner el icono: $($_.Exception.Message)" }

# «Documentos del centro»: el icono se pone si el LINUX dice que existe.
#
# 🔴 NO se comprueba con Test-Path desde aqui. Este guion lo lanza el
# agente invitado, que es SYSTEM y se identifica ante la red como LA
# MAQUINA, no como una persona: Test-Path da «acceso denegado» aunque la
# carpeta esté perfectamente y cualquier usuario entre. Ya está apuntado
# en el traspaso: eso no es prueba de nada.
if ($hayDocumentos -eq 'si') {
  try {
    $s = $w.CreateShortcut((Join-Path $esc 'Documentos del centro.lnk'))
    $s.TargetPath = '\\192.168.1.101\documentos'
    $s.Save(); "OK  icono puesto: Documentos del centro"
  } catch { "AVISO no se pudo poner el icono de Documentos" }
} else { "AVISO Documentos del centro aun no existe - crealo con: sudo redhornoma-carpeta-compartida --documentos" }
PS
redhornoma-en-windows --maquina "$VM" --guion "$GUION" 2>&1 | sed 's/^/      /'
rm -f "$GUION"

# ── 3 · Las carpetas del Windows, vistas desde Linux ──────────────────
printf "\n   ${AZ}Las carpetas del Windows, montadas aquí${V}\n"
UID_H=$(id -u hornoma 2>/dev/null || echo 1000)
GID_H=$(id -g hornoma 2>/dev/null || echo 1000)

cp -f /etc/fstab "/etc/fstab.antes-del-canal-$MARCA" && ok "copia de /etc/fstab guardada"
sed -i '/# RedHornoma canal Windows/,+3d' /etc/fstab 2>/dev/null

{
  printf '\n# RedHornoma canal Windows — las carpetas del Windows de este equipo.\n'
  printf '# «noauto,x-systemd.automount» = se montan solas la primera vez que\n'
  printf '# alguien las abre, y no bloquean el arranque si el Windows está apagado.\n'
  for c in SALMI SOAPS SNIS; do
    printf '//%s/%s  %s/%s  cifs  credentials=%s,noauto,x-systemd.automount,x-systemd.idle-timeout=300,uid=%s,gid=%s,file_mode=0664,dir_mode=0775,vers=3.0,nofail  0  0\n' \
      "$IP_NAT" "$c" "$MONTAJE" "$c" "$CRED" "$UID_H" "$GID_H"
  done
} >> /etc/fstab

for c in SALMI SOAPS SNIS; do mkdir -p "$MONTAJE/$c"; done
systemctl daemon-reload

# 🔴 «daemon-reload» CARGA las unidades pero NO las arranca. La primera
# versión de esto se quedó ahí y las tres quedaron «inactive dead»: nada
# montado, y el guion diciendo que sí. Hay que encenderlas.
for c in SALMI SOAPS SNIS; do
  systemctl start "$(systemd-escape -p --suffix=automount "$MONTAJE/$c")" 2>/dev/null
done

MONTADAS=0
for c in SALMI SOAPS SNIS; do
  printf "      %-8s " "$c"
  # Tocar la carpeta para que el automontaje salte, y DESPUÉS preguntar.
  ls "$MONTAJE/$c" >/dev/null 2>&1
  # 🔴 La comprobación va con findmnt, no con «ls».
  #
  # Antes decía:  mount … || ls … >/dev/null
  # y «ls» sobre una carpeta VACÍA sale bien. Así que cuando el montaje
  # fallaba, el «ls» lo tapaba y el guion cantaba «montada · 0 elementos».
  # Peor todavía: la prueba de escritura escribía en la carpeta local y
  # también decía que sí. Dos verdes falsos seguidos sobre algo que no
  # estaba montado. findmnt responde por el montaje real o no responde.
  if findmnt -nro SOURCE "$MONTAJE/$c" >/dev/null 2>&1; then
    N=$(ls -1 "$MONTAJE/$c" 2>/dev/null | wc -l)
    printf "${VE}montada${V}  (%s elementos)\n" "$N"; MONTADAS=$((MONTADAS+1))
  else
    printf "${RO}NO montada${V}\n"
    mount -t cifs "//$IP_NAT/$c" "$MONTAJE/$c" -o "credentials=$CRED,vers=3.0" 2>&1 \
      | head -3 | sed 's/^/         /'
  fi
done

# ── 4 · Probar el canal en los DOS sentidos ───────────────────────────
# Que los comandos no protesten no prueba nada. Lo que prueba un canal es
# cruzarlo: dejar algo de un lado y encontrarlo del otro.
printf "\n   ${AZ}Cruzando el canal en los dos sentidos${V}\n"
SELLO="prueba-canal-$MARCA.txt"

printf "      %-34s " "Linux → Windows"
echo "Escrito desde el Linux del servidor a las $(date '+%H:%M:%S')" > "$COMPARTIDA/$SELLO"
LEIDO=$(redhornoma-en-windows --maquina "$VM" --powershell \
  "if (Test-Path '\\\\192.168.122.1\\compartido\\$SELLO') { 'SI' } else { 'NO' }" 2>/dev/null | tr -d ' \r\n')
case "$LEIDO" in *SI*) printf "${VE}lo ve Windows${V}\n" ;;
                 *)    printf "${RO}Windows NO lo ve${V}\n" ;; esac

printf "      %-34s " "Windows → Linux"
redhornoma-en-windows --maquina "$VM" --powershell \
  "Set-Content -Path '\\\\192.168.122.1\\compartido\\vuelta-$SELLO' -Value 'Escrito desde Windows'" >/dev/null 2>&1
sleep 2
if [ -f "$COMPARTIDA/vuelta-$SELLO" ]; then printf "${VE}lo ve Linux${V}\n"
else printf "${RO}Linux NO lo ve${V}\n"; fi

# Esta prueba SOLO vale si la carpeta está montada de verdad. Escribir en
# una carpeta local vacía sale bien y no demuestra absolutamente nada.
printf "      %-34s " "Linux → dentro de SALMI"
if ! findmnt -nro SOURCE "$MONTAJE/SALMI" >/dev/null 2>&1; then
  printf "${RO}no montada — no se prueba${V}\n"
elif touch "$MONTAJE/SALMI/.$SELLO" 2>/dev/null; then
  # Y se comprueba desde el OTRO lado, que es lo que lo hace prueba.
  VE_WIN=$(redhornoma-en-windows --maquina "$VM" --powershell \
    "if (Test-Path 'C:\\SALMI-PN_Dispensacion_BO\\.$SELLO') { 'SI' } else { 'NO' }" 2>/dev/null | tr -d ' \r\n')
  rm -f "$MONTAJE/SALMI/.$SELLO"
  case "$VE_WIN" in *SI*) printf "${VE}escribe, y Windows lo ve${V}\n" ;;
                    *)    printf "${AM}escribió aquí pero Windows no lo ve${V}\n" ;; esac
else printf "${AM}montada pero solo lectura${V}\n"; fi

rm -f "$COMPARTIDA/$SELLO" "$COMPARTIDA/vuelta-$SELLO"

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   ${AZ}Desde Windows${V}\n"
printf "      unidad Z:                 la carpeta que comparten los dos\n"
printf "      «Carpeta de intercambio»  icono en el escritorio\n\n"
printf "   ${AZ}Desde Linux — y por tanto desde el portátil, a 100 km${V}\n"
printf "      %s/SALMI · SOAPS · SNIS\n\n" "$MONTAJE"
printf "   ${AM}La Z: aparece al INICIAR SESIÓN.${V} Si ahora hay alguien dentro\n"
printf "   de Windows, tiene que cerrar sesión y volver a entrar para verla.\n\n"
printf "   Para deshacerlo:  sudo bash %s --soltar\n\n" "$(basename "$0")"
