#!/bin/bash
# foto-del-arranque.sh — Retratar lo que ve alguien al encender.
#
# probar-compatibilidad.sh abre una ventana de QEMU y espera a que una
# persona la mire. Eso está bien para probar que instala, pero no sirve para
# revisar la PRIMERA PANTALLA: hay que estar delante, en el momento justo, y
# lo que se vea se va con la ventana.
#
# Esto arranca la ISO sin ventana y va sacando fotos. Quedan en archivos, se
# pueden mirar con calma, comparar entre versiones y guardar como prueba.
#
# Sirvió para encontrar, el 09/08/2026, que el menú de las máquinas antiguas
# enseñaba «RedHornoma ГÖ probar sin instalar»: isolinux no sabe dibujar el
# guion largo. Llevaba meses ahí y nadie lo había visto, porque para verlo
# hay que arrancar por USB y hasta ese día siempre se probaba como CD.
#
# Uso:
#   foto-del-arranque.sh                      la última ISO, los dos arranques
#   foto-del-arranque.sh --bios               solo el de las máquinas antiguas
#   foto-del-arranque.sh --uefi               solo el de las modernas
#   foto-del-arranque.sh --iso RUTA           una ISO concreta
#   foto-del-arranque.sh --cd                 como CD y no como pendrive
#   foto-del-arranque.sh --entrar             pulsa ENTER y llega al escritorio
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$BASE/pruebas/fotos-arranque"
OVMF=/usr/share/OVMF
ISO=""; MODOS="bios uefi"; MEDIO=usb; ENTRAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --bios) MODOS="bios"; shift ;;
    --uefi) MODOS="uefi"; shift ;;
    --cd)     MEDIO=cd; shift ;;
    --entrar) ENTRAR=1; shift ;;
    --iso)  ISO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "no entiendo «$1»"; exit 1 ;;
  esac
done

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; GR=$'\033[0;90m'

[ -n "$ISO" ] || ISO=$(ls -1t "$BASE"/isos/*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] && [ -f "$ISO" ] || { printf "   ${RO}✗${V} no encuentro ninguna ISO\n"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { printf "   ${RO}✗${V} falta qemu-system-x86_64\n"; exit 1; }

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "${AZ} FOTOS DEL ARRANQUE${V}\n"
printf "${AZ}══════════════════════════════════════════════════════${V}\n"
printf "   %s\n" "$(basename "$ISO")"
printf "   ${GR}entra como %s${V}\n" "$([ "$MEDIO" = usb ] && echo "PENDRIVE" || echo "CD")"

retratar(){  # modo
  local MODO="$1"
  local D="$SALIDA/$MODO-$MEDIO"
  rm -rf "$D"; mkdir -p "$D"

  # El socket va en ruta CORTA: los sockets de Unix no pasan de 108
  # caracteres y la carpeta del proyecto ya se come casi todos. Costó el
  # primer intento entero, con qemu muriendo sin decir por qué.
  local SOCK; SOCK=$(mktemp -u /tmp/rh-arranque-XXXX.sock)

  # Con 2 GB basta para ver el menú, pero el escritorio KDE en vivo no cabe:
  # arranca y se queda sin memoria a mitad.
  local RAM=2048; [ "$ENTRAR" = "1" ] && RAM=3072
  local ARG=(-m $RAM -smp 2 -display none -vga std
             -qmp "unix:$SOCK,server=on,wait=off")
  [ -w /dev/kvm ] && ARG+=(-enable-kvm)

  if [ "$MODO" = uefi ]; then
    ARG+=(-machine q35)
    cp -f "$OVMF/OVMF_VARS_4M.fd" "$D/vars.fd"
    ARG+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF/OVMF_CODE_4M.fd"
          -drive "if=pflash,format=raw,unit=1,file=$D/vars.fd")
  else
    ARG+=(-machine pc)
  fi

  if [ "$MEDIO" = usb ]; then
    # Controlador según la época: una máquina de 2011 no tiene USB 3.
    local CTL=usb-ehci; [ "$MODO" = uefi ] && CTL=qemu-xhci
    ARG+=(-device "$CTL,id=usbctl"
          -drive "file=$ISO,format=raw,readonly=on,if=none,id=pincho"
          -device usb-storage,bus=usbctl.0,drive=pincho,bootindex=1
          -boot menu=on)
  else
    ARG+=(-drive "file=$ISO,format=raw,media=cdrom,readonly=on" -boot order=d)
  fi

  printf "\n${AZ}── %s, por %s ──${V}\n" "$MODO" "$MEDIO"
  qemu-system-x86_64 "${ARG[@]}" 2>"$D/qemu.log" &
  local PID=$!
  sleep 4
  if ! kill -0 "$PID" 2>/dev/null; then
    printf "   ${RO}✗${V} qemu no arrancó:\n"; head -3 "$D/qemu.log" | sed 's/^/      /'
    rm -f "$SOCK"; return 1
  fi

  # El menú espera PARA SIEMPRE: la ISO trae «timeout 0», así que sin
  # pulsar nada no arranca nunca. Para llegar al escritorio hay que
  # apretar ENTER, y eso se puede pedir por el mismo canal que las fotos.
  local MOMENTOS="20 50 90 140"
  if [ "$ENTRAR" = "1" ]; then
    MOMENTOS="20 70 130 190 250"
  fi

  local ANTERIOR=4 t
  for t in $MOMENTOS; do
    sleep $(( t - ANTERIOR )); ANTERIOR=$t
    kill -0 "$PID" 2>/dev/null || { printf "   ${GR}se apagó sola antes del segundo %s${V}\n" "$t"; break; }
    if python3 - "$SOCK" "$D/$t"s.ppm 2>/dev/null <<'PY'
import socket, json, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile('rw')
f.readline()
f.write(json.dumps({"execute":"qmp_capabilities"})+"\n"); f.flush(); f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[2]}})+"\n"); f.flush()
f.readline()
PY
    then printf "   ${VE}●${V} segundo %s\n" "$t"
    else printf "   ${GR}no pude fotografiar en el segundo %s${V}\n" "$t"; fi

    # Después de la primera foto —cuando ya se ve el menú— se pulsa ENTER.
    if [ "$ENTRAR" = "1" ] && [ "$t" = "20" ]; then
      python3 - "$SOCK" 2>/dev/null <<'PY2' && printf "   ${GR}ENTER pulsado, entrando al sistema${V}\n"
import socket, json, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile('rw')
f.readline()
f.write(json.dumps({"execute":"qmp_capabilities"})+"\n"); f.flush(); f.readline()
f.write(json.dumps({"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":"ret"}]}})+"\n")
f.flush(); f.readline()
PY2
    fi
  done

  kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; rm -f "$SOCK"

  # Las fotos salen en PPM, que pesa 20 veces más y no lo abre casi nadie.
  local p
  for p in "$D"/*.ppm; do
    [ -f "$p" ] || continue
    if command -v convert >/dev/null 2>&1; then
      convert "$p" "${p%.ppm}.png" 2>/dev/null && rm -f "$p"
    fi
  done
  printf "   ${GR}%s${V}\n" "$D"
}

for m in $MODOS; do retratar "$m"; done

printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
printf "${AZ} LISTO${V}\n"
printf "${AZ}══════════════════════════════════════════════════════${V}\n"
find "$SALIDA" -name '*.png' -newermt '-10 minutes' 2>/dev/null | sort | sed 's|^|   |'
printf "\n   ${GR}Míralas con:  xdg-open %s${V}\n\n" "$SALIDA"
