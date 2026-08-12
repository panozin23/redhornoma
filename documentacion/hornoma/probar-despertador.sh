#!/bin/bash
# probar-despertador.sh — ¿Sabe esta máquina encenderse sola?
#
# Antes de confiarle a un servidor que se apague por la noche y vuelva solo,
# hay que comprobar que de verdad vuelve. Muchas placas traen esa opción
# apagada de fábrica: se programa la alarma, la máquina se apaga, y no
# despierta. Si eso pasa con nadie delante, el centro se queda sin servidor
# hasta que alguien viaje.
#
# Esto lo prueba en pequeño: apaga la máquina con una alarma a los minutos
# que se le digan, para verlo volver mientras hay alguien cerca.
#
# Uso:  sudo bash probar-despertador.sh [minutos]     (por defecto 4)
set -u

MINUTOS="${1:-4}"
[ "$(id -u)" = "0" ] || { echo "Hace falta administrador:  sudo bash $0"; exit 1; }

ALARMA=/sys/class/rtc/rtc0/wakealarm
[ -e "$ALARMA" ] || { echo "Esta máquina no tiene reloj-despertador"; exit 1; }

echo "═══════════════════════════════════════════════════"
echo " PRUEBA DEL DESPERTADOR"
echo "═══════════════════════════════════════════════════"
echo "   ahora son las      : $(date '+%H:%M:%S')"

# El reloj de la placa va en hora universal (comprobado con timedatectl), así
# que los segundos de «date» valen tal cual. Si fuera en hora local habría que
# corregir el desfase, y saldría una alarma con horas de diferencia.
CUANDO=$(date -d "+$MINUTOS minutes" +%s)
echo 0 > "$ALARMA"          # limpiar cualquier alarma anterior
echo "$CUANDO" > "$ALARMA"

PUESTA=$(cat "$ALARMA")
if [ "$PUESTA" = "$CUANDO" ]; then
  echo "   debería encenderse : $(date -d "@$CUANDO" '+%H:%M:%S')"
else
  echo "   ⚠️  la alarma no quedó puesta (la placa la rechazó)"
  echo "   NO se apaga: sin despertador esto sería quedarse sin servidor"
  exit 1
fi

# El Windows de dentro se apaga primero y con orden. Dejar que se corte de
# golpe es pedir una base de datos rota.
if command -v virsh >/dev/null 2>&1; then
  for vm in $(LC_ALL=C virsh -c qemu:///system list --name 2>/dev/null | grep -v '^$'); do
    echo "   apagando con orden : $vm"
    LC_ALL=C virsh -c qemu:///system shutdown "$vm" >/dev/null 2>&1
  done
  # Esperar a que se apague de verdad, hasta dos minutos.
  for _ in $(seq 1 24); do
    [ -z "$(LC_ALL=C virsh -c qemu:///system list --name 2>/dev/null | grep -v '^$')" ] && break
    sleep 5
  done
fi

echo
echo "   Apagando. Si la placa obedece, volverá sola en $MINUTOS minutos."
echo "   Si a los 10 minutos no ha vuelto, hay que encenderla a mano."
echo
sleep 3
poweroff
