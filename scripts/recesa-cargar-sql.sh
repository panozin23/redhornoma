#!/bin/bash
# RECESA: carga la imagen de SQL Server desde disco (sin internet) y arranca
# soaps-sql si el contenedor no existe todavia. Idempotente.
set -e

if docker inspect soaps-sql >/dev/null 2>&1; then
    exit 0
fi

IMAGEN=/opt/recesa/soaps-sql-image.tar.gz
if [ -f "$IMAGEN" ]; then
    gunzip -c "$IMAGEN" | docker load
fi

docker run -d --name soaps-sql --hostname FLORACBA \
    -e ACCEPT_EULA=Y -e MSSQL_PID=Express \
    -p 14330:1433 -v /var/lib/soaps-sql:/var/opt/mssql \
    --restart unless-stopped mcr.microsoft.com/mssql/server:2017-latest
# Nota (28/08/2026): el motor va en el 14330, no en el 1433 estandar,
# porque el proxy-tds.py ahora ocupa el 1433 (asi SOAPS ve
# SERVIDOR="127.0.0.1" sin puerto). --hostname FLORACBA para que coincida
# con el nombre de la PC (no soluciono la restriccion de "restaurar copia
# de seguridad" de SOAPS, pero es mas prolijo). Si @@SERVERNAME no
# coincide con FLORACBA despues de crear el contenedor, correr dentro de
# el: sqlcmd ... -Q "EXEC sp_dropserver '<nombre-viejo>'; EXEC sp_addserver 'FLORACBA', local;"
# y reiniciar el contenedor.
