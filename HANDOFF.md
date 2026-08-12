# TRASPASO — RedHornoma

> **Para quien llegue nuevo a este proyecto**, sea una persona o una sesión de
> Claude que empieza de cero. Léelo entero antes de tocar nada: está para que
> no se repitan errores que ya costaron horas.
>
> **Última actualización:** 2026-08-11 (noche)
> **Se actualiza al cerrar cada jornada.** Un traspaso viejo engaña más que
> ninguno.

---

## 1 · Objetivo

Un sistema operativo para las computadoras de un centro de salud en Bolivia,
que haga funcionar los programas del Ministerio —**SALMI**, **SOAPS**,
**SNIS**— en red interna, con respaldo automático, sobre hardware viejo, y
manejable **sin escribir comandos**.

Lo lleva **euflo**, del CS Hornoma (Capinota, Cochabamba). No es informático de
formación: las explicaciones van en español llano, y **cada comando se entrega
diciendo en qué máquina se ejecuta**.

Los **once** objetivos, en sus palabras:

1. Que funcione en cualquier máquina, antigua o moderna
2. Meter información desde cualquier máquina de la red interna
3. Un servidor con SALMI, SOAPS, SNIS (y más adelante SIAL y los de segundo nivel)
4. Virtualización: Linux con Windows dentro
5. Canal de comunicación entre Windows y Linux
6. Sin código: todo gráfico, de jalar y soltar
7. Distro en español
8. **Que la información no se pierda nunca**
9. **Que un centro pueda arreglarse solo**
10. **Que la distro se pueda rehacer desde cero**
11. **Que se puedan atender varios centros desde un solo sitio**

**Los tres últimos se añadieron el 2026-08-08**, repasando el marcador. El 8
porque ese día se descubrió que **SOAPS llevaba cinco semanas sin respaldo y
nadie lo sabía**, y eso no cabía en ninguno de los siete: el 3 habla de *tener*
los programas, no de proteger lo que guardan. El 9 y el 10 porque hoy todo
depende de que euflo esté disponible, y porque la distro no se sabe reconstruir
igual.

---

## 2 · Estado actual

| # | Objetivo | | Lo que falta, en una línea |
|---|---|---|---|
| 2 | Meter información en red | 🟢 100% | — |
| 4 | Virtualización | 🟢 95% | La llave de BitLocker al aire |
| 5 | Canal Windows ↔ Linux | 🟢 98% | Que el panel diga si la carpeta está en marcha |
| 1 | Compatibilidad | 🟢 95% | **Los 5 perfiles pasados.** Falta hierro de verdad |
| 7 | Distro en español | 🟢 95% | Falta comprobar que lo instalado queda en `es_BO` |
| 6 | Todo gráfico | 🟡 88% | 7 de 18 con ventana; hoy hubo que usar la terminal |
| 3 | Servidor con los programas | 🟡 88% | **SOAPS 7 vivo en Hornoma (10/08).** Falta SALMI, SNIS y la red |
| 8 | Que la información no se pierda | 🟡 85% | **Hornoma estuvo 7 días sin respaldo y nadie se enteró** |
| 9 | Que un centro se arregle solo | 🟡 55% | **«Algo no funciona» ya arregla 6 averías.** Falta probarlo en un centro |
| 10 | Que la distro se rehaga desde cero | 🔴 15% | 155 paquetes declarados, **2.307 acaban dentro** |
| 11 | Atender varios centros desde un sitio | 🔴 20% | Existen las piezas; **falta la pantalla que las junte**. Plan en `documentacion/PANTALLA-DE-LOS-CENTROS.md` |

**El objetivo 2 está cerrado (08/08):** los tres programas del Ministerio
probados con **dos puestos escribiendo a la vez** — SALMI el 04/08, SNIS el
07/08 y SOAPS el 08/08. En los tres se comprobó por dentro, no por la pantalla.

⚠️ **EL MARCADOR DE ARRIBA MIDE EL PROYECTO, NO UN CENTRO.** Se vio el 10/08 en
Hornoma: el objetivo 2 figura al 100% y **en Hornoma está en CERO**, porque el
Windows del servidor está detrás de un NAT y ningún puesto puede llegar a él.

**Un objetivo solo está conseguido cuando se cumple en TODOS los centros.**

| # | Objetivo | Cochabamba | **Hornoma (10/08)** |
|---|---|---|---|
| 1 | Compatibilidad | 🟢 95% | 🟢 100% |
| 4 | Virtualización | 🟢 95% | 🟢 95% |
| 7 | Distro en español | 🟢 95% | 🟢 95% |
| 5 | Canal Windows ↔ Linux | 🟢 98% | 🟡 70% |
| 3 | Servidor con los programas | 🟢 100% | 🟡 35% |
| 8 | Que la información no se pierda | 🟢 90% | 🔴 30% |
| 2 | Meter información desde la red | 🟢 100% | 🔴 **0%** |
| 9 | Que un centro se arregle solo | 🟡 55% | 🔴 10% |

**El orden para replicar Cochabamba en Hornoma**, y el primero desbloquea a los
demás:

```
1 · Sacar el Windows del NAT a la red del centro     ← bloquea al 2 y al 3
2 · Excel (bloquea el cierre de mes), SALMI, SNIS
3 · El respaldo: actualizar el .101, reapuntar, PROBAR RESTAURAR
4 · Los puestos: el .103 de cliente, dos escribiendo a la vez
```

**Publicado y funcionando:**

```
ISO        redhornoma-0.1-20260809-amd64.iso   2,7 GB
           30d9869fe820c37188dbae8c2d5add6cdf90c327fb1668978a8348ec1d5f8b61
           tercera del día. 58b22a13… tenía el menú roto; fcac8d1c… la
           ventana de bienvenida de KDE y sin os-prober
paquetes   base 1.0.1 · completo 1.0.32 · panel 1.0.8 · perifericos 1.0.10
           red 1.0.6 · respaldo 1.0.17 · virtualizacion 1.0.15
19 herramientas, 8 con ventana propia
```

**Cómo se comprueba qué lleva una ISO de verdad** — y no por lo que diga el
guion que la hizo. Se hizo así el 08/08, dos veces:

```
# los paquetes instalados dentro
bsdtar -xOf ISO live/filesystem.packages | grep redhornoma

# y para mirar ARCHIVOS concretos, hay que abrir el sistema comprimido
bsdtar -xOf ISO live/filesystem.squashfs > fs.squashfs      # ~2,5 GB
unsquashfs -l fs.squashfs | grep skel/Escritorio
unsquashfs -d sq -q fs.squashfs "etc/skel/Escritorio/*"
```

*(Los `.deb` **no** aparecen sueltos en la ISO: live-build los instala dentro
del sistema. Buscarlos ahí no prueba nada.)*

Así se comprobó que el icono del instalador **está, y es ejecutable** —si no lo
fuera, KDE lo trataría como archivo sospechoso y no arrancaría— y que el
programa al que llama existe dentro.

✅ **La del 08/08 sí se probó de verdad:** `daf365…` en el perfil `centro` y
`4f034f…` en `moderna` y `portatil-viejo`. Las tres instalaron y **arrancaron de
lo instalado**. Ver `pruebas/resultados.md`.

✅ **El icono de más ya no está.** Se comprobó abriendo el sistema comprimido
de la ISO del 09/08: en `etc/skel/Escritorio` solo queda `ANTES-DE-INSTALAR.txt`.
Y dentro van las herramientas del día, **con permiso de ejecución**:

```
-rwxr-xr-x  usr/bin/redhornoma-arreglar
-rwxr-xr-x  usr/bin/redhornoma-panel
-rwxr-xr-x  usr/lib/redhornoma/arreglos
```

⚠️ **Esta ISO no se ha instalado todavía en ninguna parte.** Está construida y
mirada por dentro, no probada. Los cinco perfiles hay que volver a pasarlos.

✅ **Arranca desde PENDRIVE hasta el escritorio, en BIOS y en UEFI.** Probado
el 09/08 con `foto-del-arranque.sh --entrar`, que pulsa ENTER y retrata el
escritorio a los 250 segundos. Sale en español, con los iconos de RedHornoma.

✅ **Y el escritorio sale limpio.** El «Centro de bienvenida» de KDE ya no se
abre encima: se ven los tres iconos de RedHornoma y nada más. Comprobado con
foto en la ISO del 09/08 a las 12:09.

✅ **El menú de arranque enseñará el Windows que ya estaba.** `os-prober`
venía instalado desde el principio pero Debian lo entrega **desactivado** desde
grub 2.06. Sin eso, instalar RedHornoma en una máquina con Windows dejaba un
menú donde Windows no aparece — y quien lo mira lo da por perdido. Corregido en
`etc/default/grub.d/redhornoma.cfg`, junto con 10 segundos de espera en vez de
5. Se descubrió el 09/08 mirando la receta ANTES de instalar en un portátil que
ya tenía Windows y Ubuntu conviviendo.

✅ **El menú de arranque, mirado con fotos y correcto en los dos caminos:**

```
BIOS  (isolinux, máquinas antiguas)   RedHornoma - probar sin instalar
UEFI  (GRUB, máquinas modernas)       RedHornoma — probar sin instalar
```

La primera ISO del día enseñaba `RedHornoma ГÖ probar sin instalar` en BIOS.
Se comprueba con `scripts/foto-del-arranque.sh`, sin necesitar a nadie
delante.

✅ **Las dos máquinas se pusieron al día (09/08)** — la primera vez que
coincidían con lo publicado. Se comprueba con `dpkg -l 'redhornoma-*'`.

⚠️ **Y volvieron a quedarse atrás el mismo día**, con `panel 1.0.8`,
`respaldo 1.0.16` y `virtualizacion 1.0.14`. Un `sudo apt update && sudo apt full-upgrade` en cada
máquina.

Hasta hoy el servidor tenía la carpeta de documentos funcionando porque el guion
se había lanzado a mano desde `/tmp`, con el paquete viejo instalado. Eso ya no
pasa: **lo que corre es lo que está publicado.**

**Las máquinas:**

| Papel | Equipo | Dónde |
|---|---|---|
| Servidor | `servidor-ciudad` — `flora@192.168.0.110` | Cochabamba |
| Su Windows | `salud-servidor` — **192.168.0.50** | dentro del anterior |
| Administración | `portatil` — `euflo` | viaja |
| Servidor | `respaldo-hornoma` — `192.168.1.101` | CS Hornoma (rural) |
| Windows del centro | `192.168.1.103` | CS Hornoma |

**Hornoma solo es accesible desde su propia red.** Desde Cochabamba no
responde, y eso es normal, no una avería.

---

## 3 · Archivos

```
receta/                  la ISO se construye entera desde aquí
  auto/config            opciones de live-build  ← incluye ForceIPv4
  config/package-lists/  155 paquetes declarados
  hooks-propios/         los ajustes propios (SSH, menú de arranque)
paquetes/                los 7 paquetes .deb, uno por carpeta
  */usr/bin/             las 19 herramientas
  redhornoma-panel/usr/lib/redhornoma/arreglos
                         lo ÚNICO que corre como administrador para reparar.
                         Lista cerrada de palabras: no entra ningún texto
  redhornoma-perifericos/usr/lib/redhornoma/grabar-pendrive
                         escribe la ISO en el pendrive. Vuelve a comprobar
                         POR SU CUENTA que el disco sea extraíble
  redhornoma-respaldo/usr/share/redhornoma/windows/
                         respaldo-programas.ps1 — la ÚNICA pieza que corre
                         DENTRO de Windows. Se instala allí con
                         «redhornoma-respaldo --preparar-programas»
scripts/
  construir-iso.sh       ~13 min · comprueba la receta antes de gastar tiempo
                         y al terminar deja solo las 2 ISOs más recientes
  construir-paquetes.sh  construye Y copia a la receta, con verificación
  publicar-repositorio.sh  firma, sube y ESPERA a que GitHub lo sirva
  probar-compatibilidad.sh  finge 6 máquinas distintas con QEMU
                         «--desde-usb» la arranca como PENDRIVE, no como CD
  foto-del-arranque.sh   retrata la primera pantalla, sin ventana ni persona
  guardar-en-disco.sh    pone a salvo lo irreemplazable en el disco externo
repositorio/             el APT propio (git aparte, rama gh-pages)
pruebas/resultados.md    dónde se ha probado la ISO de verdad
documentacion/           SALMI-EN-RED.md · INSTALAR-WINDOWS.md
  UNIR-LOS-CENTROS.md    el plan para enlazar Hornoma y Cochabamba
  PANTALLA-DE-LOS-CENTROS.md  el objetivo 11, con su decisión de diseño
  hornoma/               los guiones de la visita del 10/08
```

**Regla del proyecto:** nada se instala a mano dentro del sistema. Si algo
hace falta, se declara en la receta o en un paquete. **Un parche es código que
solo existe en una máquina.**

---

## 4 · Qué ha cambiado (5 al 10 de agosto)

**El 11 de agosto, por la noche:**

- 🌙 **El `.101` tiene horario de noche.** Es una máquina vieja: tenerla
  encendida todo el día no es aconsejable, pero euflo necesita llegar a ella
  desde Cochabamba. Solución: **se enciende sola a la 1:00 y se apaga a las
  4:00, de miércoles a domingo** (los días que no está en el centro). El
  despertador es la alarma del reloj de la placa
  (`/sys/class/rtc/rtc0/wakealarm`), y **se probó antes de confiar en ella**:
  la máquina volvió sola a los 4 minutos.
  Instalado con `documentacion/hornoma/horario-noche.sh`.

- 🔑 **La regla que manda sobre todo lo demás: una máquina apagada NO se puede
  encender desde lejos.** No tiene red. La alarma del reloj es la única puerta.
  De ahí que el guion arme la alarma **antes** de apagar y **compruebe que
  quedó puesta** — si la placa la rechaza, no se apaga. Apagar sin alarma
  comprobada sería dejar el centro sin servidor hasta que alguien viaje 100 km.
  **Corolario para quien use esto: apagar la máquina de cualquier otra forma
  (el botón, el menú del escritorio, `poweroff`) NO arma la alarma.**

- Cuatro frenos antes de apagar, y el apagado **se reintenta cada media hora
  durante 4 horas** en vez de rendirse. Salió de una pregunta de euflo —
  «¿y si sigo trabajando a las 4?»—: con un disparo único, quedarse trabajando
  a esa hora significaba que la máquina ya no se apagaba en toda la noche.

- 🔴 **Y uno de esos frenos estaba mal hecho.** «¿Hay alguien trabajando?» se
  miraba solo con `who`, que ve las sesiones **con terminal**. Abrir la
  pantalla del Windows desde el portátil (`redhornoma-entrar --en`, que va por
  `qemu+ssh`) es una conexión **sin terminal**: podía no aparecer. Era apagarle
  la máquina a alguien que está instalando un programa dentro. Ahora se mira
  también con `ss` las conexiones establecidas al puerto 22, que las ve todas.

- ⚠️ **El horario 1:00–4:00 choca con la jornada de euflo, que empieza a las
  4:00.** La máquina se apaga justo cuando él empieza. Si se conecta *antes* de
  las 4 no se apaga (los reintentos lo sostienen), pero si se sienta a las 5 la
  encuentra apagada y no puede hacer nada hasta la 1 del día siguiente.
  **Pendiente de decidir: mover el apagado a las 6:00** — sigue siendo casi
  todo el día apagada, y le cubre el arranque de su jornada.

- 💾 **`documentacion/hornoma/montar-samsung.sh`**: abre el disco Samsung en el
  `.101` y lo deja apuntado para que se monte solo al arrancar. Busca el disco
  **por su modelo, no por la letra** (`sdb` hoy puede ser `sdc` mañana según el
  orden en que se enchufen), y usa `nofail` en `/etc/fstab`: sin eso, arrancar
  con el disco desenchufado dejaría la máquina parada pidiendo auxilio en un
  pueblo donde no hay nadie. Se monta **con escritura**, por decisión expresa
  de euflo — el guion enseña la salud SMART del disco pero no frena por ella.

- 📦 **Los instaladores, para el próximo viaje:** en el portátil hay
  `~/Descargas/SNIS-2026/` con el instalador completo de SNIS 2026 (19 MB) y
  cinco actualizadores de estructura. **De SALMI no hay instalador**: lo que
  hay en `~/Descargas/INF-HORNOMA-JULIO/SALMI-0726/` es el **respaldo** de
  julio (`.sal` y `.con` de 7,7 MB), que es otra cosa. Para instalar SALMI en
  el `.101` hará falta conseguir su instalador primero.

**El 11 de agosto:**

- 🥇 **LOS DOS CENTROS ESTÁN UNIDOS.** Hornoma y Cochabamba, con Tailscale.
  Probado de verdad: desde el área rural se entra por SSH al servidor de la
  ciudad y se ve su panel. **`redhornoma-entrar --en` funcionó por el enlace
  sin cambiarle una línea.**

```
100.89.200.2    portatil
100.81.234.58   respaldo-hornoma     Expiry disabled ✅
100.74.174.70   servidor-ciudad
```

- 🎯 **Objetivo 11 nuevo:** «que se puedan atender varios centros desde un solo
  sitio». Idea de euflo. El mecanismo ya está probado —ejecutar la herramienta
  allá y traer la respuesta— y falta la pantalla que lo enseñe. Plan en
  `documentacion/PANTALLA-DE-LOS-CENTROS.md`.
- **Office instalado en el Windows de Hornoma**, que es lo que le faltaba para
  cerrar el mes.

**El 10 de agosto, en Hornoma, con euflo en el centro:**

- 🥇 **SOAPS 7 instalado y con datos en el servidor `.101`.** Dentro de su
  Windows `SERVER-HORNOMA`: las tres bases creadas y el `.wak` restaurado —
  **113.456 registros, desde enero de 2019 hasta julio de 2026**, y 849
  historias clínicas. Julio cerrado con 58 pacientes en consulta externa.
- 🔴 **El centro estuvo 7 días sin respaldo y nadie se enteró.** El `.101` no
  se había averiado: **estaba apagado** desde el 3 de agosto. Al encenderlo
  hoy intentó el respaldo a los 40 segundos, falló porque no llegaba al
  `.103`, y lo anotó. **El sistema hizo bien su trabajo; el problema es que
  no avisa a nadie.** Es el objetivo 9 dicho en una frase.
- 🪪 **El fallo que costó la tarde: el usuario de Windows se llamaba igual
  que la máquina.** SQL Server no se instalaba y su registro va cifrado.
  Receta abajo — es lo más reutilizable del día.
- 🔌 **Ese Windows no tenía red**: cero paquetes enviados en toda su vida, por
  falta del controlador virtio. Y de paso queda resuelta una duda: **el CD
  virtio reducido que hace `redhornoma-virtio-reducido` SÍ lleva el agente
  invitado**.



**El 9 de agosto:**

- 💿 **ISO nueva y limpia:** `redhornoma-0.1-20260809` (`fcac8d1c…`). Sin el
  icono sobrante, con todo lo del día dentro, **grabada en pendrive y
  comprobada leyendo del propio pendrive**. Es la primera vez que se
  comprueba el arranque por USB, y a la primera salió un defecto de meses. **La carpeta de ISOs ahora se poda sola**: se
  quedan las 2 más recientes y se dice cuáles desaparecen. Había cinco, 14 GB,
  de las que cuatro no las iba a instalar nadie.
- 🟡 **El objetivo 9 pasó de 20% a 55%: «Algo no funciona».** El panel sabía
  decir qué iba mal y terminaba dando un comando que copiar. Ahora hay una
  herramienta que mira, explica en español, arregla y **comprueba después**.
  Seis averías se arreglan solas desde ahí. Detalle abajo.
- 🔴 **El panel llevaba mintiendo sobre lo más importante que enseña.** Le
  decía al servidor que su Windows estaba apagado mientras llevaba horas
  encendido. La causa: la distro está en español y `virsh` contesta
  «ejecutando», no «running». Corregido en `panel 1.0.5` y en dos sitios más
  de `virtualizacion 1.0.14`.
- 💾 **El proyecto ya no vive en un solo disco.** Decisión de euflo: desde hoy
  todo lo que hay que poner a salvo va al disco externo Toshiba
  (`CURSAKIALINUX`), dentro de `RESPALDOS-CURSALIAS`. Lo hace
  `scripts/guardar-en-disco.sh` con un solo comando. Detalle abajo.
- **`redhornoma-respaldo 1.0.15`**: el `nvram.fd` del respaldo se queda legible.
  Antes solo lo podía leer root y al llevarse el respaldo a otro disco llegaba
  todo menos ese archivo — y sin él la máquina restaurada no sabe qué arrancar.

**El 8 de agosto, de madrugada:**

- 🥇 **El objetivo 2 quedó cerrado.** SOAPS 7 con **dos puestos escribiendo a la
  vez** completa los tres programas. Sin bloqueos: SQL Server está hecho para
  esto y se nota. Receta abajo.
- 🔴 **SOAPS llevaba cinco semanas sin respaldo** y nadie lo sabía. El diseño
  esperaba que una persona generara esas copias a mano. **Resuelto el mismo
  día** con `redhornoma-respaldo 1.0.11`: ahora el propio Windows se las hace
  cada noche a las 2 y Linux las recoge. Receta abajo.
- **Y se probó restaurándolo**, sin tocar la base real: las cuentas del
  respaldo coinciden exactamente con las de producción.
- **Teníamos mal cuál base guarda los datos de SNIS.** Se escribe en
  `snis2026.mdb` (4,6 MB), no en `snismain.mdb` (42 MB). Corregido abajo —
  importa para los respaldos y para lo que va a SEDES.
- **Los 7 registros del año 2064: encontrados Y corregidos.** No era un año mal
  tecleado — era **la fecha de nacimiento de la paciente** metida en la casilla
  de la atención. Ya no queda ni una fecha imposible en toda la base. Abajo.
- **SNIS se ve bien en el puesto**: mínimo real 1280 × 1024. Receta abajo.
- El 301a de agosto quedó limpio tras la prueba de los dos puestos.

**El 8 de agosto, por la mañana y la tarde:**

- **ISO nueva** `redhornoma-0.1-20260808`, verificada por dentro **y probada**.
- 🥇 **Los cinco perfiles de compatibilidad, pasados.** `centro`, `antigua`,
  `moderna`, `segura` y `portatil-viejo` instalan y arrancan. El objetivo 1
  sube al 95%: lo único que falta ya no se puede fingir con QEMU.
- **El banco de pruebas, recalibrado** con lo que euflo ve llegar: perfil
  `centro` nuevo (medido sobre una máquina real) y `minima` de 1,5 a 2 GB,
  porque de 1,5 GB ya no llega ninguna a un centro.
- **Documentos del centro** (`perifericos 1.0.8` + `red 1.0.6`): una carpeta que
  ven todos los consultorios, con su icono en el escritorio de Windows. Se
  acabó caminar con el pendrive de un consultorio a otro.
- **Los objetivos pasaron de siete a diez.**
- 🔴 **Y un defecto propio, encontrado por las pruebas:** un icono de instalador
  añadido esa mañana sobrevivía en el sistema **ya instalado**, apuntando a un
  programa que Calamares borra al terminar. Deshecho. Ninguna revisión de
  código lo habría visto — el archivo era correcto; el problema era *cuándo
  dejaba de serlo*.

**El 8 de agosto, por la tarde — todo salió de intentar restaurar SNIS:**

- 🥇 **SNIS restaurado y verificado.** Con los tres programas ya devueltos desde
  un respaldo, el objetivo 8 sube al 90%. Receta abajo.
- 🔴 **El respaldo de SNIS solo se llevaba los `.mdb`** — 4 archivos de 40. Fuera
  quedaban los 16 programas, las plantillas, y el `Conexion2026.bin` con la
  configuración del centro. Corregido en `respaldo 1.0.13`: va la carpeta
  entera. El paquete pasó de 36 a 44 MB.
- 🔴 **Y aun así no bastaba**: SNIS restaurado en otra máquina muere con
  `error 52` porque su configuración apunta al servidor viejo. La receta para
  arreglarlo, abajo. Sin ella, un martes serían horas perdidas.
- 🔴 **La tarea nocturna no se recuperaba de un apagón** (`respaldo 1.0.12`).
  Un centro apaga las computadoras: si el servidor estaba apagado a las 2, esa
  copia no se hacía. El lado de Linux lo tenía resuelto desde el principio.
- 🔴 **Los puestos no deben usar cuenta Microsoft.** Al cortar la red se vio que
  **Windows no deja iniciar sesión sin internet**. Pendiente, y va como norma.

**Del 5 al 7 de agosto:**

- **Repositorio APT propio** en la rama `gh-pages` de `panozin23/redhornoma`,
  firmado con llave propia. Dos vías: la ISO para máquinas nuevas, `apt` para
  las que ya trabajan. `redhornoma-base` trae el origen configurado dentro.
- **El respaldo avisa.** Cada copia deja una señal fechada en
  `drive:SENALES-REDHORNOMA`; `redhornoma-vigilar` las lee todas.
- **SOAPS 7 funciona en red** sin su instalador (receta abajo).
- **Seis herramientas con ventana**, incluido un asistente de puesta en marcha.
- **El servidor anuncia dónde está su Windows** (`windows=` en avahi).
- La ISO pasó de 90 a 12 minutos y comprueba su propia huella.
- **SNIS 2026 funciona en red** (07/08). Es familia de SALMI —Visual Basic 6 con
  bases Access—, no de SOAPS. Receta abajo.
- **Dos puestos escribiendo a la vez en SNIS** (07/08, tarde). Probado en los
  dos órdenes, con los datos releídos del disco. Nadie pierde nada.
- **`redhornoma-entrar` 1.0.12**: el visor ya no le cambia la resolución al
  Windows. Era lo que vaciaba los formularios de SNIS a media captura.

---

## 5 · Qué se ha intentado y SÍ funcionó

**«Algo no funciona» — que el centro se arregle solo** (09/08). Es el
objetivo 9, y hasta hoy estaba en el 20% porque todo dependía de que euflo
contestara el teléfono.

El panel ya diagnosticaba bien. El problema era cómo terminaba:

```
Lo que habría que hacer
   ·  Van más de dos días sin copia:  sudo redhornoma-respaldo --ahora
```

Eso no es arreglarse solo: es saber el nombre de la enfermedad y que te manden
a buscar la farmacia. En un centro rural, un martes, con la enfermera
atendiendo, **ese renglón no lo escribe nadie**.

`redhornoma-arreglar` hace cuatro pasos, y el cuarto es el que importa:

```
1 · MIRAR      qué pasa AHORA, preguntándoselo a la máquina
2 · EXPLICAR   qué significa, en español, y qué se va a hacer
3 · ARREGLAR   solo lo que la persona autoriza
4 · COMPROBAR  volver a mirar — y decir «arreglado» solo si es cierto
```

El paso 4 no se salta nunca. **Un programa que dice «listo» porque el comando
no dio error es igual de inútil que el respaldo que se creyó hecho durante
cinco semanas.**

Lo que sabe arreglar, y todo ello sin poder perder un solo dato:

| Avería | Qué hace |
|---|---|
| Los programas de salud están apagados | enciende el Windows del servidor |
| El servidor no se anuncia en la red | enciende avahi, y lo deja encendido |
| Las carpetas compartidas están caídas | reinicia smbd — no toca ni un archivo |
| No hay ni un respaldo / van días sin copia | respalda y verifica |
| La última copia no pasó la comprobación | hace una nueva y la verifica |
| Esta cuenta no maneja los programas | da el permiso de libvirt |

**Del respaldo del centro responde el servidor, y solo él.** A ningún otro
equipo se le reclama: el portátil de administración no guarda la información
de ningún centro, y un aviso que no corresponde enseña a ignorar los que sí.
También sabe distinguir una copia rechazada *porque salió mal* de una
rechazada *porque se respaldó la máquina equivocada* — la segunda no se
arregla repitiendo el respaldo, y por eso no lo ofrece.

Y dos que **no** puede arreglar pero sí diagnosticar, que es lo que convierte
una llamada de media hora en una frase: «esta computadora está fuera de la
red» (cable) y «el servidor responde, pero su Windows no» (hay que encenderlo
allá). Son los dos que producen el famoso *«no entra al SALMI»*.

**Dónde está la línea de lo que hace sin preguntar la contraseña dos veces:**
todo lo de arriba solo ENCIENDE lo apagado o COPIA lo que faltaba. Recuperar
un respaldo encima de la base viva, borrar copias o cambiar el papel del
equipo **no están** y siguen pidiendo confirmación cada vez, a propósito.

**Cómo está construido, y por qué así:** lo único que corre como
administrador es `/usr/lib/redhornoma/arreglos`, que solo entiende **palabras
de una lista cerrada**. Ningún texto de la interfaz llega jamás a una orden de
root. Se probó pasándole `borrar-todo`, `rm -rf /` y
`encender-anuncio-red; echo INYECTADO`: rechazó los tres.

En el menú aparece como **«Algo no funciona»** — que es como lo buscaría
alguien —, y en el panel como botón.

**Instalar en una máquina que ya tenía Windows y otro Linux** (09/08). Primera
instalación de RedHornoma **fuera de las máquinas del proyecto**: el portátil HP
de rosi, UEFI, con Windows en un SSD y Ubuntu en un disco de 1 TB.

**El sistema quedó perfecto y aun así la computadora no lo arrancaba.** Eso es
lo que hay que entender de este caso.

```
1 · instalado sobre la partición de Ubuntu        ✅ bien
2 · al reiniciar                                   → grub>
3 · quitada la entrada de Ubuntu                   → arrancó WINDOWS
4 · puesta RedHornoma la primera                   ✅ arranca solo
```

**Por qué `grub>`:** el firmware seguía arrancando la entrada de Ubuntu, cuyo
GRUB 2.06 buscaba por UUID un disco que ya no existía —RedHornoma se instaló
justo encima—. GRUB no encuentra nada y suelta el símbolo del sistema.

**Por qué después arrancó Windows:** porque **Windows se pone a sí mismo el
primero de la lista cada vez que arranca**. Al quitar Ubuntu, el siguiente de
la cola era Windows, arrancó, y se coronó.

**La regla que sale de aquí: nunca quitar la entrada del sistema viejo antes de
comprobar que la nueva queda en pie.**

```bash
sudo efibootmgr                      # ver la lista y el BootOrder
sudo efibootmgr -o 0001,0003,0006,…  # la de RedHornoma PRIMERO
```

Y en los HP hace falta además **apartar los archivos**: el firmware se
reinventa la entrada si `\EFI\ubuntu\` sigue ahí. Se renombra a
`ubuntu-retirado` en vez de borrarla — ocupa unos megas y así se deshace.

Otras dos cosas de este caso, para no repetir suposiciones:

- **El instalador SÍ creó su entrada** (`Debian`). El problema nunca fue que
  faltara, sino el orden. Mirar antes de crear otra.
- La máquina tenía **tres particiones EFI System** y el instalador eligió la
  del segundo disco (20,5 GB) en vez de la del SSD donde vive Windows.
  Funciona, pero no es lo más limpio.

⚠️ **Y el error de método, que fue mío:** el primer comando de reparación
llevaba `>/dev/null` en la creación de la entrada. `efibootmgr` protestó y su
queja se fue a la basura, así que pareció que no había hecho nada. **Es el
mismo `2>/dev/null` que se corrigió esta misma mañana en `guardar-en-disco.sh`,
repetido cuatro horas después.**

**Grabar el pendrive sin borrar el servidor** (09/08). Es hoy la operación
**más peligrosa** del proyecto: un `dd` con la letra equivocada destruye lo que
haya en ese disco, y no avisa ni se puede deshacer.

⚠️ **En `servidor-ciudad` hay tres discos y dos NO se tocan jamás:**

```
sda   931,5G  sata  RM=0  TOSHIBA DT01ACA100    ← su sistema, montado en /
sdb   931,5G  usb   RM=0  ST1000LM025           ← el SAMSUNG, 557 GB de euflo
sdc    14,6G  usb   RM=1  UDisk                 ← el pendrive
```

**La letra NUNCA se elige a ojo.** Se confirma por tres caminos que tienen que
coincidir, y si uno no cuadra, no se graba:

```
lsblk -d -o NAME,SIZE,TRAN,RM,MODEL,SERIAL
```

1. **`RM=1`** — extraíble. El Samsung está en USB igual que el pendrive, así
   que «va por USB» no distingue nada. Esta columna sí.
2. **El tamaño** — 14,6 GB contra dos de 931,5 GB.
3. **Qué lleva dentro** — el pendrive ya traía una RedHornoma de otra vez.

Después, en una sola línea, desmontar · grabar · **volver a leer**:

```bash
ssh -t flora@192.168.0.110 "sudo bash -c 'umount /dev/sdc[0-9] 2>/dev/null; \
  dd if=RUTA.iso of=/dev/sdc bs=4M status=progress conv=fsync; \
  head -c TAMAÑO_EN_BYTES /dev/sdc | sha256sum'"
```

El `head -c` con el tamaño exacto de la ISO es lo que convierte esto en una
comprobación de verdad: la huella sale de **leer el pendrive**, no de que `dd`
terminara sin quejarse. El 09/08 dio `58b22a13…`, igual que la ISO.

Por los puertos USB 2.0 del servidor: escribe a 13 MB/s y lee a 7,5 — unos 10
minutos. En el portátil, que tiene USB 3, sería bastante menos.

**Y hay que grabarlo otra vez** cada vez que se reconstruye la ISO. El 09/08 se
grabó dos veces: primero con `58b22a13…` y, tras arreglar el menú, con
`fcac8d1c…`, que es la buena y la que está en el pendrive ahora.

✅ **Hecho el mismo día: `redhornoma-pendrive`** (`perifericos 1.0.9`). En el
menú, «Grabar un pendrive con RedHornoma». Ya no se escribe ninguna letra.

**El filtro es «extraíble», no «va por USB»**, y esa distinción es todo el
asunto: el disco de 1 TB de euflo va por USB igual que el pendrive. Lo que los
separa es la columna `RM` de `lsblk`. Probado en el servidor con sus tres
discos delante: **solo apareció `/dev/sdc`**.

Y lo que de verdad protege no está en la ventana sino en
`/usr/lib/redhornoma/grabar-pendrive`, que **no se fía de quien lo llama** y
vuelve a comprobarlo todo después de pedir la contraseña. Se le pidió escribir
en los discos peligrosos y rechazó los cinco, siempre antes de escribir nada:

```
/dev/sda      NO es extraíble — me niego a escribir ahí
/dev/sdb      NO es extraíble — me niego a escribir ahí
/dev/sdc1     es una partición, no un disco entero
/dev/nvme0n1  no es un disco
/dev/null     no es un disco
```

También rechaza discos de más de 256 GB, los que tengan partes del sistema
montadas, y el disco del que arrancó la computadora.

✅ **Estrenada el mismo día, grabando de verdad** el pendrive del servidor con
la ISO `30d9869f…`. Salió a la primera y terminó comprobando lo grabado
**leyendo del propio pendrive**, no fiándose de que `dd` no se quejara.

**Y desde `perifericos 1.0.10` deja registro** en `/var/lib/redhornoma/pendrive.log`:
fecha, qué ISO, en qué pendrive y la huella. Antes comprobaba y se olvidaba —
se vio ese mismo día, al querer saber desde fuera si un pendrive recién grabado
estaba bien y no haber dónde mirar. **Quien grabó puede no estar el día que
alguien pregunte.**

**Poner el proyecto a salvo en el disco externo** (09/08). Un solo comando,
desde el portátil, con el Toshiba enchufado:

```bash
bash /home/euflo/PROYECTOS-CURSALIA/redhornoma/scripts/guardar-en-disco.sh
```

Deja esto en `/media/euflo/CURSAKIALINUX/RESPALDOS-CURSALIAS/`:

```
PROYECTO/            proyecto-AAAAMMDD-HHMM.tar.gz  · 14 MB · las 8 últimas
LLAVES/              la del repositorio APT y la de BitLocker de olivos
DEL-SERVIDOR/        los 7 respaldos del centro                    · 93 MB
ISO-COPY-X-FECHAS/   20260808/  la ISO y su SHA256SUMS comprobado  · 2,7 GB
```

**No copia los 74 GB del proyecto, y es a propósito.** 45 GB son discos de las
pruebas de compatibilidad, 14 GB son ISOs que se rehacen en doce minutos y
13 GB son caché de paquetes bajados. **Lo irreemplazable son 14 MB**: el código
de las 17 herramientas, los guiones, la receta, la documentación y las llaves.

Tres cosas que hace y conviene no quitarle:

- **Se niega a escribir si el destino está en el disco interno.** Una copia en
  el mismo disco no protege de nada, y es un error fácil de no notar.
- **Abre el paquete después de crearlo** (`tar -tzf`) y cuenta los archivos.
- **Comprueba la huella de la ISO copiada** contra la original, no se fía de
  que `cp` terminara sin quejarse.

De la ISO guarda **solo la última**, en una carpeta con la fecha de
construcción sacada de su propio nombre — no la de hoy, porque lo que importa
es saber qué lleva dentro. Con `--con-isos` se llevan todas.

⚠️ **El disco es NTFS, así que no conserva permisos.** La llave privada del
repositorio queda ahí legible por cualquiera que enchufe el disco. Es el precio
de tenerla fuera del portátil; si el disco sale del despacho, hay que saberlo.

**SALMI en red** (04/08): el cliente instala SALMI localmente solo por sus
bibliotecas, y abre el `.exe` **del servidor** por una carpeta compartida. Se
retira el icono local. Probado con dos puestos escribiendo a la vez.

**SOAPS 7 en red sin su instalador** (06/08), en este orden:

1. Compartir `C:\SOAPS7` en el servidor
2. Cortafuegos: regla **por programa** (`sqlservr.exe`) + UDP 1434
3. En el cliente: registrar los 16 componentes de `registrarDlls`
4. Crystal Reports pide 5 piezas más del `SysWOW64` del servidor
5. Importar `HKLM\SOFTWARE\WOW6432Node\SUIS` y cambiar `SERVIDOR` por la IP
6. Registrar `actskin4.ocx` y `TDBNumbr.ocx` de la raíz
7. **Traer los 30 `.ocx` del servidor de golpe** — hacerlo así ahorra media hora

**SNIS 2026 en red** (07/08). Vive en `C:\SNIS2026` y sus datos son Access.
**Cuál es cuál — medido el 08/08, no supuesto** (mirando qué archivo cambia de
fecha al capturar y al borrar, con SNIS cerrado del todo y sin candados):

```
snis2026.mdb    4,6 MB   AQUI SE ESCRIBE lo que se captura del 2026
snismain.mdb   42,4 MB   de consulta: catalogos, establecimientos, historico
_systmp.mdb    34,6 MB   temporal compartida
```

`snismain.mdb` **no cambió** ni con dos puestos escribiendo ni con un borrado.
SNIS la lee mucho —por eso romper las 39 tablas enlazadas dejaba los datos
incompletos— pero no escribe en ella. **Lo que va a SEDES sale de
`snis2026.mdb`**, que son 4,6 MB, no de la de 42.

*(Hasta el 08/08 el traspaso decía lo contrario: que `snismain.mdb` eran «los
datos» y `snis2026.mdb` «la fachada». Estaba mal.)*
**No hace falta instalarlo en el consultorio** —lo dijo euflo por experiencia y
acertó—: se abre el del servidor. La clave está en un detalle que costó dos
horas encontrar:

> `snis2026.mdb` tiene **39 tablas enlazadas por ruta fija** a
> `C:\SNIS2026\snismain.mdb`. Desde un consultorio ese disco no existe, las 39
> tablas se rompen y **SNIS entra igual, pero con los datos incompletos**.
> No avisa de que falta nada.

Lo que funcionó, en este orden:

1. Compartir `C:\SNIS2026` como `SNIS`, con escritura para `salmired`
2. Añadir también al usuario del propio servidor (`server-cbba`) al recurso
3. En el consultorio, un acceso directo a `\\SERVIDOR\snis\snis_2026.exe`
   —ruta entera, sin unidad `S:`
4. **En el consultorio, un enlace de directorio** que haga existir la ruta que
   las tablas esperan:
   ```
   fsutil behavior set SymlinkEvaluation L2R:1
   mklink /D C:\SNIS2026 \\192.168.0.50\SNIS
   ```

El paso 4 es el que lo resuelve, y su virtud es que **no toca ni un byte de las
bases**: el servidor sigue exactamente igual que antes.

**SNIS con dos puestos escribiendo a la vez** (07/08). Se probó sobre las bases
reales, con un respaldo en frío verificado por huella SHA256 antes de empezar
(`C:\RESPALDO-SNIS-20260807-ANTES-PRUEBA`), y sobre el mes de agosto, que no
tenía ni un registro. Los dos puestos fueron el consultorio `olivos`
(192.168.0.106) y el propio Windows del servidor (192.168.0.50).

Cómo se comprueba de verdad, sin fiarse de la pantalla: **el candado `.ldb` de
Access apunta 64 bytes por usuario dentro de la base**. Con los dos dentro:

```
snismain.ldb   128 bytes   ->  2 usuarios     los datos de verdad
_systmp.ldb    128 bytes   ->  2 usuarios     la temporal de 34 MB
```

Resultados, en los dos órdenes de guardado:

- Leer a la vez: sin problema. `_systmp.mdb`, que era el candidato a dar
  guerra, no dio ninguna.
- Escribir a la vez: **no se pierde nada**. Se montó a propósito el caso
  peligroso —cada puesto con un cambio que el otro no conocía— y los dos
  cambios entraron enteros. Access no pisó la fila del otro.
- Una vez de tres, el segundo en guardar sacó `Error 6160 en tiempo de
  ejecución: Data access error` y **el formulario se cerró**. Pero había
  guardado antes de reventar: el dato estaba. No se ha vuelto a repetir.

Un detalle que conviene saber: **aunque el servidor abra el programa desde
`C:\SNIS2026`, la base la abre por `\\192.168.0.50\SNIS`**, porque es lo que
dice el `Conexion2026.bin` compartido. Los dos puestos entran por el mismo
camino de red, y como prueba de concurrencia eso es mejor, no peor.

**Que SNIS se vea bien en el puesto** (08/08). Aprobado por euflo. Dos piezas,
y hacen falta las dos:

1. **`redhornoma-entrar` 1.0.12 o superior**, que pasa `--auto-resize=never`.
   Sin eso, el visor le cambia la resolución al Windows al mover la ventana y
   el formulario se vacía a media captura.
2. **Poner el Windows del puesto en 1280 × 1024**, una sola vez. Dentro de
   Windows: clic derecho en el escritorio → `Configuración de pantalla` →
   `Resolución de pantalla`. **Con SNIS cerrado**, o se vacía el formulario.

Por qué ese número: el 301a mide **1080 píxeles de ancho y se centra**, y los
botones `Eliminar`/`Guardar`/`Salir` no van dentro del formulario — son una tira
pegada al **borde izquierdo de la pantalla**. Por debajo de 1280 de ancho el
formulario tapa la tira y **el Guardar desaparece sin avisar**. De alto pide
unos 950 para que quepa la barra de la declaración jurada.

Y al revés de lo que parece: **cuanto más ancha la pantalla del Windows, más
pequeño se ve el formulario**, porque se queda en sus 1080 y el resto es vacío.
Bajando la resolución, el formulario llena la pantalla y el visor la agranda
entera. En un monitor viejo de 1024×768 no cabe de ninguna manera: hay que
enseñarlo reducido con el `--zoom` del visor.

Con `--auto-resize=never` **Windows se queda con la resolución entre
reinicios**, así que es un ajuste de una sola vez por máquina.

**SOAPS 7 con dos puestos escribiendo a la vez** (08/08). **Funciona, y sin un
solo sobresalto** — al revés que SNIS. SOAPS no usa Access sino **SQL Server
2008 R2 Express**, que está hecho para esto.

Cómo está montado por dentro, medido:

```
motor      SQL Server 2008 R2 Express, instancia SUIS
bases      c:\SOAPS7\BD\BDEstadistica.mdf   253 MB   ← el trabajo del centro
           c:\SOAPS7\BD\BDSnis.mdf           40 MB
           c:\SOAPS7\BD\BDMorbilidad.mdf     14 MB
entra como sa (TODOS los puestos, es como está hecho el programa)
```

**La cuenta de Windows es administradora del motor**, así que se puede
respaldar y consultar **sin conocer la contraseña de la aplicación**:

```
"C:\Program Files\Microsoft SQL Server\100\Tools\Binn\SQLCMD.EXE" -S .\SUIS -E -Q "..."
```

Cómo se comprueba de verdad, sin fiarse de la pantalla:

```sql
-- dos clientes distintos, por nombre de máquina
SELECT DB_NAME(dbid), hostname, loginame, COUNT(*)
FROM sys.sysprocesses WHERE dbid > 4 AND hostname <> '' GROUP BY ...
-- y esto es lo que delata un bloqueo, que con Access no se podía ver
SELECT spid, blocked, hostname, lastwaittype FROM sys.sysprocesses WHERE blocked <> 0
```

Resultado: `OLIVOS` y `DESKTOP-LBGLGUA` dentro a la vez, **nadie esperando a
nadie**, y las dos atenciones guardadas casi simultáneamente **entraron las
dos** (`SE_DATOS` subió de 113.461 a 113.470, que es 5 + 4).

**Que SOAPS y SNIS se respalden solos** (08/08, `redhornoma-respaldo 1.0.11`).

El problema: SALMI se saca desde fuera porque sus archivos están siempre en el
mismo sitio. **SOAPS no se puede copiar así** —vive en un SQL Server con las
bases abiertas y copiar los `.mdf` da una copia rota—, así que el diseño
anterior esperaba que **una persona** generara esas copias a mano cada mes.
Al mirarlo, la última era del 1 de julio. *Un respaldo que depende de que
alguien se acuerde es un respaldo que no ocurre.*

Cómo funciona ahora:

```
DENTRO de Windows   C:\ProgramData\RedHornoma\respaldo-programas.ps1
                    tarea «RedHornoma - Respaldo de programas», cada noche a las 2
                    · le PIDE el respaldo a SQL Server y lo verifica
                      (BACKUP … WITH CHECKSUM  +  RESTORE VERIFYONLY)
                    · copia las bases .mdb de SNIS
                    · lo empaqueta y marca el nombre -CON-AVISOS si algo falló
EN Linux            lo recoge del respaldo diario, de la carpeta compartida
```

**Se pone en marcha una sola vez:** `sudo redhornoma-respaldo --preparar-programas`.
Deja el guion dentro, crea la tarea, **y la ejecuta para verla funcionar** en
vez de programarla y confiar.

**El truco que lo hace barato:** el paquete se deja en la carpeta compartida
(`/var/lib/libvirt/compartido`), que ya **es** un directorio de Linux. Recogerlo
no cuesta ni una transferencia. Por el canal del agente invitado serían
cientos de viajes de medio mega.

```
330 MB de bases  →  36 MB comprimidos  →  33 segundos
```

Ese tamaño es lo que hace que ahora **sí quepa en la nube de un centro rural**,
que era la razón por la que antes no se recogía.

A las 2 de la madrugada porque el centro está cerrado y nadie tiene SNIS
abierto: las bases de Access solo se copian enteras si nadie está dentro. Si
alguien lo estuviera, el paquete sale marcado `-CON-AVISOS`.

**Y se recupera de un apagón, desde `respaldo 1.0.12`.** Un centro APAGA las
computadoras por la noche: si el servidor está apagado a las 2, una tarea diaria
normal se salta esa copia y no vuelve a intentarlo. El lado de Linux ya lo tenía
resuelto desde el principio —mira `CADA_DIAS`—, y al programar la de Windows se
olvidó aplicar la misma lección. Se vio el 08/08 con el servidor apagado un
sábado por la tarde, y **medido**: `StartWhenAvailable` estaba en `False`.

`schtasks` no sabe poner esa opción; hay que tocarla después con
`Set-ScheduledTask` y **leerla de vuelta para comprobar que se aplicó**. Si no
pudiera, el guion lo dice y da los pasos para hacerlo a mano.

✅ **PROBADO EN CONDICIONES REALES la primera noche (09/08).** El servidor pasó
apagado las 2 de la madrugada. Al encenderlo:

```
servidor encendido:   05:19:27
la tarea corrió:      05:25:25    ← seis minutos después
resultado:            0
dejó                  programas-20260809.zip · 44 MB
```

**Sin ese ajuste, ese día no habría habido copia de SOAPS ni de SNIS**, y nadie
se habría enterado hasta que el respaldo diario avisara a los dos días.

**Ojo con el sitio en Drive:** cada respaldo pasa de ~8 MB a ~44. Con
`nube_conservar=30` son ~1,3 GB en vez de 250 MB. Cabe en los 15 GB gratis,
pero si algún día la cuenta va justa, se baja ese número y ya está.

**Lo que NO comprueba, y hay que saberlo:** el respaldo recoge el paquete y
mira que abra, pero **no vuelve a verificar las bases de dentro** — eso ya lo
hizo SQL Server al generarlas. Si aparece un paquete `-CON-AVISOS`, hay que
mirar su `PARTE.txt`: ahí dice qué falló.

**Restauración de SOAPS probada** (08/08), y **sin tocar la base real**. Se sacó
el `.bak` del paquete igual que se haría en una emergencia y se devolvió **al
lado** de la buena, con otro nombre y los archivos en otra carpeta (`WITH MOVE`,
que es lo que impide aplastar la real por un despiste):

```
                   la real     el respaldo
SE_DATOS           113.456       113.456
TblPrestaciones     17.086        17.086
perPersona               9             9
```

Y las cuatro bases de SNIS del paquete **coinciden byte por byte** (SHA256) con
las que están en `C:\SNIS2026`. Con Access no hay `RESTORE VERIFYONLY`: la
huella del archivo es lo que vale.

Al terminar se borró la base de prueba y la carpeta de trabajo.

**Los 7 registros del año 2064, resueltos** (08/08). Llevaban tiempo ensuciando
la entrega a SEDES y nadie sabía de dónde salían. **No era un año mal
tecleado:**

```
Historia 328    JUANA POMA UCIEDA, nacida el 1964-09-13
la atención     fechada el          2064-09-13
```

Mismo día, mismo mes, solo cambia el siglo: **alguien metió la fecha de
nacimiento de la paciente en la casilla de la fecha de atención**. Encajaba con
el resto del registro, que traía «año de nacimiento 100», también basura.

**Cómo se encontró la fecha buena sin adivinar:** los formularios 538, 539 y 11
—de sistema, que el usuario no ve— guardaban 44237, 44238 y 44239. Traducidos
como fecha de Access (día cero = 1899-12-30) son **10, 11 y 12 de febrero de
2021**. Y en la lista de atenciones de Juana había un hueco justo ahí, entre el
2021-01-16 y el 2021-07-21.

Se corrigió a **2021-02-10**, con respaldo verificado antes, dentro de una
transacción que se deshacía sola si no eran exactamente 7 filas. Resultado:
7 filas cambiadas, el total sin moverse, y **cero fechas raras en toda la base**.

*Lo que euflo pidió al principio era ponerlo en 1964. Se le explicó que eso no
arregla nada —dejaría la atención fechada el día que la paciente nació, mal
igual pero sin cantar— y eligió la fecha buena. Merece la pena discrepar cuando
hay un dato delante.*

**Documentos del centro** (08/08, `perifericos 1.0.8`). Nace de un problema
diario: para pasarse un informe de un consultorio a otro, los médicos **iban
caminando con un pendrive**, copiaban y volvían. Diez minutos cada vez.

```
sudo redhornoma-carpeta-compartida --documentos      (en el SERVIDOR, una vez)
   crea    /var/lib/redhornoma/documentos
   publica \\192.168.0.110\documentos   ← la IP del LINUX, no la de su Windows
   cuenta  salmired — la MISMA que ya tienen guardada para SALMI y SNIS
```

**Va aparte de «compartido» a propósito.** En el servidor, `compartido` guarda
el respaldo diario con las bases de todos los pacientes; abrirla a la red
pondría eso al alcance de cualquier computadora. `compartido` sigue viéndose
solo desde la máquina virtual de cada equipo.

**Por qué lleva contraseña, si euflo la quería sin ella.** La pidió sin
contraseña con buen criterio —el personal es de confianza y todos meten datos
en los tres programas—, y así se hizo primero. Pero **Windows 10 y 11 traen
bloqueado de fábrica el acceso sin contraseña a carpetas de red**
(`AllowInsecureGuestAuth`, sin poner = bloqueado). Samba la servía
perfectamente —comprobado desde otra máquina Linux de la red— y Windows se
negaba a entrar.

La salida elegida no baja ninguna protección: cuenta de verdad, **guardada una
sola vez en cada puesto**. Nadie vuelve a escribir nada. Es el mismo trato que
ya tienen SALMI, SNIS y SOAPS, y por eso se usa el mismo usuario: **una sola
credencial en todo el centro**.

**Y el icono, desde `redhornoma-red 1.0.6`** (08/08, probado). `redhornoma-cliente`
trae una casilla más: *«Poner el icono de Documentos del centro»*. Guarda la
credencial con `cmdkey` y deja un acceso directo en el escritorio público. Doble
clic y dentro — **nadie teclea nunca `\\192.168.0.110\documentos`**, que además
exigiría saberse el `Alt + 92` de la barra invertida.

**No pregunta la dirección del Linux, y eso es a propósito.** El servidor ya se
anuncia en la red con las dos —la suya y la de su Windows—, así que la busca
sola (campo 8 del anuncio de avahi, frente al `windows=` que usa para los
programas). Una dirección menos que recordar, y una menos que equivocar. Si el
servidor no se anuncia, **no pone el icono** y lo dice: mejor sin icono que un
icono que no lleva a ningún sitio.

Probado el 08/08 en `olivos`, y la salida enseña las dos direcciones separadas:

```
Documentos del centro  ->  \\192.168.0.110\documentos    el LINUX
SALMI del centro       ->  \\192.168.0.50\salmi\...      el WINDOWS
```

**Restauración de SNIS probada** (08/08) — y **destapó que el respaldo no
bastaba**. Es el simulacro más útil que se ha hecho en este proyecto.

Se montó como un desastre de verdad: *«murió el servidor, solo tengo el
respaldo»*. En el puesto `olivos`, con **la red cortada** para que no pudiera
leer del servidor y darnos un verde falso:

```
virsh domif-setlink salud-puesto <MAC> down     ← esto es lo que hace la prueba honesta
```

**Lo que pasó, en orden:**

1. Se restauró la carpeta entera del respaldo en `C:\SNIS2026` del puesto
2. `snis_2026.exe` → 🔴 **`Run-time error '52': Bad file name or number`**
3. Con todos los datos delante, el programa **se negaba a abrir**

**La causa, medida y no supuesta.** `Conexion2026.bin` es una base de Access
**sin contraseña**, con una sola tabla:

```
tconexion:  RutaAccess   = \\192.168.0.50\SNIS   ← aquí está
            ServidorSQL  = servidor
            BaseSnis     = snis2026.mdb
            BaseTemporal = _systmp.mdb
            Servidor     = ACCESS
```

SNIS lee ahí dónde están sus datos. Restaurado en otra máquina, sigue buscando
el servidor viejo, no lo encuentra, y muere con un error que no explica nada.

**La receta que faltaba** — después de devolver los archivos, apuntar SNIS a
ellos. Se puede hacer sin abrir el programa:

```powershell
# con el PowerShell de 32 bits: C:\Windows\SysWOW64\WindowsPowerShell\v1.0
$cn = New-Object -ComObject ADODB.Connection
$cn.Open("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SNIS2026\Conexion2026.bin;")
$cn.Execute("UPDATE tconexion SET RutaAccess = 'C:\SNIS2026'")
$cn.Close()
```

Con eso, SNIS abrió y enseñó **las cifras reales de julio con el servidor
inalcanzable** (21/31 en mayores de 60, 1/3 en 50-59, 1/2 en niños de 1 a 4).
Restauración probada de verdad.

⚠️ **Dos avisos para quien repita esto:**

- **La primera lectura fue un falso positivo.** Al devolver la red un momento
  —Windows no dejaba iniciar sesión sin internet— SNIS leyó del **servidor** y
  enseñó los números correctos sin que el respaldo hubiera servido de nada.
  **Sin cortar la red, esta prueba no demuestra nada.**
- Al deshacerlo, `C:\SNIS2026` vuelve a ser un **enlace al servidor**. Un
  `Remove-Item -Recurse` sobre un enlace **borra al otro lado**: se llevaría los
  datos del centro. Comprobar SIEMPRE que es una carpeta de verdad antes de
  borrar nada.

**🔴 NORMA: los puestos llevan CUENTA LOCAL, nunca cuenta Microsoft** (08/08).

Se descubrió sin buscarlo, al cortarle la red a `olivos` para el simulacro de
SNIS: **Windows no dejaba iniciar sesión**. Piensa en lo que es eso en Capinota
un martes: se cae el internet, el médico llega, enciende su computadora **y no
puede entrar**. El servidor está bien, los datos están bien, y no puede
trabajar.

Se cambió a cuenta local y **se probó de verdad**: red cortada, cerrar sesión,
volver a entrar. Entra.

```
Configuración → Cuentas → Tu información
  → «Iniciar sesión con una cuenta local en su lugar»
  → pide la contraseña ACTUAL (la de Microsoft), la última vez
  → usuario: el MISMO de antes (aquí «dptos»), contraseña nueva local
  → «Cerrar sesión y acabar»
```

**Conservar el mismo nombre de usuario** es lo que hace que no se pierda nada.
Se comprobó después: siguen los cuatro iconos del escritorio, el enlace
`C:\SNIS2026` y las credenciales guardadas de `192.168.0.50` y `192.168.0.110`.

**Dos avisos:**

- **Cambiar a un correo de gmail NO lo arregla.** Una cuenta Microsoft con
  correo de gmail sigue siendo una cuenta de internet; el correo es solo la
  etiqueta. Lo que arregla es que sea **local**.
- Windows avisa por el camino de que **la llave de BitLocker está guardada en
  la cuenta Microsoft** y se quedará huérfana. Antes de omitir ese paso hay que
  tener la llave a salvo: se saca con
  `(Get-BitLockerVolume -MountPoint C:).KeyProtector`.

**Restauración de SALMI probada** (05/08): `redhornoma-respaldo --rescatar`
devolvió una copia y verificó 2193 pacientes, 17118 prestaciones.

---

## 6 · Qué ha FALLADO — no repetirlo

Esta es la sección que más ahorra. Todos estos errores **no daban error**:
parecían funcionar.

| Lo que se intentó | Qué pasó |
|---|---|
| `mkdir -p ~/.config/...` como root | dejó la carpeta del usuario a nombre de root; **KDE inservible** |
| Reescribir el XML de Dolphin con ElementTree | perdió el `xmlns` y dejó al usuario **sin barra lateral** |
| `función \| Out-Null` en PowerShell | se tragó **toda** la salida, no solo el valor devuelto |
| Mapear `S:` con el agente invitado | el agente es SYSTEM; **esa unidad no la ve nadie**. Usar rutas `\\servidor\...` enteras |
| Usuario `salmired` a secas | Windows lo busca en la máquina local → «contraseña no válida» aunque sea correcta. Va `SERVIDOR\salmired` |
| `regsvr32` sin `/s` a distancia | abre una ventana esperando un clic → **cuelga para siempre** |
| Llamar a `redhornoma-en-windows` con `bash` | es Python: da «from: orden no encontrada» y parece lentitud |
| Leer `receta/chroot/` durante la construcción | bloquea el desmontaje → **muere la ISO a los 20 minutos** |
| `lb clean --purge` | borra los 3 GB descargados en cada construcción |
| Rastrear `C:\` o todo el registro por PowerShell | tarda más de 2 minutos y agota el tiempo de espera |
| Sugerir la dirección del **Linux** del servidor | las carpetas están en su **Windows**, otra dirección |
| Confiar en que apt trae lo recién publicado | GitHub Pages cachea **10 minutos**, y sus construcciones pueden fallar |
| El botón **«Enlazar Estructura»** de SNIS | modifica el archivo y **deja los 39 enlaces igual**. Se atraganta con «Object variable not set». No insistir: usar el enlace de directorio |
| Escribir la ruta en el cuadro de SNIS del consultorio | `Conexion2026.bin` **está en el servidor y es compartido**: lo que se escribe en un puesto se lo cambia a todos |
| `Test-Path \\servidor\...` desde `redhornoma-en-windows` | el agente es SYSTEM y se identifica como **la máquina**: da «acceso denegado» aunque el usuario entre bien. **No es prueba de nada** |
| `redhornoma-entrar` desde el portátil para una máquina del servidor | solo abre máquinas **de la computadora donde se escribe**. Para las de otra: `virt-viewer -c qemu+ssh://flora@IP/system NOMBRE` |
| Dar por sano un SNIS porque «entró» | entra con las tablas rotas y enseña **datos incompletos** sin un solo aviso. Hay que mirar los datos, no la pantalla de inicio |
| Contar usuarios por el tamaño del `.ldb` | Access **no limpia la casilla del que se cayó**: siguió marcando «2 usuarios» con uno solo dentro. Sirve para ver que hay más de uno, no para contarlos |
| Leer las bases de SNIS sin pasar por SNIS | `snismain.mdb` **tiene contraseña**. Ni mdbtools ni Jet 4.0 entran. Los respaldos solo se pueden verificar por huella del archivo, no por contenido |
| Abrir `Conexion2026.bin` como texto | **es una base de Access**, no un archivo de texto. Volcarlo escupe 260 KB de basura |
| Dejar que el visor ajuste la pantalla solo | virt-viewer le **cambia la resolución al Windows** al mover el borde de la ventana. SNIS se vacía a media captura, deja el mes bloqueado y obliga a salir. Va `--auto-resize=never` (ya lo pone `redhornoma-entrar` desde 1.0.12) |
| Lanzar `virt-viewer` a pelo en Wayland | **violación de segmento** al arrancar. Necesita `GDK_BACKEND=x11` delante; `redhornoma-entrar` ya lo exporta |
| Abrir dos ventanas de la misma máquina | SPICE solo admite un visor: el segundo **se cierra con código 1 y sin decir nada**, y parece que el clic no hizo efecto |
| Comprobar el repositorio con `curl` | **`curl` no está instalado** en el portátil. `curl … \| grep` sale **vacío**, y un vacío se lee como «no hay nada publicado». Usar `wget -qO-`, que es lo que usa el propio guion |
| Dar por limpia una prueba porque SOAPS «borró» la consulta | **deja el correlativo puesto**. Se borraron 11 de 14 filas: las 3 del formulario 118 (el contador de consultas) se quedaron. Serían 3 atenciones fantasma en los informes. Hay que contar las filas antes y después |
| Buscar lo borrado en `se_datos_eliminados` | la tabla existe pero **está vacía**: SOAPS no archiva ahí lo que borra |
| Copiar los `.mdf` de SOAPS para respaldar | el motor los tiene abiertos y **la copia sale rota**. Va `BACKUP DATABASE … WITH CHECKSUM` y luego `RESTORE VERIFYONLY` |
| `sys.dm_db_partition_stats` con la columna `rows` | en SQL Server 2008 R2 se llama **`row_count`**. Con `rows` da «Invalid column name» |
| Usar `??` en un guion de PowerShell para Windows | ese Windows lleva **PowerShell 5.1** y no lo entiende: revienta el guion entero antes de ejecutar nada |
| `param(...)` en un guion enviado con `redhornoma-en-windows --guion` | no sobrevive al envío: «la expresión de asignación no es válida». Usar variables normales al principio |
| Dar por bueno un archivo recién generado en Windows | **estaba a medio escribir**. La primera versión anunció «14M» de un paquete que acabó pesando 36. Hay que esperar a que el tamaño **deje de crecer** y luego **abrirlo** para comprobarlo |
| `ZipFile::CreateFromDirectory` para armar el paquete | guarda las rutas con **barra invertida** (`SNIS2026\base.mdb`). El formato zip pide barra normal, y desde Linux eso no es una carpeta sino un archivo con una barra en el nombre. Hay que armarlo entrada por entrada con `.Replace('\','/')` — arreglado en respaldo **1.0.11** |
| `Add-Type -AssemblyName System.IO.Compression.FileSystem` a secas | `ZipArchiveMode` **no está ahí**, vive en `System.IO.Compression`. Hacen falta las dos |
| Publicar una carpeta de red **sin contraseña** para Windows | Windows 10 y 11 lo traen **bloqueado de fábrica** (`AllowInsecureGuestAuth`). Samba la sirve bien y Windows pide credenciales una y otra vez. Hay que ponerle cuenta y guardarla en cada puesto |
| Dar dos líneas seguidas cuando la primera abre una sesión SSH | euflo las pega juntas y **la segunda se pierde** al abrirse la conexión. Pasó dos veces el 08/08. Va **una sola línea**: `ssh -t usuario@IP 'sudo …'` — con `-t`, que sin él `sudo` no puede pedir la contraseña |
| Añadir el icono del instalador al escritorio | 🔴 **El error del 08/08, y de los buenos.** Se vio una captura del escritorio en vivo sin el icono y se concluyó que faltaba. **No faltaba:** Debian lo pone en cada inicio de sesión (`/etc/xdg/autostart/calamares-desktop-icon.desktop` → `add-calamares-desktop-icon`), y **tarda un segundo en aparecer** — la captura se tomó antes. Al añadir otro salieron **dos**; y peor: el de Debian **se quita solo al instalar** —Calamares borra `calamares-settings-debian`— mientras que el añadido a mano **sobrevivía en el sistema instalado, apuntando a un programa que ya no existe**. Un centro vería un icono muerto ofreciéndole instalar lo que ya tiene. Se deshizo entero: **no hay que poner nada ahí** |

| Meter la carpeta de otro proyecto entera en el paquete de respaldo | El primer `guardar-en-disco.sh` empaquetaba `cursalialinux` completa, y dentro tiene `cocina`: **16 GB de construcción** que se regeneran igual que el `chroot` de RedHornoma. El empaquetado no terminaba nunca. Se nombran las carpetas **una por una**, no la carpeta madre |
| Tirar a la basura el error de `rsync` con `2>/dev/null` | El guion decía solo «falló» y hubo que repetir el `rsync` a mano para enterarse de que el problema era **un único archivo** sin permiso de lectura (`nvram.fd`, que solo lee root) mientras los 93 MB restantes habían llegado bien. **Un fallo que no dice por qué obliga a investigar dos veces.** Es el mismo error que el `curl` silencioso de más arriba |

| Leer la respuesta de un programa en español | 🔴 **El fallo más silencioso hasta hoy.** `redhornoma-panel` preguntaba a `virsh` si el Windows estaba encendido y buscaba «running» en la respuesta. Pero esta distro está en español y virsh también: contesta **«ejecutando»**. El panel llevaba quién sabe cuánto diciéndole al servidor que sus programas estaban apagados **mientras llevaban horas funcionando** — y el panel es justo lo que alguien mira para saber si algo va mal. Lo mismo en `redhornoma-importar` ×2: `net-info` contesta «Activar: si» y no «Active: yes», así que avisaba «no pude encender la red» con la red encendida. **A cualquier programa cuya respuesta se vaya a LEER hay que hablarle en inglés: `LC_ALL=C`.** Para enseñársela a una persona, en español |
| Devolver el permiso de ejecución solo a `usr/bin` y `usr/sbin` | El constructor pone 644 a todo y luego devuelve el 755 a esas dos carpetas. El ayudante que repara el centro vive en `usr/lib/redhornoma`, así que **salió del paquete sin permiso de ejecución** y `pkexec` no puede lanzar lo que no es ejecutable: el botón «Arreglar» habría fallado en todos los centros, en silencio. Se vio abriendo el `.deb` con `dpkg-deb --contents` antes de publicar. Ahora el constructor marca ejecutable **todo archivo que empiece por `#!`**, esté donde esté |
| Avisar a un equipo de algo que no es asunto suyo | La primera prueba de «Algo no funciona» le dijo al portátil de administración «no hay ni un solo respaldo». Era verdad —el paquete le crea la carpeta vacía— y era ruido: ese portátil no guarda la información de ningún centro. **Un aviso que no corresponde enseña a ignorar los que sí.** Ahora solo se reclama respaldo al servidor, y a quien ya venía haciéndolos |

| Leer «falta la marca CORRECTO» como «está sin comprobar» | 🔴 **Mío, del 09/08, y encontrado por euflo al pulsar un botón.** `redhornoma-respaldo` verifica **siempre** nada más terminar. Si a una copia le falta `CORRECTO`, no es que nadie la haya mirado: es que **la miró y la rechazó**. El panel decía «sin verificar» y ofrecía `--verificar`, y «Algo no funciona» ofrecía lo mismo con un botón — un arreglo que daría exactamente el mismo resultado, **para siempre**. Ahora se dice «NO pasó la comprobación», y el porqué se saca de `verificacion.tsv`: si la copia tenía 1 paciente y 0 prestaciones, el problema no es el respaldo sino **qué máquina se está respaldando**, y eso no se arregla repitiéndolo |

| Poner una comprobación en un camino y no en el otro | 🔴 **El peor fallo del 09/08, y el más difícil de ver.** `--ahora` rechazaba un respaldo cuya base tenía 1 paciente y 0 prestaciones. `--verificar` **no llevaba esa comprobación**: solo comparaba con el anterior, y como el anterior estaba igual de vacío, no veía nada raro y **le ponía la marca de bueno**. El registro del portátil lo enseña entero: `07:01 SIN CONFIRMAR: …_0701` y `07:05 verificado correcto: …_0701`, la misma carpeta. Y `--verificar` era exactamente lo que el panel mandaba escribir, **así que el propio consejo del panel blanqueaba respaldos malos**: con la marca puesta, el panel lo enseña en verde y `--rescatar` restauraría desde él. Corregido en `respaldo 1.0.16` sacando la comprobación a una función que usan los dos caminos. **Una comprobación que no está en todos los caminos no es una comprobación** |

| Cambiar un `Depends` sin tocar la receta | Al añadir `pkexec` a `redhornoma-panel 1.0.5` no se declaró en `receta/config/package-lists/`. La ISO se habría construido **sin pkexec**, y en un centro recién instalado el botón «Arreglar» no habría podido pedir la contraseña: reparación imposible sin abrir una terminal, que es justo lo que este proyecto evita. **Lo cazó `comprobar-receta.sh`** antes de gastar los 12 minutos — el objetivo 10 ganándose el sueldo |
| Enseñar el final del informe en vez de la línea del fallo | `construir-iso.sh` decía «hay paquetes con nombres que no existen» y pegaba las últimas 20 líneas del informe. Esas 20 líneas eran el **resumen**: «155 declarados, 155 encontrados» y una lista de faltantes **vacía**. El mensaje contradecía a los números y la causa real quedaba fuera de pantalla. Ahora enseña las líneas con ✖ |
| Contar como sospechoso lo que nunca pudo tener la marca | `guardar-en-disco.sh` avisaba «2 copias sin la marca CORRECTO» en cada ejecución. Eran las `antes-del-rescate-*`: la foto de las bases VIVAS tomada justo antes de restaurar, para poder deshacer. No las hace el respaldo y nunca pasan por la verificación. Ahora se cuentan aparte |

| Probar siempre la ISO como CD-ROM | 🔴 **Nadie instala desde un CD.** En un centro se instala **desde un pendrive**, y son dos caminos de arranque distintos: el CD arranca por El Torito, el pendrive por el sector de inicio del propio disco. `probar-compatibilidad.sh` llevaba desde el principio conectando la ISO con `media=cdrom`, así que **el camino que se usa de verdad no se había probado nunca**. Al probarlo el 09/08 salió a la primera un defecto que llevaba meses: el menú de las máquinas antiguas enseñaba `RedHornoma ГÖ probar sin instalar` — isolinux pinta con la tabla de caracteres del PC de 1981 y no tiene el guion largo. En UEFI, que usa GRUB, se veía perfecto; por eso nadie lo había notado. **Se prueba el camino que usa la gente, no el cómodo** |

| Dar por copiado un archivo porque coincide el tamaño | 🔴 **Casi deja el respaldo mintiendo.** `guardar-en-disco.sh` decidía si la ISO ya estaba en el disco externo comparando **nombre y tamaño**. El 09/08 se construyeron dos ISOs el mismo día: la segunda arreglaba el menú de arranque. Mismo nombre —lleva la fecha, no la hora— y **exactamente el mismo tamaño, 2.843.770.880 bytes las dos**. Habría dicho «ya estaba» y el disco externo se habría quedado con la defectuosa **para siempre**, creyendo estar al día. Ahora compara la huella, que además sale gratis: `construir-iso.sh` ya la deja escrita al lado de la ISO |

| Dar por bueno el escritorio sin haberlo mirado nunca | Se sabía que la ISO instala y arranca, pero **nadie había visto la primera pantalla** de alguien que enciende RedHornoma. El 09/08, fotografiándola por primera vez, salió el «Centro de bienvenida» de KDE abierto encima, tapando los iconos. Llevaba ahí desde siempre. Lo trae `plasma-desktop` como dependencia, así que no se puede quitar el paquete: se desactiva su módulo de `kded` |

| Instalar un programa y dar por hecho que está activado | `os-prober` —el que encuentra Windows y lo pone en el menú de arranque— estaba en la receta desde el principio. Pero **Debian lo entrega desactivado** desde grub 2.06 (`GRUB_DISABLE_OS_PROBER=true`), una decisión pensada para servidores. Una ISO instalada en un portátil con Windows habría dejado un menú donde Windows no aparece. **Estar instalado no es estar funcionando** |

| Dar por hecho que una máquina arranca lo que se le instaló | 🔴 **El hueco más caro que queda.** Se verifica el respaldo leyéndolo, la ISO abriéndola, el pendrive releyéndolo… y nadie comprueba **lo único que decide si el trabajo sirvió: que al apagar y encender, la computadora entre**. El 09/08 RedHornoma quedó instalado perfectamente en un portátil ajeno y aun así arrancaba Ubuntu, y después Windows. **Solo se descubre apagando y encendiendo, con la máquina delante** — y en un centro rural eso es un viaje. Pendiente: que «Algo no funciona» mire si la primera entrada del arranque es la de RedHornoma |

| Dar por hecho que un programa del Ministerio se basta solo | 🔴 **SOAPS necesita MICROSOFT EXCEL instalado.** Los formularios 301a y 302a los construye abriendo `FORM301.xlt` y `FORM302.xlt`, que están en su propia carpeta. Sin Excel, `CreateObject("Excel.Application")` devuelve `80040154 Clase no registrada` — **el mismo texto exacto** que sale al registrar mal un componente, y por eso se pierde media tarde registrando cosas que ya estaban bien. **LibreOffice no vale**: SOAPS pide `Excel.Application` por su nombre. La prueba de que siempre hizo falta: la entrega a SEDES lleva `FORM301/302/305.xlsx` |
| Llamar «lo mismo» a dos cosas con el mismo número | 🔴 **Mío, del 10/08.** Claude escribió que «en Cochabamba funcionó porque aquella máquina ya tenía Office». Era una **deducción, no una medición, y era falsa**: euflo dijo que no recordaba haber instalado Office allá y tenía razón. Lo que pasa es que **el cierre de mes nunca se hizo en Cochabamba**. Cada «301a» del registro de Cochabamba es **el formulario del SNIS** —una pantalla donde se teclea, la de los 1080 píxeles—, no el informe que SOAPS exporta. Dos cosas distintas con el mismo número, confundidas. **Antes de escribir «allá funcionaba», comprobar que allá se hizo** |
| Restaurar un respaldo viejo encima de datos ya corregidos | Los **7 registros del año 2064** se corrigieron el 08/08. El 10/08 aparecieron otra vez en el SOAPS 7 de Hornoma: el `.wak` restaurado era del cierre de **julio**, anterior a la corrección. **Restaurar deshace lo arreglado después de esa foto.** Antes de restaurar, mirar qué arreglos son posteriores al respaldo |
| Cambiar la zona horaria y no volver a poner el reloj | Windows guarda la hora LOCAL y deduce la universal. Al corregir la zona de México (UTC-6) a Bolivia (UTC-4), el reloj **saltó de 01:16 a 03:16**. La zona queda bien y la hora queda mal. **Después de tocar la zona, siempre volver a poner la hora** |
| Suponer que el teclado del Windows es el del teclado físico | Las pulsaciones pasan tal cual del anfitrión a la máquina virtual: cada uno las interpreta con SU mapa. El Linux del `.101` usa el de España y el Windows tenía el Latinoamericano — de ahí que las tildes y la ñ no salieran. Los dos mapas tienen que coincidir |

**Y los errores de método, que son los que más se repiten:**

- **Alarmar sin comprobar.** Se dijo que la base estaba sin contraseña porque
  el registro mostraba el campo vacío. Al probarlo: *Login failed*. Sí la tenía.
- **Decir «esto no cambiará nada»** sin verificar si las herramientas estaban
  instaladas. Cambiaron la configuración del portátil de verdad.
- **Alarmar sin comprobar, otras dos veces el 08/08** — y las dos falsas:
  - «el guion de publicar cogerá la llave equivocada». Falso: busca la de
    RedHornoma por nombre, y además la configuración la fija. La comprobación
    con la que se dio la alarma era más tonta que el propio guion.
  - «el reloj del servidor está mal, marca las 3». **Eran las 3 de la
    madrugada**, y los tres relojes coincidían.

  Está escrito arriba desde el 07/08 y aun así se repitió dos veces en una
  jornada. **Mirar primero, hablar después.**

---

## 7 · Qué se planea hacer

### Necesita estar en Hornoma (cerrado hasta el lunes)

1. **Mirar la zona horaria del `.103`** ← lo primero. En Cochabamba estaba en
   zona de México, dos horas atrás, y **cada registro de SALMI llevaba una hora
   falsa**. El `.103` tiene los datos de verdad.
2. Averiguar por qué el `.101` lleva días sin responder.
3. Aplicar allá la receta de SOAPS 7 y montar el servidor.
4. **Poner en marcha allá el respaldo de SOAPS y SNIS.** Su Windows es físico y
   **no tiene agente invitado**, así que no se puede preparar desde fuera: hay
   que ir una vez con el ratón. Lanzando
   `sudo redhornoma-respaldo --preparar-programas` contra un Windows de red, el
   propio guion lo detecta e imprime los pasos exactos.
   *Antes de nada, mirar cuándo fue su último respaldo de SOAPS* — en
   Cochabamba llevaba cinco semanas y nadie lo sabía.

### Lo primero al retomar (12 de agosto)

0. **Comprobar que el `.101` despertó solo a la 1:00.** Es la prueba de fuego
   del horario de noche: si no volvió, euflo se queda sin servidor en cuanto
   viaje a Cochabamba.
   ```
   ssh -t hornoma@100.81.234.58 'cat /var/lib/redhornoma/horario.log'
   ```
   Ese registro dice, con hora exacta, qué hizo y **por qué** — incluidos los
   casos en que decidió NO apagarse. Si la máquina no contesta, es que no
   despertó, y entonces el horario no sirve todavía.
0b. **Decidir el apagado a las 6:00** en vez de las 4:00 (ver arriba: choca con
   la jornada de euflo). Es un comando:
   `sudo bash ~/horario-noche.sh --instalar --encender 01:00 --apagar 06:00`

### Se puede hacer desde Cochabamba

4. ~~SOAPS no entra en el respaldo automático.~~ ✅ **Resuelto el 08/08 con
   `redhornoma-respaldo 1.0.11`**, y probado restaurándolo. Ver la receta
   arriba. Lo de Hornoma queda en la lista de allá.
5. ~~Los 7 registros del año 2064.~~ ✅ **Corregidos el 08/08.** Ver abajo.
   La base **ya no tiene ni una fecha fuera de 2019-2026**.
6. **Que la resolución del puesto se ponga sola.** Ver la receta arriba: hoy hay
   que entrar a Windows y ponerla a mano, una vez por máquina. Debería hacerlo
   `redhornoma-cliente` o el asistente al preparar el puesto. Toca los
   objetivos 1 y 6.
   Lo difícil: el agente invitado corre como SYSTEM en la sesión 0 y **no puede
   cambiar la resolución de la sesión del usuario**. Haría falta una tarea
   programada que se ejecute al iniciar sesión dentro de Windows.
7. ~~Pruebas de compatibilidad.~~ ✅ **Los cinco perfiles pasados el 08/08**:
   `centro`, `antigua`, `moderna`, `segura` y `portatil-viejo`. Ver
   `pruebas/resultados.md`.
   *El banco se recalibró ese día con lo que euflo ve llegar a los centros: se
   añadió el perfil `centro` (4 GB, BIOS, SATA, medido sobre una máquina real) y
   `minima` pasó de 1,5 a 2 GB, porque de 1,5 ya no queda ninguna.*
   **Lo que sigue faltando es hierro de verdad**, con fabricantes concretos:
   firmware defectuoso, tarjetas de vídeo raras y discos muriéndose no los finge
   QEMU. Eso es todo lo que separa al objetivo 1 del 100%.
8. ~~Reconstruir la ISO.~~ ✅ **Hecha y probada el 08/08.**
9. ~~Los puestos no deben usar cuenta Microsoft.~~ ✅ **Arreglado en `olivos` el
   08/08 y probado.** Ver la receta abajo. **Queda como norma para cada puesto
   nuevo.**
10. **Un arreglo en la receta, SIN reconstruir todavía:** el instalador
   **parece colgado** en el primer paso y nada lo explicaba; ahora
   `ANTES-DE-INSTALAR.txt` lo dice con todas las letras. Entra en la próxima ISO.
   *(El «icono del instalador que faltaba» resultó no faltar — ver la tabla de
   fallos. Lo que se añadió se deshizo entero.)*
11. ~~Documentos del centro.~~ ✅ **Hecho, probado y publicado el 08/08**
   (`perifericos 1.0.8` la carpeta, `red 1.0.6` el icono). Ver la receta arriba.
   Falta decidir si esa carpeta **entra en el respaldo**: hoy no entra.
12. El disco `windows11-salud.qcow2` tiene BitLocker **con la llave puesta**:
   cualquiera que copie el archivo lo abre. Su contraseña de recuperación se
   sacó el 08/08 a `/home/euflo/llave-bitlocker-olivos.txt` en el portátil —
   **hay que llevarla a los dos discos externos y borrar el original**.

### Cómo quedó todo el 08/08 (para retomar sin adivinar)

En el **Windows del servidor** (`salud-servidor`, 192.168.0.50):

- recurso compartido `SNIS` → `C:\SNIS2026`, con `salmired` y `server-cbba`
- `Conexion2026.bin` **ya no dice `C:\SNIS2026`, dice `\\192.168.0.50\SNIS`**,
  porque se escribió desde el consultorio antes de dar con la solución buena.
  Funciona así, pero conviene decidir si se devuelve a la ruta local
- copias: `C:\RESPALDO-SNIS-20260807` (tomada con las bases **abiertas**, no
  fiarse), `C:\RESPALDO-SNIS-20260807-CERRADA` (limpia, verificada archivo a
  archivo) y `C:\RESPALDO-SNIS-20260807-ANTES-PRUEBA` (**la más reciente**,
  tomada en frío antes de la prueba de dos puestos y verificada por SHA256)
- se reinició con las bases abiertas y quedaron `.ldb` huérfanos; se borraron
  con todo cerrado y los datos salieron intactos
- el 301a de **agosto 2026 quedó limpio** el 08/08: se borró el registro entero
  con el botón `Eliminar`, desde el puesto y con el servidor cerrado. Agosto no
  tenía ni un registro real, lo confirmó euflo. Si aparece algo ahí, no es
  nuestro
- **al reiniciar el servidor con las bases abiertas vuelven a quedar `.ldb`
  huérfanos.** Pasó el 07/08 y otra vez el 08/08. Se quitan con todo cerrado y
  los datos salen intactos, pero conviene mirarlo después de cada reinicio
- **SOAPS**: `C:\SOAPS7`, SQL Server 2008 R2 Express instancia `SUIS`, tres
  bases en `C:\SOAPS7\BD\`. Copia manual del 08/08 en
  `C:\RESPALDO-SOAPS-20260808` (además de la automática de cada noche)
- **la tarea nocturna ya está puesta**: «RedHornoma - Respaldo de programas»,
  cada día a las 02:00, ejecuta `C:\ProgramData\RedHornoma\respaldo-programas.ps1`
- la base de SOAPS quedó con **exactamente las 113.456 filas** de `SE_DATOS` que
  tenía antes de la prueba de los dos puestos: se metieron 14 filas y se
  quitaron las 14

En el **puesto de pruebas** (`salud-puesto` del portátil, se llama `olivos`):

- **no tiene IP propia en la red del centro.** Está en la red interna del
  portátil (192.168.122.2, tarjeta `default`) y sale al servidor **a través del
  portátil**. Por eso el servidor lo ve como **192.168.0.106**, que es la IP del
  cable del portátil, no la suya. No confundirlas

- icono «SNIS del centro» en el escritorio público → `\\192.168.0.50\snis\snis_2026.exe`
- enlace de directorio `C:\SNIS2026` → `\\192.168.0.50\SNIS`
- **no tiene SNIS instalado**, y no le hace falta

- resolución puesta en **1280 × 1024**, que es el mínimo real de SNIS. Con
  `redhornoma-entrar` 1.0.12 Windows se la queda entre reinicios
- entra con una cuenta Microsoft ligada a un teléfono («voce nava»), no con la
  cuenta local `dptos` de antes. **Esa es la contraseña que pide al arrancar**

**Todo lo que quedó a medias el 07/08 está cerrado.** Se borró el 301a de
agosto, se publicó `virtualizacion 1.0.12`, y se probó y aprobó lo de 1280×1024.
Lo único que sigue abierto de aquel día es la licencia de Windows, aquí debajo.

*Palanca sin probar para el tamaño:* el propio SNIS trae `Tamaño Letra:
Normal/Mediano/Grande` arriba a la izquierda.

**Windows de `olivos` sin activar — camino agotado (08/08).** No estorba: SALMI,
SNIS y SOAPS funcionan igual; solo hay marca de agua y no deja cambiar el fondo.

```
Windows 11 Pro · compilación 26200
canal      RETAIL      ← se puede mover de máquina, y vale en virtual
error      0xC004C060  el servidor de internet se niega
motivo     0xC004F034
últimos 5  W8F9G       coinciden con el serial de euflo
```

La clave **está bien puesta** — los últimos cinco coinciden con el serial de
euflo. **Todo lo probado el 08/08, y todo descartado:**

| Se intentó | Qué dijo |
|---|---|
| Volver a meter el serial | lo acepta, pero sigue en 0xC004C060 |
| `slui 4` (activación por teléfono) | **ya no existe** en la compilación 26200 |
| Portal de Activación de Microsoft | es solo para **licencias por volumen y agentes**, no para retail |
| «Solución de problemas» → «cambié el hardware» | *«No se puede reactivar Windows desde estos dispositivos»* — con dos cuentas Microsoft distintas |
| El portal, metiendo el id. de instalación | 🔴 ***«el producto no es válido en nuestros registros. Devuelva el software al revendedor»*** |

**Ese último mensaje es la respuesta de fondo:** Microsoft no reconoce la clave
como una licencia legítima. Es lo que responde ante claves compradas a
revendedores que venden otra cosa haciéndola pasar por retail. Que el canal
salga como RETAIL y que Windows la acepte **no prueba que sea legítima**: eso
solo dice qué tipo de clave dice ser.

Lo que queda es de euflo, no técnico: **reclamar a quien se la vendió** —guardar
captura del mensaje—, o comprar una licencia buena. Y **no hace falta para
trabajar**: Windows sin activar funciona igual.

*Nota para cualquier sesión futura:* **no proponer programas para saltarse la
activación.** Ni son seguros en una máquina donde viven datos de pacientes, ni
es lo que euflo quiere.

Pendientes menores, del 07 y el 08:

- `redhornoma-en-windows --estado` **no mira `C:\SNIS2026`** en «programas de
  salud»: dice que no está cuando sí está
- `redhornoma-entrar` no sabe abrir máquinas de otra computadora, y la regla de
  oro es trabajar desde el portátil. Para las de otra máquina, a mano:
  `virt-viewer -c qemu+ssh://flora@IP/system NOMBRE`
- SNIS no es un programa, son **16**: `snis_2026.exe` es el menú, y los
  formularios (`Form301v2026`…`Form305v2026`), `recepcion`, `cobertura`,
  `transferencia`, `gen_rep26` son ejecutables aparte
- `redhornoma-en-windows --guion` **escupe un rastreo de Python** cuando el
  archivo no existe, en vez de decir «no encuentro X»
- **todos los puestos entran a SQL Server como `sa`**, el administrador del
  motor. Es como está hecho SOAPS y no se puede cambiar sin tocar el programa
  del Ministerio, pero conviene tenerlo presente
- SOAPS abre **~50 conexiones de golpe** al arrancar y las deja dormidas. Es
  normal, no es una fuga
- el portátil tiene **dos llaves GPG**: `FE37…` de cursalialinux y `D867…` de
  RedHornoma. El guion de publicar coge la buena por nombre, y además
  `scripts/repositorio.conf` la fija. **No tocar eso**

### Más adelante, decisión de euflo

**SIAL y los programas de segundo nivel** — expresamente **después** de que
todo lo anterior funcione a la perfección. No proponerlo antes.

---

## Cómo trabajar en este proyecto

```
1. Preguntar a la máquina, nunca suponer
2. Probar antes de empaquetar; empaquetar antes de la ISO
3. Subir el número de versión en cada cambio, o nadie se entera
4. Que ninguna herramienta mienta: mejor «sin dato» que un verde falso
5. Cada comando, con la máquina donde se ejecuta y qué debe salir
6. Un respaldo no está probado hasta que se ha restaurado
7. Antes de escribir en la base de un centro: copia verificada, y luego
   contar las filas antes y después
```

**Y una que se aprendió a base de repetirla:** *comprobar antes de alarmar.*
Tres veces se ha dicho aquí que algo estaba roto sin haberlo mirado, y las tres
era mentira. Una alarma falsa cuesta más que el silencio: hace perder la
confianza en las que sí son de verdad.
