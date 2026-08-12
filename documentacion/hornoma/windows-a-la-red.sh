#!/bin/bash
# windows-a-la-red.sh — Sacar el Windows del servidor a la red del centro,
#                       SIN perder lo que ya funciona por dentro.
#
# EL PORQUÉ
#
# El Windows del .101 vive en 192.168.122.226, dentro de la red privada que
# el propio Linux le fabrica (NAT). Desde ahí él sale, pero nadie entra: un
# consultorio del centro no puede llegar a sus carpetas ni a su SQL Server.
# Por eso el objetivo 2 —«meter información desde cualquier máquina de la
# red interna»— está en CERO en Hornoma por muchos programas que se
# instalen dentro.
#
# POR QUÉ UNA SEGUNDA TARJETA Y NO CAMBIAR LA QUE HAY
#
# «redhornoma-papel --papel servidor» sustituye la tarjeta por una en
# puente de tipo «macvtap». Funciona, y es lo que corre en Cochabamba.
# Pero macvtap tiene una limitación conocida del núcleo:
#
#     la máquina virtual habla con TODO el centro, menos con el Linux
#     que la aloja.
#
# En Cochabamba eso da igual. Aquí no: el 12/08 se publicaron los discos
# externos en \\192.168.122.1\SANSUNG1 y \SANSUNG2, y esa dirección ES el
# Linux de abajo. Sustituir la tarjeta dejaría al Windows sin los discos.
#
# Con dos tarjetas se queda todo:
#
#     la de ahora (NAT)      192.168.122.226   los discos externos
#     la nueva (puente)      192.168.1.50      el centro entero
#
# El Windows tiene que estar APAGADO: la red no se cambia en caliente.
#
# LO QUE NO SE VE VENIR Y ROMPE ESTO
#
# Al aparecer una red nueva, Windows la clasifica como «Pública» y
# BLOQUEA el compartir archivos. Todo quedaría bien puesto y los puestos
# seguirían sin entrar, sin un solo mensaje de error. Por eso el guion la
# pone en «Privada» y lo comprueba leyéndolo de vuelta.
#
# Uso:
#   sudo bash windows-a-la-red.sh                 la pone en 192.168.1.50
#   sudo bash windows-a-la-red.sh --ip 192.168.1.60
#   sudo bash windows-a-la-red.sh --solo-mirar    enseña qué haría
#   sudo bash windows-a-la-red.sh --deshacer      quita la tarjeta nueva
set -u

VM=salud-servidor
IP_NUEVA=192.168.1.50
RESP=/var/backups/redhornoma
MARCA="$(date '+%Y%m%d-%H%M')"

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

SOLO_MIRAR=no; DESHACER=no
while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP_NUEVA="${2:-}"; shift 2 ;;
    --solo-mirar) SOLO_MIRAR=si; shift ;;
    --deshacer)   DESHACER=si; shift ;;
    *) echo "Uso: $0 [--ip DIRECCION] [--solo-mirar | --deshacer]"; exit 1 ;;
  esac
done

VIRSH="virsh -c qemu:///system"
titulo "EL WINDOWS DEL SERVIDOR, A LA RED DEL CENTRO"

# ── Por dónde sale este Linux, y a qué red ────────────────────────────
RT=$(ip route get 1.1.1.1 2>/dev/null)
IFAZ=$(echo "$RT" | grep -oP 'dev \K\S+')
IP_LINUX=$(echo "$RT" | grep -oP 'src \K\S+')
RED=$(echo "$IP_LINUX" | cut -d. -f1-3)
PUERTA=$(ip route | grep -oP '^default via \K\S+' | head -1)

[ -n "$IFAZ" ] || { mal "no consigo saber por dónde sale este equipo a la red"; exit 1; }

printf "\n   ${AZ}Esta computadora${V}\n"
printf "      %-22s %s\n" "sale por"   "$IFAZ"
printf "      %-22s %s\n" "su dirección" "$IP_LINUX"
printf "      %-22s %s\n" "el router"  "${PUERTA:-no se ve}"

# Un puente no funciona sobre wifi: el punto de acceso descarta lo que
# venga con una dirección física que no reconoce. Decirlo antes de tocar.
case "$IFAZ" in
  wl*|wlan*|wlp*)
    mal "este equipo sale por WIFI ($IFAZ), y un puente no funciona por wifi"
    echo "      El punto de acceso descarta el tráfico de la máquina virtual."
    echo "      Hay que conectar el servidor por CABLE."
    exit 1 ;;
esac
ok "sale por cable — el puente puede funcionar"

# ── La máquina ────────────────────────────────────────────────────────
printf "\n   ${AZ}Su Windows${V}\n"
ESTADO=$(LC_ALL=C $VIRSH domstate "$VM" 2>/dev/null | tr -d '\n')
[ -n "$ESTADO" ] || { mal "no existe la máquina «$VM»"; exit 1; }
printf "      %-22s %s\n" "estado" "$ESTADO"

printf "\n   ${AZ}Sus tarjetas de red ahora${V}\n"
LC_ALL=C $VIRSH domiflist "$VM" 2>/dev/null | sed 's/^/      /'

YA=$(LC_ALL=C $VIRSH dumpxml "$VM" 2>/dev/null | grep -c "interface type='direct'")

# ── Deshacer ──────────────────────────────────────────────────────────
if [ "$DESHACER" = "si" ]; then
  [ "$(id -u)" = "0" ] || { mal "hace falta sudo"; exit 1; }
  [ "$ESTADO" = "shut off" ] || { mal "apaga el Windows primero"; exit 1; }
  [ "$YA" -gt 0 ] || { ok "no tiene ninguna tarjeta en puente — nada que quitar"; exit 0; }
  TMP=/tmp/rh-iface-quitar.xml
  LC_ALL=C $VIRSH dumpxml "$VM" | awk "/<interface type='direct'>/,/<\/interface>/" > "$TMP"
  if $VIRSH detach-device "$VM" "$TMP" --config >/dev/null 2>&1; then
    ok "tarjeta en puente quitada — vuelve a estar solo en NAT"
  else
    mal "no se pudo quitar"
  fi
  rm -f "$TMP"; exit 0
fi

if [ "$YA" -gt 0 ]; then
  ok "ya tiene una tarjeta en puente — no se añade otra"
  echo "      Si quieres rehacerla: $0 --deshacer  y volver a ejecutar esto."
  exit 0
fi

# ── Lo que va a pasar ─────────────────────────────────────────────────
printf "\n   ${AZ}Lo que va a pasar${V}\n"
printf "      %-22s %s\n" "se CONSERVA"  "la tarjeta de ahora (NAT) → los discos externos"
printf "      %-22s %s\n" "se AÑADE"     "una tarjeta en puente sobre $IFAZ"
printf "      %-22s %s\n" "dentro tendrá" "$IP_NUEVA  ·  router ${PUERTA:-$RED.1}"
printf "      %-22s %s\n" "y su red será" "Privada, para que se puedan compartir carpetas"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi
[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo"; exit 1; }
[ "$ESTADO" = "shut off" ] || { echo; mal "el Windows tiene que estar APAGADO"
  echo "      La red no se cambia en caliente. Apágalo desde dentro, o:"
  echo "         virsh -c qemu:///system shutdown $VM"; exit 1; }

# Que la dirección elegida no esté ya cogida por otra computadora.
printf "\n   ${AZ}Comprobando que %s esté libre${V}\n" "$IP_NUEVA"
if ping -c2 -W2 "$IP_NUEVA" >/dev/null 2>&1; then
  mal "$IP_NUEVA ya responde: hay otra computadora usándola"
  echo "      Elige otra con  --ip $RED.60  y vuelve a intentarlo."
  exit 1
fi
ok "libre"

# ── Añadir la tarjeta ─────────────────────────────────────────────────
printf "\n   ${AZ}Añadiendo la tarjeta${V}\n"
mkdir -p "$RESP"
LC_ALL=C $VIRSH dumpxml "$VM" > "$RESP/$VM-antes-de-la-red-$MARCA.xml" 2>/dev/null \
  && ok "cómo estaba, guardado en $RESP/$VM-antes-de-la-red-$MARCA.xml"

NUEVA=/tmp/rh-iface-nueva.xml
cat > "$NUEVA" <<XML
<interface type='direct'>
  <source dev='${IFAZ}' mode='bridge'/>
  <model type='virtio'/>
</interface>
XML
# Sin <mac>: que la ponga libvirt y la leemos después. Inventarla a mano
# es la forma de chocar con otra máquina sin enterarse.
if $VIRSH attach-device "$VM" "$NUEVA" --config >/dev/null 2>&1; then
  ok "tarjeta en puente añadida sobre $IFAZ"
else
  mal "no se pudo añadir la tarjeta — la máquina sigue como estaba"; rm -f "$NUEVA"; exit 1
fi
rm -f "$NUEVA"

MAC=$(LC_ALL=C $VIRSH domiflist "$VM" 2>/dev/null | awk '$2=="direct"{print $NF}' | head -1)
[ -n "$MAC" ] || { mal "no consigo leer la dirección física de la tarjeta nueva"; exit 1; }
ok "su dirección física es $MAC"

# ── Encender y esperar al agente ──────────────────────────────────────
printf "\n   ${AZ}Encendiendo el Windows${V}\n"
$VIRSH start "$VM" >/dev/null 2>&1 && ok "encendido"
printf "   %-30s " "esperando a su agente"
VIVO=0
for _ in $(seq 1 40); do   # hasta 10 minutos: una máquina vieja tarda
  sleep 15
  if LC_ALL=C $VIRSH qemu-agent-command --timeout 20 "$VM" \
       '{"execute":"guest-ping"}' 2>/dev/null | grep -q return; then VIVO=1; break; fi
done
[ "$VIVO" = "1" ] && printf "${VE}contesta${V}\n" || {
  printf "${RO}no contesta${V}\n"
  mal "el Windows arrancó pero su agente no responde"
  echo "      Mira su pantalla con:  redhornoma-entrar"
  echo "      La tarjeta está puesta; solo falta configurarla dentro."
  exit 1; }

# ── Configurarla dentro de Windows ────────────────────────────────────
printf "\n   ${AZ}Configurándola dentro de Windows${V}\n"
GUION=/tmp/rh-red-windows.ps1
cat > "$GUION" <<PS
\$mac = '$(echo "$MAC" | tr 'a-f:' 'A-F-')'
\$ip  = '$IP_NUEVA'
\$gw  = '${PUERTA:-$RED.1}'
PS
cat >> "$GUION" <<'PS'
$ErrorActionPreference = 'Continue'

$a = Get-NetAdapter | Where-Object { $_.MacAddress -eq $mac }
if (-not $a) { "MAL no encuentro la tarjeta $mac dentro de Windows"; exit }
"OK  tarjeta encontrada: " + $a.Name + "  (" + $a.Status + ")"

# Quitar lo que hubiera puesto antes, para no acumular direcciones.
Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -EA SilentlyContinue |
  Remove-NetIPAddress -Confirm:$false -EA SilentlyContinue
Remove-NetRoute -InterfaceIndex $a.ifIndex -Confirm:$false -EA SilentlyContinue

New-NetIPAddress -InterfaceIndex $a.ifIndex -IPAddress $ip -PrefixLength 24 -DefaultGateway $gw -EA SilentlyContinue | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $gw -EA SilentlyContinue

$puesta = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -EA SilentlyContinue).IPAddress
if ($puesta -contains $ip) { "OK  direccion puesta: $ip" } else { "MAL no se pudo poner $ip (quedo: $puesta)" }

# Windows clasifica toda red nueva como PUBLICA y bloquea el compartir
# archivos. Sin esto, todo quedaria bien y los puestos no entrarian.
Start-Sleep -Seconds 5
$p = Get-NetConnectionProfile -InterfaceIndex $a.ifIndex -EA SilentlyContinue
if ($p) {
  Set-NetConnectionProfile -InterfaceIndex $a.ifIndex -NetworkCategory Private -EA SilentlyContinue
  Start-Sleep -Seconds 2
  $c = (Get-NetConnectionProfile -InterfaceIndex $a.ifIndex -EA SilentlyContinue).NetworkCategory
  if ($c -eq 'Private') { "OK  la red quedo como Privada" } else { "AVISO la red quedo como $c - las carpetas seguiran bloqueadas" }
} else { "AVISO Windows aun no ha clasificado esa red" }

# Y comprobar de verdad que sale: preguntandole al router.
if (Test-Connection -ComputerName $gw -Count 2 -Quiet -EA SilentlyContinue) {
  "OK  llega al router $gw"
} else { "MAL no llega al router $gw" }

"--- como quedo ---"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } |
  ForEach-Object { "   " + $_.IPAddress + "/" + $_.PrefixLength + "  " + $_.InterfaceAlias }
PS

redhornoma-en-windows --maquina "$VM" --guion "$GUION" 2>&1 | sed 's/^/      /'
rm -f "$GUION"

# ── Comprobarlo desde fuera, que es la única prueba que vale ──────────
printf "\n   ${AZ}Comprobándolo desde este Linux${V}\n"
nota "Ojo: con este tipo de puente, el Linux de abajo NO puede hablar con"
nota "su propia máquina virtual. Que desde aquí no responda es NORMAL."
nota "La prueba buena es desde otra computadora del centro."
sleep 3
if ping -c2 -W2 "$IP_NUEVA" >/dev/null 2>&1; then
  ok "$IP_NUEVA responde"
else
  nota "$IP_NUEVA no responde desde aquí — esperado, mira desde tu portátil"
fi

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   Compruébalo desde el PORTÁTIL, que sí lo ve:\n\n"
printf "      ping -c3 %s\n" "$IP_NUEVA"
printf "      smbclient -L //%s -N\n\n" "$IP_NUEVA"
printf "   Si responde, el objetivo 2 deja de estar en cero en Hornoma.\n\n"
printf "   Para deshacerlo:  sudo bash %s --deshacer\n\n" "$(basename "$0")"
