# RedHornoma — Plan del proyecto

**Borrador 1 · 28 de julio de 2026**
Para revisar y corregir antes de escribir una sola línea de código.

---

## 1. Qué es RedHornoma

Un sistema operativo para **centros de salud**, construido sobre Debian 13,
cuyo único trabajo es que los programas del Ministerio —SALMI, SNIS, SOAPS y los
que vengan— funcionen bien, en red, y no se caigan nunca.

No es una distribución de propósito general. Es una **herramienta de trabajo**.

### Qué no es

- No es cursalialinux con otro nombre. Comparte código, no objetivos.
- No es un proyecto oficial de ninguna institución. Es independiente, y así
  debe decirlo en todas partes.
- No reemplaza a los programas del Ministerio. Los aloja y los cuida.

### La frase que lo resume

> Que la enfermera del consultorio 3 encienda su computadora, vea SALMI, y no
> tenga que aprender nada nuevo. Y que si algo se rompe, la información esté a
> salvo.

---

## 2. A quién sirve

Dos escenarios muy distintos. El sistema tiene que servir a los dos.

| | Centro de primer nivel | Hospital de segundo nivel |
|---|---|---|
| **Ejemplo** | centros rurales de Capinota | Hospital de Capinota |
| **Computadoras** | 2 a 5 | ~30 |
| **Luz eléctrica** | se corta | estable |
| **Internet** | malo o ninguno | aceptable |
| **Quién administra** | nadie — hay que ir | puede haber alguien |
| **Instalación** | pendrive, una por una | por red, en tanda |
| **Servidor** | una PC normal | máquina dedicada |

El diseño se hace pensando en el **caso difícil**: el centro rural sin internet,
sin técnico y con apagones. Si funciona ahí, funciona en el hospital.

---

## 3. Principios que no se rompen

Estas son las reglas aprendidas a golpes en cursalialinux. No son decoración.

### 3.1 Preguntar a la máquina, nunca suponer

Cada equipo se examina antes de configurarlo: qué acepta libvirt, qué video,
qué CPU, qué red. Ocho errores seguidos vinieron de diseñar suponiendo.

### 3.2 Todo se rehace desde una receta

Nada de carpetas modificadas a mano. Cada programa instalado está **declarado
en una lista**. La ISO se genera con `live-build` desde esa receta, y cualquiera
—incluido tú dentro de dos años— puede rehacerla desde cero.

Esto es lo que a cursalialinux le falta y aquí se hace bien desde el día uno.

### 3.3 Se entrega mascadito

El usuario no escribe comandos. No edita archivos. No elige entre opciones que
no entiende. Todo con el ratón, en español, con palabras normales.

### 3.4 La información es lo primero

Antes que la velocidad, antes que la comodidad, antes que lo bonito: **que no se
pierda nada**. Un respaldo que nunca se ha restaurado no es un respaldo.

### 3.5 Nada de nombres ajenos

Los mensajes se dirigen al usuario. No se nombra ni se critica a otras
plataformas ni a otros programas.

---

## 4. Arquitectura

### 4.1 Los tres papeles

Al instalar, el sistema pregunta una sola cosa: **qué va a ser esta máquina.**

```
┌─────────────────────────────────────────────────────────┐
│  SERVIDOR                                               │
│  Guarda la base de datos de todo el centro.             │
│  No se mueve, no se duerme, va por cable.               │
│  También se usa como puesto de trabajo normal.          │
└─────────────────────────────────────────────────────────┘
                          ▲
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  PUESTO       │ │  PUESTO       │ │  PUESTO       │
│  Consultorio  │ │  Farmacia     │ │  Estadística  │
└───────────────┘ └───────────────┘ └───────────────┘

┌─────────────────────────────────────────────────────────┐
│  ADMINISTRACIÓN  (opcional)                             │
│  La computadora de quien mantiene todo esto.            │
│  Ve el estado de todas, entra a todas, arregla todas.   │
└─────────────────────────────────────────────────────────┘
```

**Un solo instalador, tres respuestas posibles.** Todo lo demás se configura
solo según lo que se responda.

### 4.2 Los paquetes

El sistema son piezas separadas que se instalan por encima de un Debian limpio:

| Paquete | Qué trae |
|---|---|
| `redhornoma-base` | escritorio, idioma, tipografías, controladores, aspecto |
| `redhornoma-virtualizacion` | QEMU, KVM, libvirt, OVMF, TPM, controladores VirtIO |
| `redhornoma-windows` | asistente de instalación de Windows 7/8.1/10/11 |
| `redhornoma-servidor` | red en puente, arranque automático, sin suspensión |
| `redhornoma-puesto` | modos de arranque, conexión al servidor |
| `redhornoma-respaldo` | copias, verificación y rescate |
| `redhornoma-perifericos` | pendrives, impresoras, escáneres, carpeta compartida |
| `redhornoma-energia` | batería, apagado ordenado, protección ante cortes |
| `redhornoma-panel` | la pantalla única de control |
| `redhornoma-red` | descubrir y administrar las demás máquinas |
| `redhornoma-docs` | guías imprimibles para el personal |
| **`redhornoma-completo`** | **lo instala todo de una vez** |

**Por qué así:** se corrige un paquete, se publica, y todos los centros lo
reciben con `apt`. Sin rehacer la ISO de 3,5 GB. Sin viajar a Capinota.

### 4.3 De dónde salen las actualizaciones

Un repositorio APT propio, firmado, alojado en GitHub Pages — la misma
mecánica que ya funciona en cursalialinux.

Para los centros sin internet: un **espejo local**. Una máquina del centro
guarda los paquetes y las demás se actualizan de ella. Se alimenta con un
pendrive que alguien lleve una vez al mes.

---

## 5. Las piezas, una por una

### 5.1 Virtualización de Windows

**Estado: ya resuelto en cursalialinux. Se traslada.**

Lo que ya funciona y se reaprovecha:

- Perfiles por versión de Windows: el 7 con BIOS antiguo, el 11 con UEFI, TPM y
  arranque seguro
- Detección de capacidades: se le pregunta a libvirt qué acepta esta máquina
  antes de crear nada (SPICE o VNC, qxl o vga, Intel o AMD)
- Controladores VirtIO reducidos de 754 MB a 52 MB
- Arranque automático de los servicios cuando están dormidos

**Lo que falta:**

- Probarlo en más hardware distinto. Los centros de Capinota tendrán
  computadoras que ni tú ni yo hemos visto.
- Un catálogo de máquinas probadas: «este modelo funciona, este da problemas y
  se arregla así».

### 5.2 Respaldo automático y recuperación probada 🥇

**La pieza más importante del proyecto.**

#### Qué se guarda

| | Cada cuánto | Dónde |
|---|---|---|
| Base de datos de los programas | cada noche | disco interno + externo + otra PC |
| Disco completo del Windows | cada semana | disco externo |
| Configuración del sistema | cuando cambia | con el resto |

#### Cómo se guarda sin apagar nada

Se instala dentro de Windows el **agente invitado** (`qemu-guest-agent`). Eso
permite congelar los discos un instante y sacar la copia con la máquina
encendida, sin riesgo de que quede a medias.

#### Cuánto se conserva

```
7 copias diarias  ·  4 semanales  ·  12 mensuales
```

Las viejas se borran solas. Ocupa lo que ocupa, ni más.

#### La parte que casi nadie hace

**Verificación automática.** Una vez por semana, el sistema:

1. Toma la última copia
2. La restaura en una máquina virtual de prueba
3. Comprueba que arranca y que la base de datos abre
4. La borra
5. Anota el resultado

Si falla, avisa. Así el día que haga falta de verdad, ya sabes que funciona.

#### El rescate

Un solo comando, documentado y probado, que en **menos de una hora** deja el
servidor funcionando en otra computadora:

```
redhornoma-rescatar --desde /media/respaldo --a esta-maquina
```

#### La copia que sale del edificio

Un disco externo que alguien se lleva a casa y rota cada semana. Con internet
malo no hay nube que valga. Si el centro se inunda o se quema, la información
está en otro sitio.

### 5.3 Arranque directo a Windows

**Configurable, como pediste.** Tres modos, se elige al instalar y se puede
cambiar después desde el panel.

#### Modo 1 · Directo

```
┌────────────────────────────────────┐
│                                    │
│        SALMI                       │
│        [pantalla completa]         │
│                                    │
└────────────────────────────────────┘
```

Enciende y aparece Windows a pantalla completa. No hay escritorio, no hay menús,
no hay nada que tocar por error. Para el consultorio que solo mete consultas.

#### Modo 2 · Mixto

```
┌────────────────────────────────────┐
│  Escritorio                        │
│                                    │
│   ┌──────────────────────────┐     │
│   │  ENTRAR A LOS PROGRAMAS  │     │
│   │       DE SALUD           │     │
│   └──────────────────────────┘     │
│                                    │
└────────────────────────────────────┘
```

Escritorio normal con un botón grande. Para quien además usa el navegador o
imprime cosas.

#### Modo 3 · Completo

Escritorio corriente. Para administración y para quien sepa moverse.

#### La salida de emergencia

**Imprescindible.** En modo directo tiene que haber forma de llegar al sistema:

- Una combinación de teclas que solo conozca el técnico
- O un usuario administrador en la pantalla de inicio

Sin esto, el día que algo falle nadie puede entrar a arreglarlo. Se documenta y
se prueba.

### 5.4 Instalación sin internet

El pendrive tiene que traerlo **todo**:

| ✅ Va dentro | ❌ No va dentro |
|---|---|
| Sistema completo | Las imágenes de Windows |
| Controladores VirtIO | |
| Todos los paquetes RedHornoma | |
| Guías y documentación | |
| Repositorio local para actualizar después | |

**Las imágenes de Windows no viajan en la ISO.** Ocupan 6 GB cada una y, sobre
todo, cada centro tiene que usar las suyas con su licencia. El instalador las
busca en una segunda carpeta o en otro pendrive.

Esto además deja limpio el asunto legal: RedHornoma no reparte Windows.

**Para el hospital:** instalación por red. Se enciende una máquina, arranca
desde la red y se instala sola. Treinta computadoras en una mañana en vez de
treinta pendrives.

### 5.5 Pendrives, impresoras y escáneres

Lo que la gente usa todos los días y siempre da guerra.

| | Cómo se resuelve |
|---|---|
| **Pendrive** | se enchufa y aparece dentro de Windows, sin configurar nada |
| **Impresora USB** | se pasa directa al Windows |
| **Impresora de red** | se configura una vez y la ven todos los puestos |
| **Escáner** | igual que el pendrive |
| **Pasar archivos** | carpeta compartida entre el Linux y el Windows |

La carpeta compartida evita el baile del pendrive para mover un archivo de un
lado a otro de la misma computadora.

**Atención:** el paso de dispositivos USB depende de cómo se dibuje la pantalla
del Windows, y eso cambia según el hardware. Hacen falta **dos caminos**: el
cómodo cuando la máquina lo permite, y uno manual desde el panel cuando no.

### 5.6 Apagones

Real y grave. Un corte a mitad de una escritura corrompe la base de datos.

#### Con batería (UPS)

```
Se va la luz  →  aviso en pantalla
                 ↓
Batería al 30% →  se guarda todo y se apaga el Windows con orden
                 ↓
Batería al 15% →  se apaga la computadora
```

Funciona con las baterías baratas que se conectan por USB.

#### Sin batería

No hay milagro, pero sí mejoras:

- El disco virtual configurado para que un golpe no lo parta
- Respaldo más frecuente en los centros con más cortes
- Comprobación automática al arrancar: si el apagón fue feo, avisa antes de que
  alguien meta datos sobre una base dañada

#### Recomendación que va en la documentación

**Una batería para el servidor es más barata que perder un mes de información.**
Aunque los puestos no la tengan, el servidor sí.

### 5.7 Una sola pantalla de control

Todo lo importante en una ventana, con letras grandes y colores claros.

```
┌──────────────────────────────────────────────────────┐
│  RedHornoma — Centro de Salud Capinota               │
├──────────────────────────────────────────────────────┤
│                                                      │
│  🟢 Servidor              funcionando desde hace 4d  │
│  🟢 Programas de salud    SALMI, SNIS activos        │
│  🟢 Puestos conectados    3 de 4                     │
│                                                      │
│  🟢 Último respaldo       hoy 02:00   ✅ verificado  │
│  🟢 Copia externa         hace 2 días                │
│  🟡 Espacio libre         42 GB — queda para 3 meses │
│                                                      │
│  🟢 Batería               conectada, 100%            │
│  🟢 Impresora             lista                      │
│                                                      │
│  [ Entrar a los programas ]  [ Respaldar ahora ]     │
│  [ Ver los puestos ]         [ Pedir ayuda ]         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

Verde, amarillo, rojo. Sin números que haya que interpretar. Quien lo mira
entiende en tres segundos si algo va mal.

**«Pedir ayuda»** empaqueta el informe técnico de la máquina y lo deja listo
para enviarte. Sin que nadie tenga que explicar qué pasa.

### 5.8 Administración a distancia

Lo que ya construimos como *Equipos en Red*, trasladado y ampliado:

- Ver todas las máquinas del centro y su estado
- Entrar al Windows de cualquiera
- Enviarles archivos
- Actualizarlas todas de una vez
- Ver si sus respaldos van bien

**Para el hospital (30 PC)** hace falta más: acciones sobre grupos, no de una en
una. «Actualizar todos los puestos de consultorios externos», por ejemplo.

---

## 6. Fases de trabajo

Cada fase termina con algo que **funciona y se puede probar**. Nada de trabajar
tres meses para ver el resultado al final.

### Fase 0 · Cimientos

> Que exista el proyecto y se pueda construir solo.

- Estructura de carpetas y repositorio
- Receta de `live-build` con los programas **declarados**
- Esqueleto de los paquetes `.deb`
- Repositorio APT firmado
- Primera ISO que arranca, aunque no haga nada más

**Al terminar:** una ISO mínima que arranca, hecha desde una receta que
cualquiera puede repetir.

### Fase 1 · Virtualización

> Que Windows funcione, en cualquier máquina.

- Trasladar lo de cursalialinux
- Asistente de instalación de Windows 10 y 11
- Informe de la máquina antes de configurar nada
- Catálogo de hardware probado

**Al terminar:** de pendrive a Windows funcionando, sin tocar la terminal.

### Fase 2 · Red del centro

> Que las máquinas se vean y los programas trabajen en red.

- El instalador pregunta el papel de la máquina
- Modo servidor automático
- Puestos que encuentran al servidor solos
- Administración a distancia

**Al terminar:** dos máquinas con SALMI compartiendo base de datos.

### Fase 3 · Respaldo y rescate 🥇

> Que la información no se pierda nunca.

- Copias automáticas a tres sitios
- Verificación semanal automática
- Comando de rescate
- Procedimiento probado de servidor caído

**Al terminar:** apagas el servidor a lo bruto, lo restauras en otra máquina en
menos de una hora, y no falta ni un dato.

### Fase 4 · La cara visible

> Que cualquiera pueda usarlo sin aprender nada.

- Los tres modos de arranque
- El panel único de control
- Salida de emergencia documentada
- Guías imprimibles

**Al terminar:** alguien que nunca ha visto esto se sienta y trabaja.

### Fase 5 · El día a día

> Que lo cotidiano no dé guerra.

- Pendrives, impresoras, escáneres
- Carpeta compartida
- Batería y apagones
- Actualizaciones sin internet

**Al terminar:** una semana de trabajo real sin una sola llamada.

### Fase 6 · Piloto en Capinota

> Probarlo donde importa.

- Un centro, dos o tres computadoras
- **Antes de nada: respaldo completo de lo que ya tienen**
- Convivir con lo anterior, no reemplazarlo, hasta que esté probado
- Capacitación de una hora
- Un mes de observación

**Al terminar:** funciona con gente de verdad, o sabemos exactamente qué
corregir.

### Fase 7 · Escala

> De un centro a un municipio.

- Instalación por red para el hospital
- Acciones sobre grupos de máquinas
- Espejo local de actualizaciones
- Documentación para quien administre

---

## 7. La prueba piloto, en detalle

Es la fase que decide si el proyecto sirve. Merece cuidado.

### Antes de tocar nada

1. **Respaldo completo de lo que tienen ahora.** Dos copias. Verificadas.
2. Escribir qué usan, cómo lo usan y qué les molesta hoy
3. Fotografiar las pantallas de configuración de sus programas
4. Anotar el hardware de cada máquina

### Durante

- **No se reemplaza nada.** RedHornoma convive con lo que había.
- Se empieza por la máquina menos crítica
- Una persona de contacto en el centro que sepa avisarte
- Registro de cada problema, por pequeño que sea

### Después

Preguntas que hay que poder responder con un sí:

- ¿Aguantó un mes sin que fueras a arreglarlo?
- ¿Alguien perdió información alguna vez?
- ¿La gente prefiere esto a lo de antes?
- ¿Se recuperó de un apagón sin ayuda?

Si alguna sale que no, se corrige antes de ir al siguiente municipio.

---

## 8. Riesgos y cosas que hay que decidir

### 8.1 Licencias de Windows

Cada máquina virtual necesita su licencia. En 30 computadoras eso es dinero y no
se puede improvisar.

**Hay que averiguar antes del hospital:** si tienen licencias por volumen, si
las máquinas traen licencia en la placa, o qué presupuesto hay.

RedHornoma no reparte Windows ni ayuda a saltarse licencias. Eso queda escrito.

### 8.2 Datos de pacientes

Esto es información médica de personas reales. Conviene decidir:

- ¿Se cifra el disco? Protege si roban la computadora, pero complica el rescate.
- ¿Quién puede ver qué? Los programas lo controlan, pero el sistema también
  debería.
- ¿Qué pasa con los discos externos de respaldo? Salen del edificio.

**Propuesta:** cifrar los discos de respaldo que salen, dejar el resto sin
cifrar para no complicar el rescate. A revisar.

### 8.3 Que todo dependa de una persona

Hoy esto lo sabes hacer tú y nadie más. Si el proyecto crece, eso es un
problema.

Lo que lo reduce: documentación de verdad, el panel de control, y que todo se
haga con el ratón. Cuanto menos haga falta saber, menos dependen de ti.

### 8.4 Que cambien los programas del Ministerio

Cada enero llegan actualizadores. Alguna vez cambiará algo grande — como el
SOAPS 7 con servidor y base de datos aparte.

RedHornoma no puede depender de que nada cambie. Por eso Windows va dentro de
una máquina virtual: se actualiza, se rompe, se restaura, y el sistema de abajo
ni se entera.

### 8.5 Alcance

El plan es grande. Es mejor **una fase terminada y probada** que seis a medias.

Si hay que recortar, se recorta por el final: escala y comodidades. El respaldo
y la virtualización no se tocan.

---

## 9. Qué se reaprovecha de cursalialinux

Buena parte del trabajo ya está hecho y probado:

| Ya funciona | Se convierte en |
|---|---|
| `cursalia-informe.sh` | el examen previo de cada máquina |
| `virt-crear-windows.sh` | el asistente de instalación de Windows |
| `cursalia-equipos.sh` | la administración a distancia |
| `cursalia-modo-servidor.sh` | la configuración del servidor |
| `crear-virtio-reducido.sh` | los controladores de 52 MB |
| `crear-paquete.sh`, `publicar-repositorio.sh` | el sistema de actualizaciones |
| Documentación en español | las guías del personal |

**Esto no se copia y se olvida.** Se traslada y se mejora, y cursalialinux
seguirá su camino aparte.

---

## 10. Lo que hace falta decidir para empezar

1. ¿El plan refleja lo que tienes en la cabeza, o falta algo?
2. ¿Alguna fase sobra, o hay que cambiar el orden?
3. ¿Empezamos por la Fase 0, o prefieres ver antes algo que funcione?
4. Lo de las licencias de Windows en el hospital — ¿lo sabes ya o hay que
   averiguarlo?
5. ¿Cuánto tiempo real le puedes dedicar por semana? El plan se ajusta a eso,
   no al revés.
