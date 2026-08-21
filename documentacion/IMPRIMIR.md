# Imprimir en el centro

Una sola impresora, enchufada a una máquina, y que impriman todas: los
Linux, el Windows que va dentro del servidor, y los puestos Windows.

---

## Lo corto

**En la máquina donde está enchufada la impresora:**

```
sudo redhornoma-impresora --compartir
```

**En cada máquina Linux del centro:**

```
sudo redhornoma-impresora --usar 192.168.0.110
```

*(esa dirección la dice el comando anterior al terminar)*

**Para ver cómo está, en cualquier máquina:**

```
redhornoma-impresora --ver
```

---

## Los Windows

No hace falta instalarles ningún driver de Epson. Lo que se pone es un
**puerto de red normal**, de los que entiende cualquier Windows desde hace
veinte años:

```
Panel de control → Dispositivos e impresoras → Agregar impresora
   → La impresora que quiero no está en la lista
   → Agregar con dirección TCP/IP
        Dirección : 192.168.0.110       (la máquina que la comparte)
        Puerto    : 9100
   → Fabricante: Microsoft   Impresora: Microsoft PS Class Driver
```

Y ya imprime SOAPS, SALMI, SNIS y todo lo demás.

**Para el Windows que va DENTRO del servidor** la dirección no es esa: es
`192.168.122.1`, la de la red interna. La de fuera puede fallar según cómo
esté la tarjeta.

---

## Por qué está montado así

**Los Linux van por IPP**, que es lo estándar. No llevan driver: la máquina
que comparte traduce. Así, el día que se cambie de impresora solo hay que
tocar una máquina.

**Los Windows van por el puerto 9100.** Se intentó por IPP y no sirve:
Windows no deja crear un puerto `http://…` a mano, y lo que sí deja queda
guardado **para una sola cuenta de usuario**. En un centro de salud eso no
vale — la impresora tiene que estar para quien se siente.

El camino completo es:

```
Windows → PostScript → puerto 9100 → CUPS → driver Epson → papel
```

Windows manda PostScript con un driver que ya trae dentro
(*Microsoft PS Class Driver*), y CUPS lo traduce a lo que entiende la
Epson.

---

## Cosas que conviene saber

**Si la impresora está apagada, la hoja no se pierde.** El trabajo espera
en la cola y sale solo en cuanto se encienda. Comprobado el 20/08/2026.

**El driver abierto de Debian no sirve para estas Epson.** Conoce 586
modelos y no están ni la L220, ni la L222, ni la L380. El driver de verdad
va dentro de `redhornoma-perifericos`, pero solo cubre **L380 y L382**:
para la de Hornoma habrá que buscar el suyo.

**Si se mueve la impresora de máquina**, la cola vieja se queda y sigue
diciendo «imprimiendo» para siempre. `--usar` la retira sola.

---

## Cómo quedó Cochabamba el 20/08/2026

```
impresora   Epson L380, enchufada al servidor «flora»
cola        EPSON_L380, compartida
direcciones 192.168.0.110  (red del centro)
            100.74.174.70  (Tailscale, desde cualquier lado)
            192.168.122.1  (para el Windows de dentro)
puerto 9100 abierto para los Windows
```

Probado el mismo día, con papel de verdad: una hoja desde el portátil de
euflo, una desde el portátil «rosi», y dos desde el Windows del servidor.
