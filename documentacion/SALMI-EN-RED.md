# SALMI para varios consultorios

Cómo montar un centro donde varias personas registran en SALMI a la vez,
cada una desde su computadora, sobre la misma información.

**Probado el 30 de julio de 2026** con datos reales del Centro de Salud
Hornoma: dos máquinas viendo a la misma paciente al mismo tiempo.

---

## Cómo funciona

```
   🖥️ SERVIDOR  ←── tiene SALMI instalado y la base de datos
        │            comparte su carpeta por la red
        │
   ┌────┴────┬─────────┐
   │         │         │
  🖥️ C2     🖥️ C3     🖥️ C4
   Abren EL MISMO programa desde esa carpeta
```

No hay dos bases de datos ni sincronización: **hay una sola**, en el servidor,
y todos escriben en ella.

Los permisos los distingue **el usuario con el que cada uno entra en SALMI**,
no la máquina. SALMI trae su propia lista de usuarios.

### Lo que hay que asumir

Si se apaga el servidor, **nadie puede trabajar**. Es así por diseño, no un
fallo. Y una base de datos Access compartida por red **se puede corromper** si
la red parpadea o se va la luz mientras alguien graba.

Por eso el respaldo automático de RedHornoma no es opcional en este montaje.

---

## En el servidor

### 1 · Sacar su Windows a la red

De fábrica el Windows virtual vive escondido en una red privada. Hay que ponerlo
en puente para que los demás lo vean.

**Requiere apagar ese Windows primero:**

```bash
sudo virsh shutdown --mode agent salud
sudo redhornoma-papel --configurar --papel servidor
sudo virsh start salud
```

> `--mode agent` no es un detalle: si Windows tiene la pantalla apagada por
> inactividad, la señal normal de apagado se pierde y la orden nunca llega.

### 2 · Decirle a Windows que la red es de confianza

Al ver una red nueva, Windows la trata como pública y **cierra todo**. Dentro de
ese Windows:

```
Configuración → Red e Internet → Ethernet
   Perfil de red → Privada
```

### 3 · Darle dirección fija

Un servidor no puede cambiar de número:

```
Configuración → Red e Internet → Ethernet
   Asignación de IP → Editar → Manual → IPv4 activado
```

Elige un número **fuera del rango que reparte el router**. Si las máquinas
reciben `.100`, `.101`…, entonces el `.50` está libre.

### 4 · Compartir la carpeta de SALMI

Clic derecho en `C:\SALMI-PN_Dispensacion_BO` → Propiedades → Compartir.

Y **dar permiso de escritura**: sin él los consultorios podrán mirar pero no
registrar.

### 5 · Crear un usuario para el acceso

Windows no deja entrar a una carpeta compartida sin identificarse. Hace falta
una cuenta, y **conviene que sea dedicada** en vez de la personal de alguien:

```
Nombre:  salmired
Para:    solo abrir la carpeta compartida
```

Si esa persona se va del centro, no se rompe nada.

---

## En cada consultorio

### 1 · Instalar SALMI localmente

Aunque después no se use su base de datos. La instalación deja las bibliotecas
que el programa necesita para arrancar.

### 2 · Conectar la carpeta del servidor

```
Explorador → clic derecho en «Este equipo» → Conectar a unidad de red

   Unidad:   S:
   Carpeta:  \\DIRECCION-DEL-SERVIDOR\SALMI
   ☑ Conectar de nuevo al iniciar sesión

   Usuario:     salmired
   Contraseña:  la que se puso
   ☑ Recordar mis credenciales
```

### 3 · Crear el acceso directo

Un icono en el escritorio que apunte a **`S:\SalmiDis.exe`**.

### 4 · Quitar el icono local

**Este paso importa.** Tras instalar SALMI queda un icono que abre la base
vacía de esa máquina. Si nadie lo quita, alguien lo abrirá por error, verá un
sistema sin pacientes y creerá que se perdió todo.

Deja **un solo icono** y que sea el del servidor.

---

## Las dos contraseñas

Es la confusión más común, y conviene explicarla al personal:

| Cuándo aparece | Qué pide |
|---|---|
| Al abrir el icono, ventana azul de Windows | la cuenta **`salmired`** de la carpeta compartida |
| Después, dentro del programa | el usuario **de SALMI** de cada persona |

La primera se marca «recordar» y no vuelve a salir. La segunda se escribe cada
día, y es personal.

---

## Comprobar que funciona

Desde el servidor, con el programa abierto en los dos sitios:

```powershell
Get-SmbOpenFile | Select-Object ClientUserName,ClientComputerName,Path
```

Debe aparecer una línea por cada consultorio conectado.

Y la prueba de verdad: **buscar el mismo paciente en las dos pantallas**. Si
aparece en ambas, están sobre la misma información.

---

## Si algo no va

| Síntoma | Qué mirar |
|---|---|
| «Acceso denegado» al abrir la carpeta | la cuenta `salmired` y su contraseña |
| El servidor no responde al ping | el perfil de red en Windows sigue en «Pública» |
| Entra pero no reconoce el usuario de SALMI | se abrió el icono local, no el del servidor |
| Puede mirar pero no registrar | falta permiso de escritura en la carpeta |
