#!/bin/bash
# programas-en-red.sh — Abrir SALMI, SOAPS 7 y SNIS del servidor a los
#                       puestos del centro. El lado del SERVIDOR.
#
# EL PORQUÉ
#
# El Windows del .101 ya tiene los tres programas del Ministerio y desde
# hoy tiene dirección propia en la red del centro (192.168.1.50). Pero por
# dentro sigue cerrado como el primer día:
#
#     cuentas         solo salud-hornoma — no existe la del centro
#     compartidas     ninguna propia
#     cortafuegos     ni una regla para SQL Server
#
# Así, un consultorio que intente entrar recibe «acceso denegado» y no hay
# nada que revisar, porque no hay nada puesto.
#
# LO QUE HACE, Y POR QUÉ ASÍ
#
# 1 · LA CUENTA. Se crea la MISMA que ya conoce el centro, sacada de
#     /etc/redhornoma/windows.credenciales — la que los puestos tienen
#     guardada para SALMI y la que usa el respaldo. Una sola credencial en
#     todo el centro: si se inventara otra, habría que ir puesto por puesto.
#
# 2 · LAS CARPETAS. Una por programa, con escritura. SALMI y SNIS guardan
#     en archivos de Access que se abren desde el puesto; SOAPS necesita su
#     carpeta para que el cliente saque los componentes.
#
# 3 · EL CORTAFUEGOS DE SQL SERVER, y aquí está lo que cuesta media tarde
#     si se hace mal: SQL Server Express NO usa un puerto fijo. Cambia en
#     cada arranque. Por eso la regla va **por programa** (sqlservr.exe) y
#     no por puerto, más el UDP 1434, que es el «buscador de instancias»
#     —el que le dice al cliente en qué puerto está hoy—. Sin el 1434, el
#     cliente encuentra la máquina y no encuentra el motor.
#
# 4 · LA LLAVE DEL REGISTRO. SOAPS guarda en HKLM\...\SUIS dónde está su
#     servidor. Sin esa llave el cliente dice «El sistema no está bien
#     instalado, consulte con su proveedor». Se exporta ya apuntando a
#     este servidor, lista para llevar al puesto.
#
# 5 · SE COMPRUEBA ENTRANDO. No basta con que los comandos no protesten:
#     al final este mismo Linux se conecta con esa cuenta y lista los
#     archivos. Si no entra, lo dice.
#
# Uso:
#   sudo bash programas-en-red.sh              lo deja funcionando
#   sudo bash programas-en-red.sh --solo-mirar enseña qué haría
set -u

VM=salud-servidor
CRED=/etc/redhornoma/windows.credenciales
COMPARTIDA=/var/lib/libvirt/compartido

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
ok(){  printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){ printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){ printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
nota(){ printf "   ${GR}%s${V}\n" "$1"; }
titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }

SOLO_MIRAR=no
case "${1:-}" in
  --solo-mirar) SOLO_MIRAR=si ;;
  "") ;;
  *) echo "Uso: $0 [--solo-mirar]"; exit 1 ;;
esac

titulo "LOS PROGRAMAS DEL SERVIDOR, ABIERTOS AL CENTRO"

# ── La máquina y su dirección ─────────────────────────────────────────
ESTADO=$(LC_ALL=C virsh -c qemu:///system domstate "$VM" 2>/dev/null | tr -d '\n')
[ "$ESTADO" = "running" ] || { mal "el Windows «$VM» no está encendido (está: ${ESTADO:-no existe})"; exit 1; }
ok "«$VM» encendido"

redhornoma-en-windows --maquina "$VM" --powershell '"vivo"' >/dev/null 2>&1 \
  || { mal "su agente invitado no contesta"; exit 1; }
ok "su agente invitado contesta"

RED_CENTRO=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | cut -d. -f1-3)
[ -n "$RED_CENTRO" ] && RED_CENTRO="$RED_CENTRO.0/24" || RED_CENTRO="192.168.1.0/24"
ok "red del centro: $RED_CENTRO"

# ── La cuenta del centro ──────────────────────────────────────────────
[ -r "$CRED" ] || { mal "no puedo leer $CRED (¿ejecutaste con sudo?)"; exit 1; }
USU=$(grep -oP '^\s*username\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r')
CLA=$(grep -oP '^\s*password\s*=\s*\K.*' "$CRED" | head -1 | tr -d '\r')
[ -n "$USU" ] && [ -n "$CLA" ] || { mal "no encuentro usuario y contraseña dentro de $CRED"; exit 1; }
ok "cuenta del centro: «$USU» (la contraseña no se enseña ni se registra)"

printf "\n   ${AZ}Lo que va a quedar${V}\n"
printf "      %-14s %s\n" "cuenta"      "$USU, creada dentro de Windows con esa misma clave"
printf "      %-14s %s\n" "SALMI"       "\\\\192.168.1.50\\SALMI"
printf "      %-14s %s\n" "SOAPS"       "\\\\192.168.1.50\\SOAPS"
printf "      %-14s %s\n" "SNIS"        "\\\\192.168.1.50\\SNIS"
printf "      %-14s %s\n" "cortafuegos" "sqlservr.exe + UDP 1434, solo desde $RED_CENTRO"
printf "      %-14s %s\n" "para el puesto" "SUIS.reg en la carpeta compartida"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"; exit 0
fi
[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo"; exit 1; }

# ── El guion que va dentro de Windows ─────────────────────────────────
# Lleva la contraseña, así que se escribe con permisos cerrados y se borra
# al terminar. Nunca se pasa por la línea de órdenes, que queda a la vista
# de cualquiera que mire los procesos.
GUION=$(mktemp /tmp/rh-red-XXXXXX.ps1)
chmod 600 "$GUION"
trap 'rm -f "$GUION"' EXIT

{
printf '$usu = %s\n' "'$(printf '%s' "$USU" | sed "s/'/''/g")'"
printf '$cla = %s\n' "'$(printf '%s' "$CLA" | sed "s/'/''/g")'"
printf '$red = %s\n' "'$RED_CENTRO'"
cat <<'PS'
$ErrorActionPreference = 'Continue'

# ── 1 · La cuenta ─────────────────────────────────────────────────────
$sec = ConvertTo-SecureString $cla -AsPlainText -Force
$y = Get-LocalUser -Name $usu -EA SilentlyContinue
if ($y) {
  Set-LocalUser -Name $usu -Password $sec -PasswordNeverExpires $true -EA SilentlyContinue
  "OK  la cuenta $usu ya existia - contrasena puesta al dia"
} else {
  New-LocalUser -Name $usu -Password $sec -PasswordNeverExpires -AccountNeverExpires `
    -FullName "Cuenta de red del centro" -Description "RedHornoma - acceso de los puestos" -EA SilentlyContinue | Out-Null
  if (Get-LocalUser -Name $usu -EA SilentlyContinue) { "OK  cuenta $usu creada" } else { "MAL no se pudo crear la cuenta $usu" }
}
Enable-LocalUser -Name $usu -EA SilentlyContinue

# ── 2 · Las carpetas de los programas ─────────────────────────────────
# Se buscan, no se dan por sabidas: cada centro instala donde le toca.
$mapa = @{}
foreach ($p in @('C:\SALMI-PN_Dispensacion_BO','C:\SALMI')) { if (Test-Path $p) { $mapa['SALMI'] = $p; break } }
foreach ($p in @('C:\SOAPS7','C:\SOAPS'))                   { if (Test-Path $p) { $mapa['SOAPS'] = $p; break } }
foreach ($p in @('C:\SNIS2026'))                            { if (Test-Path $p) { $mapa['SNIS']  = $p; break } }

foreach ($n in $mapa.Keys) {
  $ruta = $mapa[$n]
  $ya = Get-SmbShare -Name $n -EA SilentlyContinue
  if ($ya) {
    Grant-SmbShareAccess -Name $n -AccountName $usu -AccessRight Full -Force -EA SilentlyContinue | Out-Null
    "OK  $n ya estaba compartida ($ruta) - permiso dado a $usu"
  } else {
    New-SmbShare -Name $n -Path $ruta -FullAccess $usu -Description "RedHornoma - $n del centro" -EA SilentlyContinue | Out-Null
    if (Get-SmbShare -Name $n -EA SilentlyContinue) { "OK  $n compartida  ->  $ruta" } else { "MAL no se pudo compartir $n" }
  }
  # El permiso de la carpeta en el disco: sin esto, la carpeta se ve y
  # no se puede escribir, y el error que da no lo explica.
  & icacls $ruta /grant "${usu}:(OI)(CI)M" /T /C 2>&1 | Out-Null
}
foreach ($n in @('SALMI','SOAPS','SNIS')) { if (-not $mapa.ContainsKey($n)) { "AVISO $n no esta instalado en este servidor - no se comparte" } }

# ── 3 · El cortafuegos de SQL Server ──────────────────────────────────
# POR PROGRAMA, no por puerto: SQL Server Express cambia de puerto en cada
# arranque. Y el UDP 1434 aparte, que es quien le dice al cliente cual es.
$inst = Get-Service | Where-Object { $_.Name -like 'MSSQL$*' -and $_.Status -eq 'Running' } | Select-Object -First 1
if ($inst) {
  $exe = (Get-CimInstance Win32_Service -Filter "Name='$($inst.Name)'").PathName -replace '^"([^"]+)".*$','$1'
  if (Test-Path $exe) {
    Remove-NetFirewallRule -DisplayName 'RedHornoma - SQL Server (SOAPS)' -EA SilentlyContinue
    New-NetFirewallRule -DisplayName 'RedHornoma - SQL Server (SOAPS)' -Direction Inbound -Program $exe `
      -Action Allow -Profile Any -RemoteAddress $red -EA SilentlyContinue | Out-Null
    "OK  cortafuegos: permitido $exe desde $red"
  } else { "MAL no encuentro el programa de SQL Server ($exe)" }
  Remove-NetFirewallRule -DisplayName 'RedHornoma - Buscador de instancias SQL' -EA SilentlyContinue
  New-NetFirewallRule -DisplayName 'RedHornoma - Buscador de instancias SQL' -Direction Inbound -Protocol UDP `
    -LocalPort 1434 -Action Allow -Profile Any -RemoteAddress $red -EA SilentlyContinue | Out-Null
  "OK  cortafuegos: UDP 1434 abierto desde $red"

  # ── 4 · La llave del registro, para el puesto ───────────────────────
  $mi = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '192.168.122.*' } | Select-Object -First 1).IPAddress
  $sv = $inst.Name -replace '^MSSQL\$',''
  $dst = 'C:\RESPALDOS\SUIS.reg'
  New-Item -ItemType Directory -Path 'C:\RESPALDOS' -Force -EA SilentlyContinue | Out-Null
  & reg export 'HKLM\SOFTWARE\WOW6432Node\SUIS' $dst /y 2>&1 | Out-Null
  if (Test-Path $dst) {
    # Dejarla apuntando a ESTE servidor, que es lo que el puesto necesita.
    (Get-Content $dst -Raw) -replace '\.\\' + $sv, ($mi + '\' + $sv) | Set-Content $dst -Encoding Unicode
    "OK  llave del registro lista para el puesto: $dst  (servidor $mi\$sv)"
  } else { "AVISO no se pudo exportar la llave SUIS - el puesto la necesitara" }
} else { "AVISO SQL Server no esta corriendo - SOAPS no se podra usar en red" }

"--- COMO QUEDO ---"
Get-SmbShare -EA SilentlyContinue | Where-Object { $_.Name -notmatch '\$$' } | ForEach-Object { "   " + $_.Name + "  ->  " + $_.Path }
PS
} > "$GUION"

printf "\n   ${AZ}Dentro de Windows${V}\n"
redhornoma-en-windows --maquina "$VM" --guion "$GUION" 2>&1 | sed 's/^/      /'
rm -f "$GUION"

# ── 5 · Comprobarlo ENTRANDO, que es la única prueba que vale ─────────
# El Windows tiene dos direcciones. Desde este Linux se llega por la de
# NAT: con el puente macvtap, la de la red del centro no es alcanzable
# desde aquí. Eso NO significa que los puestos no lleguen.
printf "\n   ${AZ}Comprobando de verdad: entrando con la cuenta del centro${V}\n"
IP_NAT=$(LC_ALL=C virsh -c qemu:///system qemu-agent-command "$VM" \
  '{"execute":"guest-network-get-interfaces"}' 2>/dev/null \
  | grep -oP '"ip-address":"\K192\.168\.122\.[0-9]+' | head -1)
IP_NAT="${IP_NAT:-192.168.122.226}"

BIEN=0; TOTAL=0
for c in SALMI SOAPS SNIS; do
  TOTAL=$((TOTAL+1))
  printf "      %-8s " "$c"
  SAL=$(smbclient "//$IP_NAT/$c" -A "$CRED" -t 15 -c 'ls' 2>&1)
  if printf '%s' "$SAL" | grep -q "blocks of size"; then
    N=$(printf '%s' "$SAL" | grep -cE '^\s+\S')
    printf "${VE}entra${V}  (%s elementos)\n" "$N"; BIEN=$((BIEN+1))
  else
    printf "${RO}no entra${V}\n"
    printf '%s\n' "$SAL" | head -2 | sed 's/^/         /'
  fi
done

# La llave del registro, a mano para llevarla al puesto.
if [ -f "$COMPARTIDA/RESPALDOS/SUIS.reg" ]; then
  ok "la llave del puesto está en $COMPARTIDA/RESPALDOS/SUIS.reg"
fi

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
if [ "$BIEN" = "$TOTAL" ]; then
  printf "   ${VE}Los %s programas se abren desde fuera con la cuenta del centro.${V}\n\n" "$TOTAL"
else
  printf "   ${AM}%s de %s programas entran. Mira arriba qué dijo el que falta.${V}\n\n" "$BIEN" "$TOTAL"
fi
printf "   Desde un puesto del centro, las rutas son:\n\n"
printf "      \\\\\\\\192.168.1.50\\\\SALMI\n"
printf "      \\\\\\\\192.168.1.50\\\\SOAPS\n"
printf "      \\\\\\\\192.168.1.50\\\\SNIS\n\n"
printf "   ${AM}Ojo con SNIS:${V} sus 39 tablas buscan C:\\\\SNIS2026 por ruta fija.\n"
printf "   En el puesto hay que hacer el enlace de directorio, o SNIS entra\n"
printf "   igual y enseña los datos INCOMPLETOS sin avisar de nada.\n\n"
