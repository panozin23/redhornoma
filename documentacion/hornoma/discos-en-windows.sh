#!/bin/bash
# discos-en-windows.sh — Que los discos externos del .101 se vean DENTRO
#                        de su Windows, y se pueda escribir en ellos.
#
# EL PORQUÉ
#
# Los discos están enchufados al Linux del .101 y montados. Samba ya los
# publica. Y aun así, desde el Windows de dentro «no se ven». Son dos
# cosas distintas, y hacen falta las dos:
#
#   1. EN LINUX — las dos particiones del Samsung están publicadas como
#      «read only = yes». Eso viene de cuando se puso la regla de solo
#      lectura por sus 6 sectores dudosos. euflo la quitó: es su disco.
#
#   2. EN WINDOWS — las carpetas se publican SIN CONTRASEÑA («guest ok»),
#      y Windows 10 y 11 traen eso PROHIBIDO de fábrica. Samba las sirve
#      bien, Windows se niega, y no explica por qué: parece que la carpeta
#      no existe. Es el mismo caso que costó una tarde con «Documentos del
#      centro» el 08/08.
#
#      Se abre poniendo «AllowInsecureGuestAuth» en ese Windows. Aquí es
#      aceptable porque las carpetas están limitadas a «hosts allow =
#      192.168.122.», que es la red privada entre este Linux y su propio
#      Windows: no la alcanza ninguna otra computadora del centro.
#
# NO se mapean letras de unidad. El agente invitado corre como SYSTEM, y
# una unidad que mapea SYSTEM no la ve ningún usuario — está apuntado en
# el traspaso. En su lugar se dejan ICONOS en el escritorio de todos los
# usuarios, con la ruta entera.
#
# Uso:
#   sudo bash discos-en-windows.sh              lo deja funcionando
#   sudo bash discos-en-windows.sh --solo-mirar enseña qué haría, sin tocar
set -u

CONF=/etc/samba/smb.conf
USUARIO=hornoma
IP_LINUX=192.168.122.1     # la dirección del Linux vista desde su Windows
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
case "${1:-}" in
  --solo-mirar) SOLO_MIRAR=si ;;
  "") ;;
  *) echo "Uso: $0 [--solo-mirar]"; exit 1 ;;
esac

titulo "LOS DISCOS EXTERNOS, DENTRO DE WINDOWS"

# ── 1 · ¿Qué hay montado de verdad? ───────────────────────────────────
# No se comparte lo que no está montado: se publicaría una carpeta vacía
# y el Windows enseñaría un disco sin nada, que es peor que no verlo.
printf "\n   ${AZ}Qué discos hay montados${V}\n"
MONTADOS=""
for etq in SANSUNG1 SANSUNG2 CURSAKIALINUX; do
  PUNTO="/media/$USUARIO/$etq"
  if findmnt -nro TARGET "$PUNTO" >/dev/null 2>&1; then
    LIBRE=$(df -h "$PUNTO" | tail -1 | awk '{print $2" total, "$4" libres"}')
    ok "$etq — $LIBRE"
    MONTADOS="$MONTADOS $etq"
  else
    nota "$etq — no está montado, no se comparte"
  fi
done
[ -n "$MONTADOS" ] || { mal "no hay ningún disco externo montado"; exit 1; }

# ── 2 · ¿Está encendido su Windows? ───────────────────────────────────
printf "\n   ${AZ}Su Windows${V}\n"
VM=$(LC_ALL=C virsh -c qemu:///system list --name --state-running 2>/dev/null | grep -v '^$' | head -1)
if [ -z "$VM" ]; then
  mal "no hay ningún Windows encendido en este equipo"
  echo "      Enciéndelo y vuelve a intentarlo."
  exit 1
fi
ok "«$VM» encendido"
if redhornoma-en-windows --maquina "$VM" --powershell '"agente vivo"' >/dev/null 2>&1; then
  ok "su agente invitado contesta"
else
  mal "su agente invitado no contesta — sin él no se puede tocar Windows desde aquí"
  exit 1
fi

# ── 3 · Lo que va a cambiar ───────────────────────────────────────────
printf "\n   ${AZ}Lo que va a cambiar${V}\n"
printf "      %-34s %s\n" "en Linux:  read only" "yes → no  (SANSUNG1 y SANSUNG2)"
printf "      %-34s %s\n" "en Windows: AllowInsecureGuestAuth" "→ 1  (deja entrar sin contraseña)"
printf "      %-34s %s\n" "en Windows: iconos en el escritorio" "uno por disco montado"

if [ "$SOLO_MIRAR" = "si" ]; then
  printf "\n   ${AM}Solo mirando: no se ha tocado nada.${V}\n\n"
  exit 0
fi
[ "$(id -u)" = "0" ] || { echo; mal "hace falta sudo"; exit 1; }

# ── 4 · Lado Linux: abrir la escritura ────────────────────────────────
printf "\n   ${AZ}En Linux${V}\n"
cp -f "$CONF" "$CONF.antes-de-discos-$MARCA" && ok "copia de seguridad: smb.conf.antes-de-discos-$MARCA"

# Solo dentro de los bloques [SANSUNG1] y [SANSUNG2]: no se toca nada más
# del archivo, que también sirve al respaldo y a la carpeta del centro.
python3 - "$CONF" <<'PY'
import re, sys
ruta = sys.argv[1]
texto = open(ruta, encoding='utf-8').read()
def abrir(m):
    bloque = m.group(0)
    if re.search(r'^\s*read only\s*=', bloque, re.M):
        return re.sub(r'^(\s*read only\s*=\s*).*$', r'\1no', bloque, flags=re.M)
    return bloque.rstrip('\n') + '\n   read only = no\n'
for nombre in ('SANSUNG1', 'SANSUNG2'):
    texto = re.sub(r'^\[' + nombre + r'\].*?(?=^\[|\Z)', abrir, texto,
                   flags=re.M | re.S)
open(ruta, 'w', encoding='utf-8').write(texto)
PY

# No basta con escribir la configuración: si tiene un error, smbd arranca
# con la de antes y todo «parece» bien.
if ! testparm -s "$CONF" >/dev/null 2>&1; then
  mal "la configuración de Samba quedó mal — se devuelve la de antes"
  cp -f "$CONF.antes-de-discos-$MARCA" "$CONF"
  exit 1
fi
ok "configuración de Samba correcta"

systemctl restart smbd 2>/dev/null
sleep 2
systemctl is-active smbd >/dev/null 2>&1 || { mal "smbd no arrancó"; exit 1; }
ok "servicio de carpetas compartidas en marcha"

# Y comprobar leyendo, no confiando en que el reinicio bastó.
for etq in $MONTADOS; do
  NOM="$etq"; [ "$etq" = "CURSAKIALINUX" ] && NOM=TOSHIBA
  RO=$(testparm -s --section-name "$NOM" --parameter-name "read only" 2>/dev/null | tail -1)
  printf "      %-14s escritura: %s\n" "$NOM" \
    "$([ "$RO" = "No" ] && echo "${VE}sí${V}" || echo "${AM}$RO${V}")"
done

# ── 5 · Lado Windows ──────────────────────────────────────────────────
printf "\n   ${AZ}En Windows${V}\n"

LISTA=""
for etq in $MONTADOS; do
  NOM="$etq"; [ "$etq" = "CURSAKIALINUX" ] && NOM=TOSHIBA
  LISTA="$LISTA'$NOM',"
done
LISTA="${LISTA%,}"

GUION=/tmp/rh-discos-windows.ps1
cat > "$GUION" <<PS
\$ErrorActionPreference = 'Continue'
\$discos = @($LISTA)
\$ip = '$IP_LINUX'
PS
cat >> "$GUION" <<'PS'

# 1 · Permitir entrar a carpetas de red sin contraseña.
#     Windows 10/11 lo traen prohibido de fábrica y NO lo explica: la
#     carpeta simplemente no aparece.
$k = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
New-ItemProperty -Path $k -Name AllowInsecureGuestAuth -Value 1 -PropertyType DWord -Force | Out-Null
$puesto = (Get-ItemProperty -Path $k -Name AllowInsecureGuestAuth -ErrorAction SilentlyContinue).AllowInsecureGuestAuth
if ($puesto -eq 1) { "OK  entrar sin contrasena: permitido" } else { "MAL no se pudo permitir la entrada sin contrasena" }

# 2 · Que el cliente de red lo tome sin reiniciar Windows.
try { Restart-Service LanmanWorkstation -Force -ErrorAction Stop; Start-Sleep -Seconds 4; "OK  cliente de red reiniciado" }
catch { "AVISO el cliente de red no se dejo reiniciar: hara falta reiniciar Windows" }

# 3 · Un icono por disco, en el escritorio de TODOS los usuarios.
#     No se mapean letras de unidad: el agente corre como SYSTEM y una
#     unidad suya no la ve ningun usuario.
$esc = Join-Path $env:PUBLIC 'Desktop'
$w = New-Object -ComObject WScript.Shell
foreach ($d in $discos) {
  $ruta = '\\' + $ip + '\' + $d
  try {
    $s = $w.CreateShortcut((Join-Path $esc ("Disco " + $d + ".lnk")))
    $s.TargetPath = $ruta
    $s.Description = "Disco externo " + $d + " del servidor"
    $s.Save()
    "OK  icono puesto: Disco $d  ->  $ruta"
  } catch {
    "MAL no se pudo poner el icono de $d : $($_.Exception.Message)"
  }
}
PS

if redhornoma-en-windows --maquina "$VM" --guion "$GUION" 2>&1 | sed 's/^/      /'; then
  :
else
  mal "no se pudo ejecutar dentro de Windows"
fi
rm -f "$GUION"

# ── 6 · Cómo queda ────────────────────────────────────────────────────
printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   Dentro de Windows, en el escritorio, tienes un icono por disco.\n"
printf "   Y si prefieres escribir la ruta a mano:\n\n"
for etq in $MONTADOS; do
  NOM="$etq"; [ "$etq" = "CURSAKIALINUX" ] && NOM=TOSHIBA
  printf "      \\\\\\\\%s\\\\%s\n" "$IP_LINUX" "$NOM"
done
printf "\n   ${AM}Si aun así no se ven:${V} reinicia el Windows. El permiso de\n"
printf "   entrar sin contraseña a veces solo se aplica al arrancar.\n\n"
printf "   ${AM}Y lo de siempre con el Samsung:${V} 6 sectores que no lee bien.\n"
printf "   Va con escritura porque tú lo decidiste. Lo que solo esté ahí,\n"
printf "   no está a salvo.\n\n"
