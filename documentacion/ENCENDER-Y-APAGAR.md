# Encender y apagar, sin preguntarle a nadie

**Todo lo de aquí se escribe EN TU PORTÁTIL**, estés donde estés.
Comprobado el 19/08/2026.

---

## ⚠️ Antes de nada: dos nombres, UNA máquina

En tus notas aparecían como si fueran dos computadoras distintas. **Son la
misma:**

```
respaldo-hornoma   =   100.81.234.58   =   el servidor de Hornoma
```

Por eso tenías dos apuntes que hacían exactamente lo mismo.

## Desde el 19/08 se llaman más corto

```
hornoma        el servidor de HORNOMA      (el principal)
cochabamba     el servidor de COCHABAMBA   (el de apoyo)
```

Basta con `ssh hornoma`. Los nombres largos siguen valiendo, **pero solo
mientras el sistema no reescriba su configuración de nombres** — y la
reescribe él solo cada vez que se reconecta la red. Pasó ese mismo día a
las 21:15, y a partir de ahí `ssh respaldo-hornoma` decía «no se conoce
ese nombre» sin más pistas.

Los cortos van atados a su número y no dependen de nadie.

---

## 🥇 Lo primero: la pantalla que te ahorra casi todos los comandos

```
redhornoma-centros
```

Te dice de un vistazo **qué centros están despiertos** y te deja entrar a
la pantalla de su Windows con un botón. También está en el menú del
escritorio, como **«Los centros»**.

Si prefieres verlo escrito:

```
redhornoma-centros --texto
```

Y se ve así:

```
   CENTRO           ESTADO       SU WINDOWS         ENLACE
   ○ CS Hornoma     no contesta  —                  —
   ● Cochabamba     despierto    salud-servidor     85 ms
```

**`○ no contesta` no siempre es un problema**: a partir de las 8 de la
mañana Hornoma se apaga sola. Mira el apartado siguiente.

---

# 🏥 HORNOMA — el servidor principal

## Se apaga y se enciende SOLA. No hay que hacer nada.

```
se enciende    todos los días a la 01:00
se apaga       de miércoles a domingo, a partir de las 08:00
```

A las 8 empieza a intentarlo, y **reintenta cada media hora hasta las
12:30** si hay alguien trabajando. En cuanto no queda nadie, se apaga.

**No se apaga si:** hay alguien conectado por red, hay un respaldo en
marcha, o existe el archivo `/etc/redhornoma/no-apagar`.

## Saber si está viva, y qué prometió

```
redhornoma-centros --texto
```

Y para saber **qué dijo la última vez** —incluso estando apagada—:

```
rclone cat drive:ESTADO-REDHORNOMA/hornoma--respaldo-hornoma.txt
```

Contesta algo así, y esto es oro cuando no responde:

```
que=apagando
vuelve=20/08 a las 01:00
despertador=si
Se apagó con orden, y dejó el despertador puesto y COMPROBADO.
```

> **Si prometió volver y no volvió, el problema es la placa o la
> corriente, no el programa.** Si ni siquiera prometió, se apagó por otro
> camino.

## Apagarla ahora — con un botón

En `redhornoma-centros`: eliges el centro y pulsas **«Apagar este
centro»**. Te pregunta antes, y abre una terminal para que escribas la
contraseña de esa máquina. Ahí verás **a qué hora prometió volver**.

## O escribiéndolo, si prefieres

```
ssh -t hornoma 'sudo /usr/local/sbin/redhornoma-apagar-noche --ahora'
```

Te pide la contraseña de esa máquina.

**El `--ahora` es lo que dice «lo pido yo».** Sin él, el guion mira si hay
alguien conectado —y como tú entras por SSH, se vería a ti mismo y no se
apagaría nunca.

Esto hace tres cosas, y por eso es mejor que `poweroff` a secas:

```
1 · cierra el Windows con orden, sin perder nada
2 · arma el despertador para la 01:00 y lo COMPRUEBA
3 · deja dicho en la nube a qué hora vuelve
```

⚠️ **Nunca la apagues con el enchufe inteligente.** Cortarle la luz la deja
sin despertador puesto: no volvería sola.

## Encenderla desde lejos

**No se puede por red**: una máquina apagada no escucha. Se hace con el
**enchufe inteligente**, desde el teléfono, con la aplicación **Smart
Life** — y funciona con datos móviles, sin estar en el centro.

```
1 · abre Smart Life y busca la toma donde está la PC
2 · APÁGALA
3 · espera 10 segundos
4 · ENCIÉNDELA
```

**El apagar-y-encender es lo que la arranca.** Si la toma ya estaba
encendida y solo le das a «encender», no pasa nada: la placa necesita ver
que vuelve la luz.

⚠️ El **botón pequeño azul** del enchufe apaga las DOS tomas. No lo uses.

Tarda un par de minutos en aparecer. Compruébalo con `redhornoma-centros`.

## Entrar a la pantalla de su Windows

Lo cómodo:

```
redhornoma-centros --entrar hornoma
```

Lo mismo, escrito entero (por si la pantalla fallara):

```
redhornoma-entrar --en hornoma
```

Ahí dentro tienes SOAPS, SALMI y SNIS del centro, como si estuvieras
sentado delante.

---

# 🏙️ COCHABAMBA — el servidor de apoyo

**No tiene horario, y es a propósito.** Aquí estás tú: se enciende y se
apaga a mano, con su botón.

Para apagarlo desde el portátil:

```
ssh -t cochabamba 'sudo systemctl poweroff'
```

> Va con `systemctl` y no con `poweroff` a secas por un detalle: en esa
> máquina `poweroff` vive en `/sbin`, que **no está en el camino de tu
> usuario**. Con `sudo` normalmente funcionaría igual, pero «normalmente»
> no basta para un comando que apaga un servidor. `systemctl` sí está en
> el camino, siempre.

Para entrar a su Windows:

```
redhornoma-entrar --en cochabamba
```

⚠️ **Este no tiene despertador.** Si lo apagas y te vas, hay que ir a
encenderlo con el botón.

---

# 💻 LOS PUESTOS (las computadoras de los consultorios)

Se encienden y se apagan **con su botón, como siempre**. No tienen horario
ni hace falta.

Lo único que importa: **para que funcionen, el servidor tiene que estar
despierto.** Si alguien dice «no abre el SOAPS» a las 9 de la mañana, casi
siempre es que el servidor ya se apagó.

## El portátil de un médico que viene de visita

En el servidor del centro, una sola vez:

```
sudo redhornoma-visitante
```

Y te dice exactamente qué decirle. Resumido:

```
1 · que se conecte al wifi del centro
2 · que abra:  \\192.168.1.110\INSTALAR
3 · doble clic en «Instalar.bat»  (le pides tú la cuenta de las carpetas)
4 · al terminar la jornada, doble clic en «Quitar.bat»
```

---

# 🔧 CUANDO ALGO NO VA

## El orden en el que mirar

```
1 · redhornoma-centros --texto        ¿está despierto el centro?
2 · redhornoma-vigia --siempre        ¿hay algo que avisar?
3 · rclone cat drive:ESTADO-…         ¿qué dijo antes de callarse?
```

## «El acceso directo de SOAPS no está disponible»

Casi siempre es **el cable de la placa del servidor**, por donde se asoma
el Windows. Si se suelta, el Windows desaparece de la red **aunque el
servidor siga funcionando**. Se comprueba así:

```
ssh hornoma 'cat /sys/class/net/enp2s0/carrier'
```

```
1 = hay cable      0 = está suelto
```

## El vigía

```
redhornoma-vigia
```

**Si no dice nada, es que todo está bien.** Es a propósito: un aviso que
sale todos los días se ignora a la semana. Para que hable igualmente:

```
redhornoma-vigia --siempre
```

---

# 📋 LA CHULETA

**Casi todo se hace desde una sola pantalla — `redhornoma-centros`, o
«Los centros» en el menú. Lo de escribir es solo para cuando esa pantalla
no esté a mano.**

| Quiero… | Con el ratón | Escribiéndolo |
|---|---|---|
| ver cómo está todo | «Los centros» | `redhornoma-centros --texto` |
| entrar al Windows de un centro | botón **Entrar a su Windows** | `redhornoma-centros --entrar hornoma` |
| apagar un centro | botón **Apagar este centro** | `ssh -t hornoma 'sudo …apagar-noche --ahora'` |
| ¿hay algo que avisar? | «El vigía» | `redhornoma-vigia --siempre` |
| preparar un puesto para un visitante | — | en el servidor: `sudo redhornoma-visitante` |
| encender Hornoma | con el teléfono: Smart Life → apagar la toma, 10 s, encender | no se puede por red |
