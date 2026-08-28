#!/bin/bash
# RECESA: el login "sa" (el que usa SOAPS) trae por defecto el idioma
# us_english, que interpreta las fechas como MM/DD/AAAA. Como SOAPS/Wine
# mandan las fechas en formato boliviano DD/MM/AAAA, cualquier dia > 12
# rompe con "Error converting data type char to datetime".
# Se corrige poniendo el login en un idioma que use DD/MM/AAAA (British).
# Descubierto y arreglado el 28/08/2026 en flora.
set -e
docker exec soaps-sql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$1" \
    -Q "ALTER LOGIN sa WITH DEFAULT_LANGUAGE = British;"
echo "Listo. Hay que cerrar y volver a abrir SOAPS para que tome el cambio."
