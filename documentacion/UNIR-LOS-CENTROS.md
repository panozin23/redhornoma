# Unir Hornoma y Cochabamba

**Estado: decidido el 2026-08-11, sin empezar.** Este documento es el plan.

---

## El problema, medido

Los dos centros salen a internet pero **ninguno puede recibir llamadas**. Medido
en Hornoma el 11/08:

```
dirección pública que se ve:   190.129.17.143
el camino real:  192.168.1.1 → 10.179.67.194 → 10.179.69.61
```

Esos `10.x` son la red interna del operador. Es lo que se llama **CGNAT**: la
conexión sale, pero desde fuera no hay número al que llamar. En Cochabamba será
igual, porque es el mismo tipo de servicio.

**Eso descarta lo que sería más limpio:** WireGuard directo entre los dos
routers, o abrir un puerto de SSH. Ninguno de los dos extremos puede escuchar.

## La solución elegida: Tailscale

Cada máquina **llama hacia fuera** y se encuentran en el medio. Nadie necesita
recibir llamadas. Comprobado el 11/08 que hay paquetes para Debian 13 trixie.

**Gratis** para lo que hace falta: el plan libre da 100 máquinas y 3 personas;
aquí hacen falta 4.

### Lo que hay que aceptar, dicho claro

**Hay una empresa en el medio.** El contenido viaja cifrado de punta a punta y
Tailscale no puede leerlo, pero **sí sabe qué máquinas se conectan y cuándo**.
En un proyecto con datos de pacientes eso hay que decirlo, aunque los datos
nunca pasen por ellos en claro.

**Añade un repositorio que no es de Debian**, y eso roza el objetivo 10 —que la
distro se pueda rehacer desde cero—. Se declara en la receta como cualquier
otra cosa, pero deja de ser «todo Debian».

**Si algún día no se quiere empresa de por medio:** existe **Headscale**, el
mismo sistema con el servidor propio y libre. Necesita una máquina con
dirección pública, que hoy no hay. Se puede migrar después sin rehacer nada en
los centros.

---

## 🔴 La regla que no se negocia

**Ningún centro puede DEPENDER de este enlace para funcionar.**

Si mañana Tailscale se cae, se pierde la cuenta o el internet del centro falla:

- SALMI, SOAPS y SNIS siguen funcionando en la red interna del centro
- El respaldo local sigue haciéndose y verificándose
- Lo único que se pierde es **la copia cruzada y el acceso a distancia**

El enlace es un **extra**, nunca un cimiento. Si algo del centro deja de
funcionar sin internet, está mal diseñado.

---

## Qué máquinas entran

| Máquina | Para qué |
|---|---|
| `respaldo-hornoma` · 192.168.1.101 | servidor de Hornoma |
| `servidor-ciudad` · 192.168.0.110 | servidor de Cochabamba |
| `portatil` de euflo | para trabajar en los dos desde donde esté |
| (más adelante) el portátil de rosi | cuando tenga papel en algún centro |

---

## Los pasos, en orden

### 1 · La cuenta

Se entra con una cuenta de Google. **Usar la del proyecto**, no una personal
cualquiera — ver [[drive-cuenta-de-respaldos]] para la que ya se usa.

Anotar cuál se usó, junto a las llaves del repositorio.

### 2 · En cada máquina

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=respaldo-hornoma
```

Sale una dirección web: se abre, se entra con la cuenta, y la máquina queda
unida. Se repite en cada una cambiando el `--hostname`.

*(En el `.101` no hay `curl` — usar `wget -qO- … | sh`, o instalar el
repositorio a mano. Es el mismo tropiezo del 08/08 con el repositorio APT.)*

### 3 · ⚠️ Quitar la caducidad de las llaves

**Esto es lo más importante de todo el montaje.**

Tailscale caduca las llaves de cada máquina a los 6 meses. Cuando eso pasa, la
máquina **se cae del enlace en silencio**. Un servidor de un centro rural no
tiene a nadie que lo note.

En el panel de Tailscale, en cada servidor: **«Disable key expiry»**.

Es exactamente el mismo tipo de fallo que este proyecto lleva persiguiendo todo
el año: algo deja de funcionar y nadie se entera. Ver
[[jornada-2026-08-10]], donde el `.101` estuvo 7 días apagado sin que nadie lo
supiera.

### 4 · Comprobar de verdad

No basta con que el panel diga «conectado»:

```bash
tailscale status                                  # las cuatro máquinas
ping -c3 <direccion-100.x-del-otro-centro>
ssh flora@<direccion-100.x>  'hostname; uptime -p'
```

Y la prueba que de verdad importa, la de este proyecto:

```bash
redhornoma-entrar --en flora@<direccion-100.x>
```

**Si eso abre la pantalla del Windows de Cochabamba desde Hornoma, está hecho.**
No hay que cambiar nada en la herramienta: por debajo es SSH.

---

## Lo que se desbloquea, por orden de valor

### 1 · La copia cruzada — objetivo 8

**Es lo que más vale de todo esto.** Hoy el respaldo de Hornoma vive en Hornoma
y el de Cochabamba en Cochabamba. Un incendio, un robo o un rayo se lleva las
dos cosas a la vez: la información y su copia.

Con el enlace, **cada centro guarda el respaldo del otro**. Eso es una copia
fuera del edificio de verdad, y sale gratis.

Se haría con lo que ya existe (`rsync` sobre SSH), añadiendo un destino a
`respaldo.conf`.

### 2 · Vigilar los dos centros a la vez — objetivo 9

`redhornoma-vigilar` existe y hoy solo ve lo que tiene delante. Con el enlace
ve los dos, y **el silencio de uno se convierte en una alarma**.

### 3 · Trabajar en cualquiera desde donde sea

Lo que hoy obliga a viajar. Ver [[regla-de-oro-trabajar-por-ssh]].

---

## Lo que NO se debe hacer

**No compartir Samba por el enlace.** Las carpetas del centro se quedan en su
red. Lo que viaje entre centros que viaje por SSH, que es lo que ya usamos.

**No abrir la pantalla del Windows a la red.** Sigue escuchando en `127.0.0.1`
y se llega por el túnel de SSH, como ahora.

**No poner el enlace en medio del trabajo diario del centro.** Los puestos
hablan con su servidor por la red interna, y punto.
