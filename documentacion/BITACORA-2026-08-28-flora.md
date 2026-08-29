# flora — Bitácora del 28/08/2026

## ⏸️ PAUSA — CONTINUAR DESDE ACÁ

**Lo último pendiente, sin resolver:** restaurar el respaldo `E300183SOAPS0401201913092064m.wak`
(27/08, en `/media/portatil/CURSAKIALINUX/22ULTIMO-B-SALMO-SOAPSAGOST/actualizado/`)
en BDEstadistica. **57 de 58 tablas SÍ se restauraron bien.** Las dos más
importantes — **SE_DATOS** (consultas) y **SE_HC** (historias clínicas) —
**NO entraron**: error de formato (no es solo el año 2064 conocido; hay
"String data, right truncation" en cascada, como si el `.wak` viniera de
otra versión/estructura de SOAPS). Se intentó 2 veces (con y sin tolerancia
a errores) y terminó en 0 filas las dos veces. **Se devolvieron ambas
tablas al estado de "antes de hoy"** (no se perdió nada, pero tampoco se
ganaron los datos del 27/08 de esas dos tablas).

**Qué queda listo para retomar sin repetir trabajo:**
- Los 58 archivos `.dat` (formato nativo bcp) ya están extraídos en el
  servidor: `/var/lib/soaps-sql/restore-tmp/` (visible desde el contenedor
  como `/var/opt/mssql/restore-tmp/`).
- Hay una base de referencia con el estado de "antes de tocar nada":
  **`BDEstadistica_ANTES`** (restaurada de
  `/var/opt/mssql/backup/BDEstadistica-antes-de-restaurar.bak` dentro del
  contenedor `soaps-sql`). NO BORRAR hasta terminar de investigar.
- Los archivos de error de bcp quedaron en
  `/var/opt/mssql/restore-tmp/errores_se_datos.txt` (1802 líneas) y
  `errores_se_hc.txt` (2 líneas) — ahí está el detalle fila por fila de
  qué falló.
- **Próximo paso sugerido:** comparar la estructura de columnas
  (`sp_help SE_DATOS` / `sp_help SE_HC`) entre lo que el `.dat` espera y
  lo que la tabla actual tiene, para encontrar el desajuste exacto (¿una
  columna de más/menos, un varchar más corto, un tipo de fecha distinto?).

**Otras cosas resueltas en el camino, sirven para cualquier centro:**
- La restricción de SOAPS "la copia de seguridad debe realizarse en el
  equipo servidor" (al querer usar F2-Restaurar desde el propio SOAPS)
  **sigue sin resolverse** — se probaron dos teorías (nombre del
  contenedor Docker, formato de la cadena de conexión) y ninguna era la
  causa. Quedó igual, pero de paso se dejaron dos mejoras reales:
  - El contenedor `soaps-sql` ahora se llama `FLORACBA` (antes tenía el
    ID random de Docker) — más prolijo, y correcto para cuando haya que
    identificarlo.
  - El proxy TDS ahora escucha en el puerto 1433 (el estándar), y el
    motor real quedó en el 14330 — antes era al revés. Registro de SOAPS
    actualizado (`SERVIDOR="127.0.0.1"`, sin el puerto). **Si se vuelve a
    clonar flora, revisar que `scripts/proxy-tds.py` en el repo tenga
    estos puertos actualizados** (el que está en GitHub todavía dice
    1435/1433 — falta subir esta versión).
- El teclado (Shift trabado) resultó ser, la última vez, **Caps Lock
  físicamente prendido en el servidor** (no un bug de VNC). Se apagó con
  `xdotool key Caps_Lock`, y `x11vnc` quedó con `-clear_all` (limpia
  también Bloq Mayús al arrancar, no solo Shift).

---

**Contexto de partida:** corte de luz en Cochabamba dejó SOAPS sin abrir en

**Contexto de partida:** corte de luz en Cochabamba dejó SOAPS sin abrir en
flora (el ícono aparecía y se cerraba solo). Al investigar se descubrió que
el disco de este portátil (euflo) había tenido fallas y se perdieron varios
archivos sueltos — tanto en flora como en el clon que se había llevado a
Hornoma (ese clon, además, no tenía ni Docker ni el motor SQL, por eso
tampoco funcionaba allá).

Se recuperó `/home/euflo` completo desde el disco del portátil (la cuenta se
había borrado, pero los archivos seguían físicamente ahí) y se respaldó todo
el repo `redhornoma` en GitHub, con este cierre de jornada incluido.

---

## 🔴 Causa raíz de fondo (para no repetir)

Varias piezas clave vivían como **archivos sueltos en `$HOME`**, fuera del
sistema de paquetes/receta del proyecto — por eso no sobrevivían a un clon
ni a una falla de disco:

- `proxy-tds.py` (el intermediario TDS)
- `abrir-soaps.sh` (el lanzador)
- La imagen Docker del motor SQL (penguins-eggs excluye `/var/lib/docker`
  al clonar)

Todo esto ya quedó en el repo (`scripts/`), pero **falta empaquetarlo
formalmente** (`.deb`) para que sobreviva cualquier reconstrucción futura —
ver la sección "Pendiente" más abajo.

---

## ✅ Lo arreglado hoy

1. **`proxy-tds.py` recuperado y corregido.** Se encontró una versión "v3"
   sin commitear en el repo que modifica el PRE-LOGIN de AMBOS lados
   (cliente y motor) — **es la versión que NO funciona** (produce "General
   network error", documentado en `hornoma-instalado-desde-iso.md`). Se
   restauró la versión correcta (solo modifica el lado del cliente) como
   `scripts/proxy-tds.py`, y la mala quedó renombrada
   `proxy-tds-v3-NO-USAR-bidireccional.py` para que no se vuelva a usar por
   error.

2. **`abrir-soaps.sh` recuperado** desde el clon de Hornoma (que sí lo
   tenía) y desplegado en flora.

3. **Mecanismo de SQL sin internet, nuevo:**
   `scripts/recesa-cargar-sql.sh` + `recesa-cargar-sql.service` — en el
   primer arranque de una máquina nueva, carga la imagen Docker guardada en
   `/opt/recesa/soaps-sql-image.tar.gz` (411 MB) y recrea el contenedor
   `soaps-sql` apuntando a `/var/lib/soaps-sql`. Idempotente: si el
   contenedor ya existe, no hace nada. Instalado, habilitado y probado en
   flora.

4. **Acceso remoto (VNC) reparado:**
   - `x11vnc` (pantalla física, puerto 5900) tenía el Shift "trabado" de
     una sesión anterior — se solucionó reiniciando con `-clear_mods` (ya
     agregado a `~/.local/bin/iniciar-vnc.sh` para que no vuelva a pasar).
   - Lo que parecía un bug de Wayland en el cliente (Remmina) resultó ser
     **Bloq Mayús físicamente encendido** en las laptops — false alarm,
     pero de paso se dejaron las laptops en sesión X11 (más estable que
     Wayland para VNC de todas formas).
   - RDP (krdp) **no sirve** en este servidor: falta configurar su base de
     credenciales (SAM) y depende del portal de escritorio remoto. Usar
     siempre VNC.

5. **🥇 Sesión independiente por consultorio (lo más grande de hoy).**
   Hasta hoy, todos los que se conectaban por VNC veían la MISMA pantalla
   compartida (x11vnc sobre `:0`) — si dos personas abrían SOAPS a la vez,
   se pisaban. Se armó:
   - `scripts/recesa-puesto-sesion.sh` + `recesa-puesto@.service`
     (plantilla systemd): arranca una sesión Xvnc + icewm independiente por
     número de consultorio (`:1`→5901, `:2`→5902, `:3`→5903, `:4`→5904).
   - **Cada consultorio tiene su PROPIA copia del prefijo de Wine**
     (`/home/euflo/.wine-consultorio-N`, 4,3 GB cada una). Esto fue
     necesario porque Wine solo permite una instancia de una app por
     prefijo (vía wineserver), sin importar en qué pantalla corra —
     compartir el prefijo entre sesiones hacía que abrir SOAPS en un
     consultorio cerrara el SOAPS del otro.
   - Los scripts `abrir-*.sh` (`scripts/abrir-soaps.sh`, `abrir-snis.sh`,
     `abrir-salmi.sh`, `abrir-excel.sh`, `abrir-word.sh`,
     `abrir-powerpoint.sh`) ahora respetan un `WINEPREFIX` ya exportado en
     vez de forzar siempre `~/.wine-ministerio`.
   - Cada sesión muestra los **mismos íconos del escritorio** (SOAPS, SNIS,
     SALMI, Office) vía `pcmanfm --desktop`, en vez de un menú escondido —
     se probó primero con clic derecho + `yad` y no era suficientemente
     simple para el usuario final (auxiliar de enfermería, acostumbrado a
     Windows).
   - **Probado con dos sesiones reales a la vez** (esta laptop = consultorio
     1, "rosi" = consultorio 2): cada una metió un paciente distinto
     (Encarna / Francisco) sin interferencias. Las 4 sesiones (1-4) quedaron
     activas y habilitadas.

6. **Error de fecha en SOAPS resuelto.** "Error converting data type char to
   datetime" al guardar una consulta. Causa: el login `sa` de SQL Server
   (el que usa SOAPS) traía el idioma `us_english` (fechas MM/DD/AAAA), pero
   SOAPS/Wine mandan las fechas en formato boliviano DD/MM/AAAA — cualquier
   día >12 rompía. Arreglo aplicado y documentado en
   `scripts/arreglar-idioma-fechas-sql.sh`:
   `ALTER LOGIN sa WITH DEFAULT_LANGUAGE = British;` (British usa DD/MM/AAAA).

7. **Pantalla que no se ajustaba a monitores chicos** (SNIS necesita
   1280×1024 por dentro, si no el botón Guardar desaparece). Solución:
   NO cambiar la resolución real de la sesión — usar el modo "ajustar a la
   ventana" / escalado de Remmina (ícono en su barra de herramientas), que
   escala la imagen sin tocar la resolución interna. Confirmado que se
   guarda solo entre reconexiones.

8. **Acceso a Rosi armado.** Rosi no tenía `remmina` instalado (versión más
   vieja de RedHornoma) — se instaló y se armaron los accesos a la pantalla
   física y al Consultorio 2.

9. **Epson L380 en red.** Se conectó la impresora física a flora. El driver
   propietario y las dos correcciones de Debian mínimo (`libcupsimage2t64`,
   blacklist de `usblp`) ya estaban puestos de una sesión anterior — solo
   faltó compartirla: `sudo /usr/sbin/cupsctl --share-printers --remote-any`
   + `sudo lpadmin -p L380-Series -o printer-is-shared=true` (ojo: `cupsctl`
   vive en `/usr/sbin`, no está en el PATH de un usuario normal). Probada
   de punta a punta: impresión física directa en flora, y **desde esta
   laptop por la red** (`lp -h 192.168.0.110:631 -d L380-Series ...`), las
   dos veces salió la hoja. Como el servidor la anuncia por Avahi con
   soporte IPP Everywhere (URF/PWG-raster, "mopria-certified"), **los
   puestos cliente no necesitan instalar el driver de Epson** — la ven y
   usan directo, incluso desde Windows.

---

10. **Office cambiado de 2013 a 2007 (S5, resuelto de nuevo tras el giro).**
    Se quiso instalar Office 2010 primero (el usuario tenía un instalador),
    pero resultó ser un `.rar` de un sitio de descargas con un
    "Activador" (KMSpico) adentro — **se borró sin usar**, riesgo real de
    virus para el servidor de un centro de salud. Se bajó una copia limpia
    y oficial de Office 2010 en español desde archive.org
    (`office-2010-proplus-rtm-spanish`, instaladores x86/x64 oficiales), pero
    el instalador **exige clave para instalación silenciosa o básica**, y
    con la clave genérica de KMS (`6QFDX-PYH2G-PPYFD-C7RJM-BBKQ8`, la
    publicada por Microsoft para medios VL) el instalador copiaba TODO
    bien pero se revertía entero al final (error 1603) — no se pudo
    resolver. Además se confirmó que **los servidores de activación de
    Office 2010 están apagados desde 2020**, así que ni comprando una
    clave real se podría activar por el metodo normal. **Se descartó
    Office 2010.** Also descartado 2019/2021: son Click-to-Run, no
    instalan bien en Wine (ya probado y descartado antes en el proyecto).

    **Se volvió a Office 2007** (el mismo que ya se sabía que funciona en
    hardware viejo, `office2007.iso` en el Toshiba). Antes de instalarlo se
    desinstaló Office 2010 a medias y se limpiaron sus vestigios del
    registro (misma técnica de bloques). Al instalar Office 2007 con la
    clave del propio ISO (`VB48G-H6VK9-WJ93D-9R6RM-VP7GT`), **Excel se
    quedaba trabado en la pantalla de bienvenida** (confirmado con `gdb`:
    los 5 hilos bloqueados en el mismo punto) — resultó ser solo que el
    cartel de bienvenida no se cerraba solo; haciendo clic sobre él, Excel
    ya estaba cargado y andando atrás. **Quedó activado** (Excel dice
    "este producto ya se activó"). Se actualizaron `abrir-excel`,
    `abrir-word`, `abrir-powerpoint` de `Office15` a `Office12`.
    **Probado con SNIS: genera el 301 con datos reales (julio) en Excel
    2007.** ⚠️ NO intentar "actualizar" Office 2007 por internet — sus
    servidores de actualización también están apagados; cualquier sitio
    que aparezca ahí es sospechoso.

11. **El Shift de x11vnc se trabó DOS VECES más durante la jornada**, después
    de reinicios de wineserver y mucha actividad. Cada vez se resolvió
    reiniciando x11vnc (ya tiene `-clear_mods`, ver punto 4). **Queda como
    algo a vigilar**: si vuelve a pasar seguido, revisar si hay una causa de
    fondo en vez de seguir reiniciando a mano.

## 🔴 Auditoría del 28/08 — lo que falta, sin tocar todavía

1. **No hay respaldo automático de la base de datos.** Último `.bak` real:
   22/08. Los pacientes metidos hoy (Encarna, Francisco) NO están
   respaldados en ningún lado — si el disco falla ahora, se pierden. Es la
   misma lección que ya costó cara una vez (objetivo S3 / "🥇 la pieza más
   importante del proyecto", ver `respaldo automático y recuperación
   probada` en `PLAN.md`).
2. **No hay "vigía"** (el aviso automático si un centro deja de responder) —
   no se portó todavía a la versión sin Windows/virtualización.
3. ✅ Office: RESUELTO más tarde en la jornada — se cambió a 2007, activado, ver punto 10 de arriba.
4. ✅ Impresora Epson: RESUELTO más tarde en la jornada, ver punto 9 de arriba.
5. El disco de flora está SANO (`smartctl -H`: PASSED) — el problema de la
   PC del portátil no fue el disco.

## Pendiente para terminar el ISO 0.0.2 (para llevar a Hornoma el lunes)

- Empaquetar `proxy-tds.py`, `abrir-soaps.sh` y el mecanismo de SQL offline
  como paquete `.deb` (no solo archivos sueltos en `$HOME`), para que
  sobrevivan de verdad a cualquier clon futuro.
- Armar el respaldo automático (punto 1 de arriba) ANTES de generar el ISO.
- `sudo eggs produce --clone` y comprobar el tamaño (ver
  `Escritorio/PASOS-CREAR-ISO.txt`: si sale en MB en vez de GB, es el bug de
  la versión nueva de penguins-eggs, avisar).
- Decidir Office 2010 vs 2007 cuando llegue el instalador.

## Máquinas usadas hoy

```
flora / floracba   192.168.0.110   Cochabamba, servidor secundario/apoyo
rosi                192.168.0.107   laptop, RedHornoma más vieja (sin remmina, ya instalado)
portátil            (este equipo)   administración de euflo
```
