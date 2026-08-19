#!/bin/bash
# probar-compatibilidad.sh — ¿Instala RedHornoma en cualquier máquina?
#
# Hasta hoy la respuesta era «en las dos que probamos, sí». Eso no es una
# respuesta: es una anécdota. Un centro de salud que reciba el pendrive
# tendrá la máquina que tenga, no la nuestra.
#
# Este guion no necesita máquinas prestadas. El portátil finge ser cada una
# de ellas: le da a QEMU el firmware, la memoria, los hilos y el tipo de
# disco de una máquina de 2011 o de una comprada ayer. Lo que falle aquí,
# habría fallado allá.
#
# Lo que NO puede fingir: fabricantes concretos con firmware defectuoso,
# tarjetas de vídeo raras y discos que se están muriendo. Eso solo se ve en
# hierro de verdad. Aquí se cubre todo lo demás, que es casi todo.
#
# Uso:
#   probar-compatibilidad.sh --lista           qué máquinas sabe fingir
#   probar-compatibilidad.sh antigua           probar una
#   probar-compatibilidad.sh --todas           una detrás de otra
#   probar-compatibilidad.sh --instalado antigua   arrancar lo ya instalado
#   probar-compatibilidad.sh --desde-usb antigua   arrancar como PENDRIVE
#   probar-compatibilidad.sh --resultados      qué salió en las pruebas
#   probar-compatibilidad.sh --foto antigua    una foto de su pantalla AHORA
set -u

# ¿La ISO entra como CD o como pendrive?
#
# No es el mismo camino. Un CD arranca por El Torito, que va dentro del
# sistema de archivos; un pendrive arranca por el sector de inicio del propio
# disco, como un disco duro cualquiera. La ISO lleva los dos, pero hasta el
# 09/08/2026 este guion solo había probado el del CD — y en un centro nadie
# instala desde un CD: se instala desde un pendrive.
#
# La primera vez que se probó el camino del pendrive salió un defecto que
# llevaba meses ahí: el menú de arranque de las máquinas antiguas enseñaba
# «RedHornoma ГÖ probar sin instalar».
DESDE_USB=0

BASE="$(cd "$(dirname "$0")/.." && pwd)"
TRABAJO="$BASE/pruebas"
RESULTADOS="$TRABAJO/resultados.md"
OVMF=/usr/share/OVMF

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n%s══════════════════════════════════════════════════════%s\n%s %s%s\n%s══════════════════════════════════════════════════════%s\n" "$AZ" "$V" "$AZ" "$1" "$V" "$AZ" "$V"; }
ok(){   printf "   %s●%s %s\n" "$VE" "$V" "$1"; }
mal(){  printf "   %s✗%s %s\n" "$RO" "$V" "$1"; }
avis(){ printf "   %s!%s %s\n" "$AM" "$V" "$1"; }
nota(){ printf "   %s%s%s\n" "$GR" "$1" "$V"; }

# ── Las máquinas que sabemos fingir ──────────────────────────────────
#
# Cada una son siete datos: nombre, descripción, firmware, memoria en MB,
# hilos, modelo de procesador, tipo de disco.
#
# El modelo de procesador importa más de lo que parece: «core2duo» no tiene
# instrucciones que un Debian moderno da por supuestas en máquinas nuevas.
# Si algo va a romperse por antigüedad, se rompe ahí.
PERFILES=(
  # «centro» es la que más importa y la que faltaba: está medida sobre
  # servidor-ciudad, una máquina de escritorio real de un centro. Arranca por
  # BIOS ANTIGUO —no UEFI, aunque lleve Windows 10—, dos núcleos y disco SATA
  # de platos. Hasta el 08/08 se probaba de todo menos esto.
  "centro|La que de verdad hay en los centros, medida sobre una real|bios|4096|2|core2duo|sata"
  "antigua|PC de escritorio de 2011, como el de Hornoma|bios|2048|2|core2duo|ide"
  # 2048 y no 1536: euflo, que es quien ve las máquinas que llegan, dice que
  # de 1 GB ya no queda ninguna y que de 2 apenas. Probar con 1536 medía una
  # computadora que ya no existe — y encima tardó 14 minutos en llegar al
  # formulario de usuarios, con el procesador clavado, pareciendo colgada.
  "minima|Lo más flaco que aún existe|bios|2048|1|core2duo|ide"
  "moderna|Equipo de hoy, arranque UEFI normal|uefi|4096|4|host|virtio"
  "segura|Equipo comprado hoy, tal como viene de fábrica|segura|4096|4|host|virtio"
  "portatil-viejo|Portátil de 2013, UEFI de primera generación|uefi|3072|2|Nehalem|sata"
)

perfil_campo(){ echo "$1" | cut -d'|' -f"$2"; }

buscar_perfil(){
  for P in "${PERFILES[@]}"; do
    [ "$(perfil_campo "$P" 1)" = "$1" ] && { echo "$P"; return 0; }
  done
  return 1
}

# ── Encontrar la ISO ─────────────────────────────────────────────────
# Siempre la más reciente. Probar una ISO vieja creyendo que es la nueva es
# el error que hace perder una tarde entera.
ultima_iso(){
  ls -1t "$BASE"/isos/*.iso 2>/dev/null | head -1
}

listar(){
  titulo "MÁQUINAS QUE PODEMOS FINGIR"
  for P in "${PERFILES[@]}"; do
    printf "   %s%-16s%s %s\n" "$VE" "$(perfil_campo "$P" 1)" "$V" "$(perfil_campo "$P" 2)"
    printf "                    %sfirmware %s · %s MB · %s hilos · procesador %s · disco %s%s\n" \
      "$GR" "$(perfil_campo "$P" 3)" "$(perfil_campo "$P" 4)" "$(perfil_campo "$P" 5)" \
      "$(perfil_campo "$P" 6)" "$(perfil_campo "$P" 7)" "$V"
  done
  printf "\n"
}

# ── Comprobaciones antes de empezar ──────────────────────────────────
revisar_equipo(){
  local FALTA=0
  command -v qemu-system-x86_64 >/dev/null || { mal "falta qemu-system-x86_64"; FALTA=1; }
  command -v qemu-img          >/dev/null || { mal "falta qemu-img"; FALTA=1; }
  [ -r /dev/kvm ] || { avis "sin /dev/kvm: las pruebas irán muy lentas pero valen"; }
  [ -f "$OVMF/OVMF_CODE_4M.fd" ]    || { mal "falta ovmf — no se puede probar UEFI"; FALTA=1; }
  [ -f "$OVMF/OVMF_CODE_4M.ms.fd" ] || { avis "falta OVMF_CODE_4M.ms.fd — no se puede probar Arranque Seguro"; }
  return $FALTA
}

# ── Correr una prueba ────────────────────────────────────────────────
# ── Arrancar lo que quedó instalado, sin el CD ───────────────────────
#
# La prueba de verdad no es que el instalador termine: es que la máquina
# arranque sola después, sin el pendrive puesto. Eso es lo que hará el
# centro cuando lo desenchufe.
arrancar_instalado(){
  local P="$1"
  local NOMBRE FIRM MEM HILOS CPU DISCO
  NOMBRE=$(perfil_campo "$P" 1); FIRM=$(perfil_campo "$P" 3)
  MEM=$(perfil_campo "$P" 4);    HILOS=$(perfil_campo "$P" 5)
  CPU=$(perfil_campo "$P" 6);    DISCO=$(perfil_campo "$P" 7)

  local DISCO_ARCH="$TRABAJO/$NOMBRE/disco.qcow2"
  [ -f "$DISCO_ARCH" ] || { mal "no hay ningún disco de «$NOMBRE» — primero hay que instalar"; return 1; }

  titulo "ARRANCAR LO INSTALADO EN «$NOMBRE»"
  ok "disco: $(du -h "$DISCO_ARCH" | cut -f1) ocupados"
  nota "Sin CD conectado: si arranca, arranca por sí mismo."
  printf "\n"

  local -a ARG
  ARG=(-name "instalado-$NOMBRE" -m "$MEM" -smp "$HILOS")
  [ -r /dev/kvm ] && ARG+=(-enable-kvm)
  ARG+=(-cpu "$CPU")
  case "$FIRM" in
    bios) ARG+=(-machine pc) ;;
    uefi|segura)
      ARG+=(-machine q35)
      local CODIGO="$OVMF/OVMF_CODE_4M.fd"
      [ "$FIRM" = segura ] && CODIGO="$OVMF/OVMF_CODE_4M.ms.fd"
      # Se reutilizan las variables que dejó la instalación: ahí está
      # apuntado dónde quedó el sistema.
      ARG+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=$CODIGO")
      ARG+=(-drive "if=pflash,format=raw,unit=1,file=$TRABAJO/$NOMBRE/vars.fd")
      ;;
  esac
  case "$DISCO" in
    ide)    ARG+=(-drive "file=$DISCO_ARCH,format=qcow2,if=ide") ;;
    sata)   ARG+=(-device ich9-ahci,id=ahci
                  -drive "file=$DISCO_ARCH,format=qcow2,if=none,id=d0"
                  -device ide-hd,drive=d0,bus=ahci.0) ;;
    virtio) ARG+=(-drive "file=$DISCO_ARCH,format=qcow2,if=virtio") ;;
  esac
  ARG+=(-boot order=c)
  ARG+=(-vga virtio -display gtk,show-cursor=on)
  # 🔴 Una puerta para MIRAR la pantalla sin estar delante.
  #
  # El 18/08/2026 se probó una ISO nueva y hubo que preguntarle a euflo qué
  # veía, describirlo con palabras y creerle. Eso no es comprobar: es
  # suponer con un intermediario. Y él estaba a 100 km de la máquina que
  # importaba, haciendo de ojos.
  #
  # Con esto se le puede pedir a la máquina una foto de su propia pantalla
  # en cualquier momento, desde otra terminal:
  #
  #   scripts/probar-compatibilidad.sh --foto segura
  #
  # No cambia nada de cómo arranca: es una puerta de servicio.
  ARG+=(-qmp "unix:$TRABAJO/$NOMBRE/mando.sock,server=on,wait=off")
  ARG+=(-netdev user,id=n0 -device virtio-net-pci,netdev=n0)

  qemu-system-x86_64 "${ARG[@]}" 2>"$TRABAJO/$NOMBRE/qemu-instalado.log"
}

probar(){
  local P="$1" ISO="$2"
  local NOMBRE DESC FIRM MEM HILOS CPU DISCO
  NOMBRE=$(perfil_campo "$P" 1); DESC=$(perfil_campo "$P" 2)
  FIRM=$(perfil_campo "$P" 3);   MEM=$(perfil_campo "$P" 4)
  HILOS=$(perfil_campo "$P" 5);  CPU=$(perfil_campo "$P" 6)
  DISCO=$(perfil_campo "$P" 7)

  titulo "PROBANDO: $NOMBRE"
  nota "$DESC"
  printf "\n"
  ok "ISO:      $(basename "$ISO")"
  ok "firmware: $FIRM"
  ok "memoria:  $MEM MB   ·   hilos: $HILOS   ·   disco: $DISCO"

  mkdir -p "$TRABAJO/$NOMBRE"
  local DISCO_ARCH="$TRABAJO/$NOMBRE/disco.qcow2"

  # Disco nuevo en cada prueba. Reutilizar uno de ayer mezcla el resultado
  # de dos pruebas y no se sabe cuál falló.
  rm -f "$DISCO_ARCH"
  qemu-img create -f qcow2 "$DISCO_ARCH" 40G >/dev/null 2>&1 \
    || { mal "no se pudo crear el disco de prueba"; return 1; }
  ok "disco de prueba: 40 GB, vacío"

  local -a ARG
  ARG=(-name "prueba-$NOMBRE" -m "$MEM" -smp "$HILOS")
  [ -r /dev/kvm ] && ARG+=(-enable-kvm)

  # «host» copia el procesador real; los demás fingen uno más viejo. Con
  # KVM eso es tapar instrucciones, que es exactamente lo que hace una
  # máquina antigua de verdad.
  ARG+=(-cpu "$CPU")

  case "$FIRM" in
    bios)
      # i440fx es la placa que llevaban las máquinas de esa época.
      ARG+=(-machine pc)
      ;;
    uefi|segura)
      ARG+=(-machine q35)
      local CODIGO VARIABLES
      if [ "$FIRM" = segura ]; then
        CODIGO="$OVMF/OVMF_CODE_4M.ms.fd"; VARIABLES="$OVMF/OVMF_VARS_4M.ms.fd"
      else
        CODIGO="$OVMF/OVMF_CODE_4M.fd";    VARIABLES="$OVMF/OVMF_VARS_4M.fd"
      fi
      [ -f "$CODIGO" ] || { mal "no está $CODIGO"; return 1; }
      # Las variables del firmware se escriben al arrancar: hace falta una
      # copia propia. Si se usara la del sistema, la prueba modificaría el
      # firmware del portátil.
      cp -f "$VARIABLES" "$TRABAJO/$NOMBRE/vars.fd"
      ARG+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=$CODIGO")
      ARG+=(-drive "if=pflash,format=raw,unit=1,file=$TRABAJO/$NOMBRE/vars.fd")
      ;;
  esac

  case "$DISCO" in
    ide)    ARG+=(-drive "file=$DISCO_ARCH,format=qcow2,if=ide") ;;
    sata)   ARG+=(-device ich9-ahci,id=ahci
                  -drive "file=$DISCO_ARCH,format=qcow2,if=none,id=d0"
                  -device ide-hd,drive=d0,bus=ahci.0) ;;
    virtio) ARG+=(-drive "file=$DISCO_ARCH,format=qcow2,if=virtio") ;;
  esac

  if [ "$DESDE_USB" = "1" ]; then
    # El controlador, según la época de la máquina. Una de 2011 no tiene
    # USB 3: ponerle uno sería probar algo que allá no existe.
    case "$FIRM" in
      bios) ARG+=(-device usb-ehci,id=usbctl
                  -drive "file=$ISO,format=raw,readonly=on,if=none,id=pincho"
                  -device usb-storage,bus=usbctl.0,drive=pincho,bootindex=1) ;;
      *)    ARG+=(-device qemu-xhci,id=usbctl
                  -drive "file=$ISO,format=raw,readonly=on,if=none,id=pincho"
                  -device usb-storage,bus=usbctl.0,drive=pincho,bootindex=1) ;;
    esac
  else
    ARG+=(-drive "file=$ISO,format=raw,media=cdrom,readonly=on")
  fi

  # «cd» = primero el disco duro, y si no arranca, el CD.
  #
  # Antes decía «order=d», o sea SIEMPRE el CD. Con el disco vacío daba
  # igual —no había otra cosa de la que arrancar—, pero después de instalar
  # el reinicio volvía al instalador una y otra vez, y parecía que el
  # sistema instalado no arrancaba. Se vio el 2026-08-06 probando «antigua».
  #
  # En una máquina UEFI el fallo no se notaba: su firmware se apunta dónde
  # quedó instalado el sistema y va directo. En una de BIOS antiguo, no.
  #
  # Con «cd» el disco vacío no arranca, cae al CD, y una vez instalado
  # arranca solo — que es justo lo que hay que comprobar.
  # Desde pendrive el orden no se pide por letras: se pide con «bootindex»,
  # que es lo que entiende un arranque por USB. Mezclar los dos hace que
  # SeaBIOS ignore uno de ellos y arranque de donde no toca.
  if [ "$DESDE_USB" = "1" ]; then
    ARG+=(-boot menu=on)
  else
    ARG+=(-boot order=cd,menu=on)
  fi
  ARG+=(-vga virtio -display gtk,show-cursor=on)
  # 🔴 Una puerta para MIRAR la pantalla sin estar delante.
  #
  # El 18/08/2026 se probó una ISO nueva y hubo que preguntarle a euflo qué
  # veía, describirlo con palabras y creerle. Eso no es comprobar: es
  # suponer con un intermediario. Y él estaba a 100 km de la máquina que
  # importaba, haciendo de ojos.
  #
  # Con esto se le puede pedir a la máquina una foto de su propia pantalla
  # en cualquier momento, desde otra terminal:
  #
  #   scripts/probar-compatibilidad.sh --foto segura
  #
  # No cambia nada de cómo arranca: es una puerta de servicio.
  ARG+=(-qmp "unix:$TRABAJO/$NOMBRE/mando.sock,server=on,wait=off")
  ARG+=(-netdev user,id=n0 -device virtio-net-pci,netdev=n0)

  printf "\n"
  avis "Se abre una ventana. Ahí dentro está la máquina fingida."
  nota "   1. Deja que arranque el menú de RedHornoma"
  nota "   2. Entra al escritorio y ejecuta el instalador"
  nota "   3. Instala entero, reinicia, y mira si arranca lo instalado"
  nota "   4. Cierra la ventana cuando termines"
  printf "\n"

  qemu-system-x86_64 "${ARG[@]}" 2>"$TRABAJO/$NOMBRE/qemu.log"
  local SALIDA=$?

  if [ $SALIDA -ne 0 ]; then
    mal "QEMU terminó con error $SALIDA. Lo que dijo:"
    sed 's/^/      /' "$TRABAJO/$NOMBRE/qemu.log" | tail -10
  fi

  # ── Anotar el resultado ────────────────────────────────────────────
  # Lo que no se anota, se olvida. Y una prueba olvidada hay que repetirla.
  printf "\n"
  titulo "¿QUÉ PASÓ EN «$NOMBRE»?"
  printf "   1) Arrancó el menú e instaló entero          %s(todo bien)%s\n" "$VE" "$V"
  printf "   2) Arrancó pero el instalador falló\n"
  printf "   3) Ni siquiera arrancó el menú\n"
  printf "   4) Lo dejo sin anotar\n\n"
  printf "   Elige [1-4]: "
  read -r R
  local VEREDICTO DETALLE=""
  case "$R" in
    1) VEREDICTO="✅ instala" ;;
    2) VEREDICTO="⚠️ arranca, no instala"; printf "   ¿Qué decía el error? "; read -r DETALLE ;;
    3) VEREDICTO="❌ no arranca";           printf "   ¿Qué se veía en pantalla? "; read -r DETALLE ;;
    *) nota "sin anotar"; return 0 ;;
  esac

  mkdir -p "$TRABAJO"
  if [ ! -f "$RESULTADOS" ]; then
    {
      echo "# Dónde se ha probado RedHornoma"
      echo
      echo "Cada línea es una prueba real, no una suposición."
      echo "Generado por \`scripts/probar-compatibilidad.sh\`."
      echo
      echo "| Fecha | Máquina fingida | ISO | Resultado | Detalle |"
      echo "|---|---|---|---|---|"
    } > "$RESULTADOS"
  fi
  printf "| %s | %s | %s | %s | %s |\n" \
    "$(date '+%Y-%m-%d %H:%M')" "$NOMBRE" "$(basename "$ISO")" "$VEREDICTO" "${DETALLE:--}" >> "$RESULTADOS"
  ok "anotado en pruebas/resultados.md"
}

ver_resultados(){
  if [ -f "$RESULTADOS" ]; then
    titulo "RESULTADOS DE TODAS LAS PRUEBAS"
    cat "$RESULTADOS"
  else
    titulo "RESULTADOS"
    nota "Todavía no se ha probado nada."
  fi
}

# ── Principal ────────────────────────────────────────────────────────
# Se mira antes del resto para que «--desde-usb antigua» funcione igual que
# «antigua», sin duplicar todo el manejo de opciones.
if [ "${1:-}" = "--desde-usb" ]; then
  DESDE_USB=1; shift
  [ $# -gt 0 ] || set -- --todas
fi


# ── Una foto de lo que hay ahora mismo en la pantalla ─────────────────
#
# Sirve mientras la prueba está abierta, desde otra terminal. Es la única
# forma de comprobar lo que se VE sin estar delante de la máquina: útil
# cuando quien la tiene delante y quien la revisa no son la misma persona.
foto(){
  local NOMBRE="$1" SOCK DESTINO
  SOCK="$TRABAJO/$NOMBRE/mando.sock"
  [ -S "$SOCK" ] || { mal "«$NOMBRE» no está abierta ahora mismo"
                      nota "primero:  scripts/probar-compatibilidad.sh $NOMBRE"; return 1; }
  DESTINO="${2:-$TRABAJO/$NOMBRE/pantalla-$(date '+%H%M%S').png}"
  python3 - "$SOCK" "$DESTINO" <<'PYFIN'
import socket, json, sys, os, time
sock, destino = sys.argv[1], os.path.abspath(sys.argv[2])
s = socket.socket(socket.AF_UNIX); s.connect(sock); f = s.makefile('rw')
f.readline()                                    # el saludo de qemu
f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush(); f.readline()
f.write(json.dumps({"execute": "screendump",
                    "arguments": {"filename": destino}}) + "\n"); f.flush()
r = json.loads(f.readline())
print("error: " + str(r["error"]) if "error" in r else "")
# El screendump vuelve en cuanto lo acepta, no cuando ha escrito.
for _ in range(40):
    if os.path.exists(destino) and os.path.getsize(destino) > 0: break
    time.sleep(0.25)
PYFIN
  # 🔴 qemu guarda en PPM, un formato de los años ochenta, aunque el
  # archivo se llame «.png». Ningún visor moderno lo abre, y el error que
  # da es «no es una imagen válida», que despista mucho. Se convierte aquí.
  if [ -s "$DESTINO" ] && head -c2 "$DESTINO" | grep -q '^P6' \
     && command -v convert >/dev/null 2>&1; then
    convert "$DESTINO" png:"$DESTINO.tmp" 2>/dev/null && mv -f "$DESTINO.tmp" "$DESTINO"
  fi
  if [ -s "$DESTINO" ]; then
    ok "foto: $DESTINO"
    command -v identify >/dev/null 2>&1 && nota "$(identify -format '%wx%h  %m' "$DESTINO")"
  else
    mal "no salió la foto"
  fi
}

case "${1:---lista}" in
  --lista|-l)   listar; exit 0 ;;
  --resultados) ver_resultados; exit 0 ;;
  --foto)
    [ -n "${2:-}" ] || { mal "di de cuál: --foto segura"; exit 1; }
    foto "$2" "${3:-}"; exit $? ;;
  -h|--help)    sed -n '2,26p' "$0" | sed 's/^# \?//'; exit 0 ;;
  --instalado)
    revisar_equipo || exit 1
    P=$(buscar_perfil "${2:-}") || { mal "di cuál: --instalado antigua"; listar; exit 1; }
    arrancar_instalado "$P"; exit $? ;;
esac

revisar_equipo || exit 1

ISO=$(ultima_iso)
[ -n "$ISO" ] || { mal "no hay ninguna ISO en $BASE/isos/"; exit 1; }

if [ "$1" = "--todas" ]; then
  titulo "TODAS LAS MÁQUINAS, UNA DETRÁS DE OTRA"
  nota "Son ${#PERFILES[@]} pruebas. Cierra cada ventana para pasar a la siguiente."
  for P in "${PERFILES[@]}"; do probar "$P" "$ISO"; done
  ver_resultados
  exit 0
fi

P=$(buscar_perfil "$1") || { mal "no sé fingir «$1»"; listar; exit 1; }
probar "$P" "$ISO"
