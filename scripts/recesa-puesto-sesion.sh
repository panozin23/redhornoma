#!/bin/bash
# RECESA: arranca una sesion de consultorio independiente (Xvnc + icewm).
# Uso: recesa-puesto-sesion.sh <numero 1-4>
set -e
N="$1"
[ -z "$N" ] && { echo "falta el numero de consultorio (1-4)"; exit 1; }

export HOME=/home/euflo
export USER=euflo
export DISPLAY=":$N"
export WINEPREFIX=/home/euflo/.wine-consultorio-$N

rm -f "/tmp/.X$N-lock" "/tmp/.X11-unix/X$N" 2>/dev/null || true

Xvnc ":$N" -rfbauth /home/euflo/.vnc/passwd -geometry 1280x1024 -depth 24 \
    -desktop "RECESA - Consultorio $N" -SecurityTypes VncAuth -localhost=no &
XPID=$!

for i in $(seq 1 40); do
    xdpyinfo -display ":$N" >/dev/null 2>&1 && break
    sleep 0.5
done

icewm-session &
ICEPID=$!

wait $XPID
kill $ICEPID 2>/dev/null || true
