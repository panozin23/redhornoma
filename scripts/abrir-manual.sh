#!/bin/bash
# Abre el manual «Encender y apagar».
#
# POR QUÉ NO SE ABRE LA PÁGINA DIRECTAMENTE
#
# El manual se escribe en ENCENDER-Y-APAGAR.md y se convierte a una página
# para leerlo cómodo. Si el acceso directo abriera la página a secas, el
# día que se mejore el manual y nadie se acuerde de convertirlo, euflo
# estaría leyendo una versión vieja sin saberlo — y creyéndosela.
#
# Aquí se mira si el manual es más nuevo que la página. Si lo es, se
# rehace antes de abrir. Así no pueden separarse.
set -u
BASE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
MD="$BASE/documentacion/ENCENDER-Y-APAGAR.md"
HTML="$BASE/documentacion/ENCENDER-Y-APAGAR.html"

[ -f "$MD" ] || { echo "No encuentro el manual: $MD"; exit 1; }

if [ ! -f "$HTML" ] || [ "$MD" -nt "$HTML" ]; then
  python3 "$BASE/scripts/manual-a-pagina.py" "$MD" "$HTML" >/dev/null 2>&1 \
    || { echo "No se pudo rehacer la página; se abre el texto"; xdg-open "$MD"; exit 0; }
fi

xdg-open "$HTML"
