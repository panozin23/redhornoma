# flora — Bitácora del 28/08/2026

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

## 🔴 Auditoría del 28/08 — lo que falta, sin tocar todavía

1. **No hay respaldo automático de la base de datos.** Último `.bak` real:
   22/08. Los pacientes metidos hoy (Encarna, Francisco) NO están
   respaldados en ningún lado — si el disco falla ahora, se pierden. Es la
   misma lección que ya costó cara una vez (objetivo S3 / "🥇 la pieza más
   importante del proyecto", ver `respaldo automático y recuperación
   probada` en `PLAN.md`).
2. **No hay "vigía"** (el aviso automático si un centro deja de responder) —
   no se portó todavía a la versión sin Windows/virtualización.
3. Office sigue en 2013 — cambio a 2010 pendiente del instalador de euflo.
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
