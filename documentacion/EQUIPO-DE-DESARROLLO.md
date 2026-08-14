# El equipo donde se construye RedHornoma

**Esto NO va dentro de la ISO.** Son las herramientas que hacen falta en la
máquina que construye la distro y los paquetes — hoy, el portátil de euflo.

Va aparte a propósito. Un centro de salud no necesita compiladores ni
editores de código, y meterlos en la ISO la engorda, alarga la instalación
y da más superficie que mantener en máquinas que nadie vigila.

Es la otra mitad del **objetivo 10**: la receta dice cómo se hace la
distro, y este archivo dice qué hace falta para poder hacerla. Sin los dos,
«rehacer desde cero» depende de que alguien se acuerde.

---

## Lo imprescindible

```
sudo apt install live-build debootstrap squashfs-tools xorriso genisoimage \
                 dpkg-dev gnupg git rsync python3 shellcheck
```

| paquete | para qué |
|---|---|
| `live-build` | construye la ISO — es el motor de toda la receta |
| `debootstrap` | monta el sistema base de Debian dentro de la ISO |
| `squashfs-tools` | comprime ese sistema para que quepa |
| `xorriso` | escribe la imagen ISO arrancable |
| `genisoimage` | lo mismo, cuando xorriso no basta |
| `dpkg-dev` | `dpkg-scanpackages`, que arma el índice del repositorio APT |
| `gnupg` | firma el repositorio con la llave del proyecto |
| `git` | el código y su historia |
| `rsync` | copiar respaldos y publicar |
| `python3` | los guiones de `scripts/` que hablan con el Windows |
| `shellcheck` | revisa las herramientas antes de publicarlas |

## Para probar sin quemar un pendrive

```
sudo apt install qemu-system-x86 qemu-utils
```

`scripts/probar-compatibilidad.sh` arranca la ISO en seis máquinas
inventadas —BIOS antiguo, UEFI, arranque seguro, poca memoria— y dice en
cuáles instala. Es lo que sostiene el **objetivo 1** sin tener que
conseguir seis computadoras prestadas.

---

## Antes de construir, siempre

```
bash scripts/comprobar-receta.sh
```

Tarda veinte segundos y evita perder una hora. Comprueba tres cosas:

1. **que cada paquete declarado exista** con ese nombre en Debian 13
2. **que lo que piden los paquetes propios esté declarado**
3. **que cada orden que usan las herramientas pueda venir de la receta** —
   esta nació el 14/08/2026 y encontró cinco agujeros a la primera:
   `psmisc`, `xdg-user-dirs`, `xorriso`, `genisoimage` y **`tailscale`**

El de Tailscale era el grave. Se instalaba a mano en cada máquina y no
estaba en la receta: **una ISO reconstruida desde cero salía sin el enlace
entre centros**, y con ella se caía el objetivo 11 entero, sin que nada
avisara.

---

## Lo que hay en el portátil y NO hace falta

Para que nadie lo confunda con parte del proyecto: el portátil lleva
además Docker, PHP, Node, editores de código y programas de edición de
vídeo, audio e imagen. **Nada de eso pertenece a RedHornoma.** Son de
euflo y de otros trabajos.

Si algún día se reconstruye el equipo de desarrollo, con la lista de
arriba basta.
