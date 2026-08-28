#!/bin/bash
export WINE=/opt/wine-staging/bin/wine WINEPREFIX="$HOME/.wine-ministerio" WINEARCH=win32 WINEDEBUG=-all
[ -x /opt/wine-staging/bin/wine ] || WINE=wine
# Red de seguridad: si el motor de datos no estuviera arriba, lo despertamos.
docker start soaps-sql >/dev/null 2>&1
cd "$WINEPREFIX/drive_c/SOAPS7" 2>/dev/null
exec $WINE SOAPS_7.exe
