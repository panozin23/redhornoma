#!/bin/bash
export WINE=/opt/wine-staging/bin/wine WINEPREFIX="${WINEPREFIX:-$HOME/.wine-ministerio}" WINEARCH=win32 WINEDEBUG=-all
export WINEDLLOVERRIDES="winedbg.exe=d"
exec "$WINE" "$WINEPREFIX/drive_c/Program Files/Microsoft Office/Office15/POWERPNT.EXE" "$@"
