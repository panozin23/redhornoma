#!/bin/bash
export WINE=/opt/wine-staging/bin/wine WINEPREFIX="${WINEPREFIX:-$HOME/.wine-ministerio}" WINEARCH=win32 WINEDEBUG=-all
[ -x /opt/wine-staging/bin/wine ] || WINE=wine
cd "$HOME/pruebas/SALMI-para-wine" 2>/dev/null || cd "$WINEPREFIX/drive_c/SALMI" 2>/dev/null
exec $WINE SalmiDis.exe
