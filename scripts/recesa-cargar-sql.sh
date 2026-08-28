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

docker run -d --name soaps-sql \
    -e ACCEPT_EULA=Y -e MSSQL_PID=Express \
    -p 1433:1433 -v /var/lib/soaps-sql:/var/opt/mssql \
    --restart unless-stopped mcr.microsoft.com/mssql/server:2017-latest
