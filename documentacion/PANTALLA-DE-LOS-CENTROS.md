# La pantalla de los centros — objetivo 11

**Decidido el 2026-08-11. Sin empezar.** Idea de euflo, afinada entre los dos.

> **11 · Que se puedan atender varios centros desde un solo sitio.**

---

## El problema

Los diez objetivos describen **lo que necesita un centro**. Ninguno hablaba de
**atender a varios a la vez**. Hoy son dos —Hornoma y Cochabamba— y mañana
serán los del municipio, y cada uno se atiende de memoria: recordar su
dirección, escribir el `ssh`, acordarse de qué máquina virtual tiene dentro.

## La decisión de diseño que importa

La tentación es enseñarle a cada herramienta a trabajar a distancia: que el
panel sepa mirar otro centro, que «Algo no funciona» sepa arreglar otro centro.
**Eso está mal.** Es mucho trabajo y multiplica los sitios donde algo falla.

**Se hace al revés: no se traen los datos aquí, se ejecuta la herramienta ALLÁ
y se trae la respuesta.**

```
mal    el panel de aquí intenta leer los archivos de allá
bien   se le pide al panel de ALLÁ que se mire, y manda lo que ve
```

Cada servidor ya tiene todas las herramientas instaladas y **se conoce a sí
mismo mejor que nosotros**. Además así funciona igual aunque el centro tenga
una versión distinta de los programas.

**Una sola excepción:** la pantalla del Windows, que tiene que dibujarse en el
portátil. Eso ya está resuelto con `redhornoma-entrar --en` desde
`virtualizacion 1.0.15`.

## Cómo se vería

```
┌─ RedHornoma · ¿con qué centro trabajo? ──────────────┐
│                                                       │
│  🟢  Hornoma           respaldo-hornoma               │
│      último respaldo hace 2 horas ✅ · 3 puestos      │
│                                                       │
│  🔴  Cochabamba        servidor-ciudad                │
│      no responde desde hace 4 días                    │
│                                                       │
│  ── con el centro elegido ──                          │
│  [ Ver su estado ]   [ Entrar a sus programas ]       │
│  [ Revisar y arreglar ]   [ Sus respaldos ]           │
└───────────────────────────────────────────────────────┘
```

**Lo importante es la segunda línea de cada centro.** Que al abrirla ya diga si
ese centro está sano, sin tener que entrar. Abrir esa ventana por la mañana
tiene que sustituir a preguntarse «¿estará bien Hornoma?».

## Lo que ya existe y NO hay que duplicar

| Herramienta | Qué hace hoy |
|---|---|
| `redhornoma-panel` | el estado de **un** centro, en su propia máquina |
| `redhornoma-equipos` | las computadoras de **una** red |
| `redhornoma-vigilar` | si **todos** los centros respaldaron |
| `redhornoma-entrar --en` | la pantalla del Windows de otro equipo ✅ |

Lo nuevo es **la puerta de entrada que les falta a los cuatro**: no un quinto
programa que repita lo suyo, sino uno que los llame con el centro correcto.

## Cómo se construiría

**Dónde viven los centros.** Un archivo tipo `/etc/redhornoma/centros.conf`:

```
nombre=Hornoma      destino=hornoma@192.168.1.101
nombre=Cochabamba   destino=flora@192.168.0.110
```

Cuando esté el enlace de [[unir-centros-tailscale]], esas direcciones pasan a
ser las de Tailscale y funcionan desde cualquier sitio **sin cambiar nada más**.

**Cada botón es una llamada por SSH:**

```bash
Ver su estado         ssh $destino 'redhornoma-panel --texto'
Revisar y arreglar    ssh -t $destino 'redhornoma-arreglar --texto'
Sus respaldos         ssh $destino 'sudo redhornoma-respaldo'
Entrar a programas    redhornoma-entrar --en $destino     ← el único local
```

**El resumen de la primera pantalla** sale de preguntar a cada centro en
paralelo, con un tiempo de espera corto: un centro que no responde en 5
segundos se pinta en rojo y no bloquea a los demás.

## ⚠️ Lo que hay que cuidar

**Un centro que no responde no es un centro roto.** Puede ser el internet. La
pantalla debe decir «no responde», nunca «está mal» — es la misma regla del
panel: cuando algo no se puede saber, se dice en gris y no se inventa un verde.

**Nada de lo que se vea aquí debe hacer falta para que el centro funcione.**
Esta pantalla es para quien administra, no para quien atiende pacientes.
