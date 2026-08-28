#!/bin/bash
export WINE=/opt/wine-staging/bin/wine WINEPREFIX="${WINEPREFIX:-$HOME/.wine-ministerio}" WINEARCH=win32 WINEDEBUG=-all
[ -x /opt/wine-staging/bin/wine ] || WINE=wine
cd "$WINEPREFIX/drive_c/SNIS2026" 2>/dev/null
exec $WINE snis_2026.exe
