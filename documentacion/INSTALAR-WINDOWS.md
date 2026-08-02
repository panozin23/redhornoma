# Instalar Windows dentro de RedHornoma

Cómo poner el Windows que necesitan SALMI, SNIS y SOAPS, y las cuatro trampas
que uno se encuentra por el camino.

**Probado el 2 de agosto de 2026** en un PC de escritorio Intel de 2011:
Pentium G630 de dos hilos, 11 GB de memoria y disco mecánico.

---

## Qué Windows poner

| Máquina | Versión | Por qué |
|---|---|---|
| Servidores y puestos de los centros | **Windows 10** | va suelto en equipos viejos |
| Un portátil moderno | Windows 11 | si el hardware da para ello |

Y siempre **edición Pro**, nunca Home. Home no deja compartir carpetas con
permisos —que es como los consultorios llegan a SALMI— y además obliga a entrar
con cuenta de Microsoft.

---

## Antes de empezar

Las tres imágenes tienen que estar en `/var/lib/libvirt/images`:

```
Windows.iso                 la instalación de Windows
virtio-win-0.1.285.iso      los controladores de la máquina virtual
salmi-2026.iso              el instalador de SALMI
```

Se copian con `sudo`, porque esa carpeta es de root:

```bash
sudo mv ~/donde-esten/*.iso /var/lib/libvirt/images/
sudo chown root:root /var/lib/libvirt/images/*.iso
sudo chmod 644 /var/lib/libvirt/images/*.iso
```

> **Ojo con el asterisco.** Si escribes `sudo chown root:root /var/lib/.../*.iso`
> desde un usuario normal, falla: el `*` lo resuelve tu terminal ANTES de que
> sudo entre, y tu usuario no puede leer esa carpeta. Hay que dejar que sea root
> quien lo resuelva:
>
> ```bash
> sudo sh -c 'chown root:root /var/lib/libvirt/images/*.iso'
> ```

---

## Crear la máquina

```bash
sudo redhornoma-windows --version 10
```

El asistente pregunta la imagen, el papel y el nombre. Para los nombres:

```
salud-servidor     la que guarda la base de datos
salud-puesto       un consultorio
```

**Nunca dos máquinas con el mismo nombre**, ni siquiera en equipos distintos.
`virsh shutdown salud` apaga una máquina diferente según dónde lo escribas, y
con cinco consultorios eso acaba en apagar el servidor por error.

Al final pide escribir **`CREAR`** en mayúsculas. Pulsar Enter a secas cancela.

---

## Las cuatro trampas

### 1 · Windows obliga a usar cuenta de Microsoft

Solo si detecta internet. Sin red ofrece crear una **cuenta local**, que es lo
que quiere un equipo de un centro: si esa persona se va o cambia su contraseña,
el equipo no se queda colgado.

Antes de encender la máquina, bájale el cable virtual:

```bash
MAC=$(virsh -c qemu:///system domiflist salud-servidor | awk '/virtio/{print $5}')
sudo virsh domif-setlink salud-servidor "$MAC" down --config
```

Y cuando Windows esté instalado y la cuenta creada, lo mismo con `up`.

Se le baja el cable en vez de quitarle la tarjeta a propósito: así Windows
**sí ve** el adaptador y le instala su controlador, solo que sin conexión.

### 2 · La pantalla de discos sale vacía

Le pasa a todo el mundo. Windows no reconoce discos VirtIO de fábrica.

```
Cargar controlador → segundo CD → viostor\w10\amd64
```

Aparecerá el disco de 64 GB.

**Carga solo ese.** El de red (`NetKVM\w10\amd64`) déjalo para después de crear
la cuenta local, o Windows despertará la tarjeta justo en la pantalla donde
pide la cuenta de Microsoft.

### 3 · Al reiniciar, vuelve a empezar la instalación

Este es el que más tiempo cuesta si no se sabe.

Windows copia los archivos, reinicia, y **arranca otra vez del CD**: la
instalación empieza de cero, una y otra vez.

Pasa cuando el CD tiene prioridad de arranque sobre el disco. La receta ya lo
corrige —desde el 2026-08-02 el disco arranca primero— pero si te encuentras
una máquina antigua con el problema:

```bash
virsh -c qemu:///system dumpxml salud-servidor | grep -B3 'boot order'
```

Si el `boot order='1'` está en el CD y no en el disco, hay que invertirlo.

> **Por qué el disco primero no rompe nada:** mientras está vacío, el firmware
> no encuentra nada que arrancar y cae al CD igual. En cuanto Windows escribe,
> sigue desde el disco. No hay que acordarse de pulsar ni de no pulsar nada.

### 4 · Windows 10 no viene activado

Elige «No tengo clave de producto» durante la instalación. Funciona sin activar
—con una marca de agua en la esquina— y el centro puede activarlo después con
su licencia.

**RedHornoma no incluye ni reparte Windows.** Cada centro usa las licencias que
ya tiene derecho a usar.

---

## Ya dentro de Windows

### 1 · El agente invitado — no es opcional

En el segundo CD:

```
guest-agent\qemu-ga-x86_64.msi
```

Sin él **no se pueden sacar respaldos con la máquina encendida**, y el respaldo
es la pieza más importante del sistema. Compruébalo desde Linux:

```bash
virsh -c qemu:///system qemu-agent-command salud-servidor '{"execute":"guest-ping"}'
```

### 2 · Devuélvele la red

```bash
sudo virsh domif-setlink salud-servidor "$MAC" up --config
```

Y dentro de Windows, instala el controlador de red desde el segundo CD:
`NetKVM\w10\amd64`.

### 3 · Dirección fija, si es el servidor

```
Configuración → Red e Internet → Ethernet
   Asignación de IP → Editar → Manual → IPv4 activado
```

Elige un número **fuera del rango que reparte el router**.

> Aunque la dirección sea fija, los consultorios harían mejor en conectarse
> **por nombre**. Un centro que se muda de router se queda sin red entera si
> todo apunta a números; ver [SALMI-EN-RED.md](SALMI-EN-RED.md).

### 4 · Perfil de red privado

Al ver una red nueva Windows la trata como pública y cierra todo:

```
Configuración → Red e Internet → Ethernet → Perfil de red → Privada
```

---

## Cuánto tarda

En el Pentium de 2011 con disco mecánico: alrededor de una hora, contando los
reinicios. En una máquina moderna, veinte minutos.

No es el procesador: es el disco. Si algún día un centro puede permitirse un
SSD de 240 GB, es la mejora que más se nota.

---

## Al terminar

```bash
sudo redhornoma-papel --configurar --papel servidor   # red en puente
sudo redhornoma-respaldo --programar                  # copias diarias
```

Y ya se puede instalar SALMI dentro, restaurar el `.sal` del centro, y
comprobar que los pacientes están:

```bash
sudo redhornoma-respaldo --ahora
```

Si dice **«ESTA BASE ESTÁ PRÁCTICAMENTE VACÍA»**, la restauración no llegó a
hacerse. Un centro en funcionamiento tiene miles de pacientes y de prestaciones.
