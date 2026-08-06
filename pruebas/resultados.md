# Dónde se ha probado RedHornoma

Cada línea es una prueba real, no una suposición.
Generado por `scripts/probar-compatibilidad.sh`.

| Fecha | Máquina fingida | ISO | Resultado | Detalle |
|---|---|---|---|---|
| 2026-08-06 06:50 | antigua | redhornoma-0.1-20260806-amd64.iso | ✅ instala y arranca | BIOS antiguo, 2 GB, core2duo, disco IDE. Instaló, y lo instalado arrancó solo sin el CD puesto. |
| 2026-08-06 06:31 | segura | redhornoma-0.1-20260806-amd64.iso | ✅ instala | Arranque Seguro activado. Instaló y arrancó lo instalado, **sin ningún aviso**. Disco 8,4 GB. |
