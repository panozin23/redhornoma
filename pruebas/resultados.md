# Dónde se ha probado RedHornoma

Cada línea es una prueba real, no una suposición.
Generado por `scripts/probar-compatibilidad.sh`, y completado a mano cuando la
ventana se cierra antes de que el guion llegue a preguntar.

| Fecha | Máquina fingida | ISO | Resultado | Detalle |
|---|---|---|---|---|
| 2026-08-18 | **segura** | redhornoma-0.1-20260814 | ✅ instala y arranca | **Arranque Seguro activado, tal como viene un equipo comprado hoy.** Arrancó la ISO **sin un solo aviso** y el instalador dejó 8,62 GB en el disco. Comprobado sin depender de lo que se ve en pantalla: el firmware (`OVMF_CODE_4M.ms.fd`, el que lleva las llaves de Microsoft) quedó con `\EFI\Debian\shimx64.efi` anotado como arranque — o sea que el instalador escribió el gestor de arranque **firmado**, que es lo único que el Arranque Seguro acepta. |
| 2026-08-18 | **centro** | redhornoma-0.1-20260814 | ✅ instala y arranca | **La ISO nueva, la que lleva Tailscale y las herramientas de agosto.** BIOS antiguo, 4 GB, 2 núcleos core2duo, disco SATA. Instaló y arrancó DE LO INSTALADO **teniendo el CD puesto y con prioridad de arranque** — o sea que el instalador dejó bien el arranque. Comprobado por tres caminos: el disco seguía escribiéndose con el sistema en marcha (+192 y +448 KB cada pocos segundos, cosa que un sistema en vivo nunca hace), pidió la contraseña creada durante la instalación, y `redhornoma-preparar` respondió con su lista dentro del sistema recién instalado. Disco en 9,2G. |
| 2026-08-06 06:50 | antigua | redhornoma-0.1-20260806 | ✅ instala y arranca | BIOS antiguo, 2 GB, core2duo, disco IDE. Instaló, y lo instalado arrancó solo sin el CD puesto. |
| 2026-08-06 06:31 | segura | redhornoma-0.1-20260806 | ✅ instala y arranca | Arranque Seguro activado. Instaló y arrancó lo instalado, **sin ningún aviso**. Disco 8,4 GB. |
| 2026-08-08 08:41 | minima (1,5 GB) | redhornoma-0.1-20260808 (daf365…) | ⚠️ arranca, se abandonó | Arrancó e instalaba, pero **inutilizable de lento**: 14 minutos solo para llegar al formulario de usuarios, con el procesador clavado al 100%. Se paró a propósito, no falló. Por eso el perfil pasó a 2 GB: máquinas de 1,5 GB ya no llegan a un centro. |
| 2026-08-08 08:57 | **centro** | redhornoma-0.1-20260808 (daf365…) | ✅ instala y arranca | **La máquina que de verdad hay en los centros**: BIOS antiguo, 4 GB, 2 núcleos, disco SATA — medida sobre `servidor-ciudad`. Instaló en unos minutos y **arrancó de lo instalado**. Comprobado desde fuera: el disco quedó en 8,8 GB y seguía escribiéndose con el sistema en marcha, cosa que un sistema en vivo no hace. |
| 2026-08-08 12:40 | moderna | redhornoma-0.1-20260808 (4f034f…) | ✅ instala y arranca | UEFI normal, 4 GB, 4 hilos, disco virtio. Instaló y **arrancó de lo instalado**: disco de 8,7 GB en uso, con el CD todavía puesto y el orden de arranque en «disco primero». |
| 2026-08-08 13:22 | portatil-viejo | redhornoma-0.1-20260808 (4f034f…) | ✅ instala y arranca | UEFI de primera generación, 3 GB, 2 hilos, procesador Nehalem, disco SATA. Instaló y **arrancó de lo instalado**: disco de 9,5 GB en uso. |

## Los cinco perfiles, al 2026-08-08

```
centro          ✅   la máquina que de verdad hay en los centros
antigua         ✅   PC de escritorio de 2011
moderna         ✅   equipo de hoy, UEFI normal
segura          ✅   de fábrica, con Arranque Seguro
portatil-viejo  ✅   UEFI de primera generación
minima          ⚠️   1,5 GB: arranca pero es inutilizable. Perfil recalibrado a 2 GB
```

**Lo que sigue faltando, y QEMU no lo puede fingir:** hierro de verdad, con
fabricantes concretos. Firmware defectuoso, tarjetas de vídeo raras y discos
que se están muriendo solo se ven en una máquina prestada.

## Lo que destapó la prueba de `moderna`, y confirmó `portatil-viejo`

En el escritorio del sistema **ya instalado** aparecía «Instalar RedHornoma».

Venía de un icono añadido a mano en la receta esa misma mañana. Debian ya ponía
el suyo en el sistema en vivo —y lo retira solo al instalar, porque Calamares
borra `calamares-settings-debian`—, pero el añadido **sobrevivía a la
instalación** y apuntaba a un programa que ya no existía. Un centro habría visto
un icono muerto ofreciéndole instalar lo que ya tiene. Se deshizo entero.

**Sin arrancar la ISO no se habría visto**, y ninguna revisión de código lo
habría encontrado: el archivo era correcto, estaba bien escrito y era
ejecutable. El problema era *cuándo dejaba de ser correcto*.
