# RedHornoma

Sistema operativo para centros de salud. Debian 13 con virtualización de
Windows, red interna servidor/clientes y respaldo automático, para que los
programas del Ministerio —SALMI, SNIS, SOAPS— funcionen bien y no se pierda
información.

**Proyecto independiente.** No está afiliado ni respaldado por ninguna
institución pública.

---

## La regla del proyecto

> Nada se instala a mano dentro del sistema. Si algo hace falta, se escribe en
> una lista de `receta/config/package-lists/`.

Así la ISO se puede rehacer desde cero, en cualquier equipo, en cualquier
momento. Sin esa regla, un proyecto como este acaba viviendo en una carpeta que
nadie sabe reconstruir.

---

## Construir la ISO

Tres pasos. El primero solo se hace una vez por equipo.

```bash
# 1 · Preparar el equipo (una sola vez)
bash scripts/preparar-equipo.sh              # mira e informa
sudo bash scripts/preparar-equipo.sh --aplicar

# 2 · Comprobar la receta (20 segundos, sin sudo)
bash scripts/comprobar-receta.sh

# 3 · Construir (40-90 minutos, 3 GB de descarga)
sudo bash scripts/construir-iso.sh
```

La ISO queda en `isos/` con su versión, su fecha y su huella SHA-256.

---

## Las carpetas

| | |
|---|---|
| `PLAN.md` | el plan completo del proyecto — leer primero |
| `receta/` | la receta de `live-build`: **de aquí sale todo** |
| `receta/config/package-lists/` | los programas declarados, por temas |
| `paquetes/` | el código de los `.deb` de RedHornoma |
| `scripts/` | construir, comprobar, publicar |
| `documentacion/` | guías en español para el personal de los centros |
| `marca/` | logos, colores, diapositivas del instalador |
| `isos/` | las imágenes generadas |

---

## Qué hay en la receta

137 programas declarados, agrupados por para qué sirven:

| Lista | Para qué |
|---|---|
| `00-sistema` | arranque, controladores, discos, hora |
| `10-escritorio` | KDE Plasma mínimo |
| `20-idioma` | todo en español |
| `30-virtualizacion` | QEMU, libvirt, UEFI, TPM — el corazón |
| `40-red` | SSH, carpetas compartidas, descubrimiento |
| `50-perifericos` | impresoras, escáneres, pendrives |
| `60-energia` | baterías y apagones |
| `70-utilidades` | lo que usan las herramientas propias |
| `80-instalador` | Calamares |

Cada lista lleva escrito **por qué** está cada cosa. Eso también es parte de la
receta.

---

## Estado

**Fase 0 — Cimientos: cerrada el 28 de julio de 2026.**

Primera ISO construida y probada: 2,7 GB en 16 minutos, 143 paquetes declarados
que se convierten en 2.313 instalados, arranca hasta el escritorio en español,
con Calamares y toda la virtualización dentro. El arranque seguro se verificó
byte a byte contra el shim firmado.

**Fase 1 — Virtualización: cerrada el 29 de julio de 2026.**

Probada en dos máquinas deliberadamente distintas:

| | Portátil HP | PC de escritorio |
|---|---|---|
| Procesador | AMD Ryzen 5 5500U, 12 hilos | Intel Pentium G630 de 2011, 2 hilos |
| Disco | NVMe | mecánico |
| Recomendación | Windows 11 | Windows 10 |

Probar en la máquina vieja encontró cuatro fallos que no se veían de otra
forma: cuatro procesadores pedidos a una máquina de dos, Windows 11
ofrecido donde su instalador lo rechaza, `qemu-system-modules-spice`
ausente de la receta, y la caída a VNC funcionando de verdad.

### Las herramientas

| | |
|---|---|
| `redhornoma-informe` | examina un equipo y da un veredicto |
| `redhornoma-probar-equipo` | ¿puede ejecutar Windows? Sin necesitar imagen ni licencia |
| `redhornoma-windows` | crea la máquina virtual, adaptada a lo que hay |
| `redhornoma-virtio-reducido` | deja el CD de controladores en ~50 MB |

Cada prueba se anota sola en `/var/lib/redhornoma/equipos-probados.tsv`.

**Fase 2 — Red del centro: siguiente.**

El plan completo, con las siete fases, está en [PLAN.md](PLAN.md).

---

## Construido sobre

Debian, KDE, GNU, QEMU, libvirt, Calamares y el trabajo de mucha gente que
publicó lo suyo para que otros pudieran usarlo. Software libre.

---

## Licencia

**GPL-3.0** — ver [LICENSE](LICENSE).

Eres libre de usar RedHornoma, copiarlo, estudiarlo y modificarlo. Si lo
mejoras y lo repartes, tienes que compartir esas mejoras con la misma
libertad. Es la misma familia de licencias que Debian y KDE, los proyectos
sobre los que está construido.

**Windows no se incluye ni se reparte.** Cada centro debe usar sus propias
licencias. RedHornoma se limita a alojar el sistema que el centro ya tiene
derecho a usar.
