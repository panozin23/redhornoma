# TRASPASO — RedHornoma

> **Para quien llegue nuevo a este proyecto**, sea una persona o una sesión de
> Claude que empieza de cero. Léelo entero antes de tocar nada: está para que
> no se repitan errores que ya costaron horas.
>
> **Última actualización:** 2026-08-07
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

Los siete objetivos, en sus palabras:

1. Que funcione en cualquier máquina, antigua o moderna
2. Meter información desde cualquier máquina de la red interna
3. Un servidor con SALMI, SOAPS, SNIS (y más adelante SIAL y los de segundo nivel)
4. Virtualización: Linux con Windows dentro
5. Canal de comunicación entre Windows y Linux
6. Sin código: todo gráfico, de jalar y soltar
7. Distro en español

---

## 2 · Estado actual

| # | Objetivo | |
|---|---|---|
| 4 | Virtualización | 🟢 95% |
| 5 | Canal Windows ↔ Linux | 🟢 95% |
| 1 | Compatibilidad | 🟢 90% |
| 2 | Meter información en red | 🟢 90% |
| 7 | Distro en español | 🟢 90% |
| 6 | Todo gráfico | 🟢 85% |
| 3 | Servidor con los programas | 🟡 50% |

**Publicado y funcionando:**

```
ISO        redhornoma-0.1-20260806-amd64.iso
paquetes   base 1.0.1 · completo 1.0.32 · panel 1.0.4 · perifericos 1.0.6
           red 1.0.5 · respaldo 1.0.9 · virtualizacion 1.0.11
17 herramientas, 6 con ventana propia
```

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
  */usr/bin/             las 17 herramientas
scripts/
  construir-iso.sh       ~12 min · comprueba la receta antes de gastar tiempo
  construir-paquetes.sh  construye Y copia a la receta, con verificación
  publicar-repositorio.sh  firma, sube y ESPERA a que GitHub lo sirva
  probar-compatibilidad.sh  finge 5 máquinas distintas con QEMU
repositorio/             el APT propio (git aparte, rama gh-pages)
pruebas/resultados.md    dónde se ha probado la ISO de verdad
documentacion/           SALMI-EN-RED.md · INSTALAR-WINDOWS.md
```

**Regla del proyecto:** nada se instala a mano dentro del sistema. Si algo
hace falta, se declara en la receta o en un paquete. **Un parche es código que
solo existe en una máquina.**

---

## 4 · Qué ha cambiado (5 al 7 de agosto)

- **Repositorio APT propio** en la rama `gh-pages` de `panozin23/redhornoma`,
  firmado con llave propia. Dos vías: la ISO para máquinas nuevas, `apt` para
  las que ya trabajan. `redhornoma-base` trae el origen configurado dentro.
- **El respaldo avisa.** Cada copia deja una señal fechada en
  `drive:SENALES-REDHORNOMA`; `redhornoma-vigilar` las lee todas.
- **SOAPS 7 funciona en red** sin su instalador (receta abajo).
- **Seis herramientas con ventana**, incluido un asistente de puesta en marcha.
- **El servidor anuncia dónde está su Windows** (`windows=` en avahi).
- La ISO pasó de 90 a 12 minutos y comprueba su propia huella.

---

## 5 · Qué se ha intentado y SÍ funcionó

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

**Restauración probada** (05/08): `redhornoma-respaldo --rescatar` devolvió una
copia y verificó 2193 pacientes, 17118 prestaciones.

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

**Y dos errores de método, no de código:**

- **Alarmar sin comprobar.** Se dijo que la base estaba sin contraseña porque
  el registro mostraba el campo vacío. Al probarlo: *Login failed*. Sí la tenía.
- **Decir «esto no cambiará nada»** sin verificar si las herramientas estaban
  instaladas. Cambiaron la configuración del portátil de verdad.

---

## 7 · Qué se planea hacer

### Necesita estar en Hornoma (cerrado hasta el lunes)

1. **Mirar la zona horaria del `.103`** ← lo primero. En Cochabamba estaba en
   zona de México, dos horas atrás, y **cada registro de SALMI llevaba una hora
   falsa**. El `.103` tiene los datos de verdad.
2. Averiguar por qué el `.101` lleva días sin responder.
3. Aplicar allá la receta de SOAPS 7 y montar el servidor.

### Se puede hacer desde Cochabamba

4. Probar **SNIS**.
5. Escribir desde dos puestos a la vez **en SOAPS** (en SALMI ya está probado).
6. Rellenar las 3 pruebas de compatibilidad que faltan: `minima`, `moderna`,
   `portatil-viejo`.
7. El disco `windows11-salud.qcow2` tiene BitLocker **con la llave puesta**:
   cualquiera que copie el archivo lo abre.

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
```
