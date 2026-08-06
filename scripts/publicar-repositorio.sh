#!/bin/bash
# publicar-repositorio.sh — Publica las mejoras de RedHornoma para que los
# centros las reciban solos.
#
# El ISO sirve para máquinas nuevas. Pero una máquina que ya está trabajando
# —con su Windows, sus programas y la información del centro dentro— no se
# reinstala para corregir un guion de veinte líneas. Para esas está esto.
#
# Convierte paquetes/deb/ en un repositorio APT firmado, alojado en GitHub
# Pages, que es gratuito y no necesita servidor propio. Después, en cualquier
# centro, un «apt upgrade» trae la corrección. Pesa 50 kB en vez de 2,8 GB:
# la diferencia entre bajarlo por internet rural y no bajarlo nunca.
#
# NO tiene nada que ver con el repositorio de cursalialinux, que es otro
# proyecto, con otra dirección, otra llave y otros paquetes. Solo comparten
# la mecánica, igual que dos panaderías comparten la receta del pan.
#
# Uso:  bash publicar-repositorio.sh            arma y sube
#       bash publicar-repositorio.sh --local    solo arma, para revisarlo
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$BASE/scripts/repositorio.conf"
REPO="$BASE/repositorio"
PAQUETES="$BASE/paquetes/deb"
SUITE=trixie
# La rama donde vive el repositorio APT. NO es main: ahí está el código.
RAMA=gh-pages
COMPONENTE=main
ARQ=all
SOLO_LOCAL=0
[ "${1:-}" = "--local" ] && SOLO_LOCAL=1

V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'; GR=$'\033[0;90m'
titulo(){ printf "\n%s══════════════════════════════════════════════════════%s\n%s %s%s\n%s══════════════════════════════════════════════════════%s\n" "$AZ" "$V" "$AZ" "$1" "$V" "$AZ" "$V"; }
ok(){   printf "   %s●%s %s\n" "$VE" "$V" "$1"; }
mal(){  printf "   %s✗%s %s\n" "$RO" "$V" "$1"; }
avis(){ printf "   %s!%s %s\n" "$AM" "$V" "$1"; }
nota(){ printf "   %s%s%s\n" "$GR" "$1" "$V"; }

# ── Configuración ────────────────────────────────────────────────────
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EJEMPLO'
# Datos para publicar el repositorio de RedHornoma.

# Tu usuario de GitHub (el que sale en la dirección)
GITHUB_USUARIO=

# El repositorio del proyecto, el que ya guarda el código fuente.
# NO hay que crear ninguno: los paquetes van a su rama gh-pages.
GITHUB_REPO=redhornoma

# Identificador de la llave con la que se firma.
# Se ve con:  gpg --list-secret-keys --keyid-format=long
CLAVE_GPG=
EJEMPLO
  titulo "FALTA CONFIGURAR"
  nota "Acabo de crear este archivo:"
  printf "\n      %s\n\n" "$CONF"
  nota "Ábrelo, pon tu usuario de GitHub, y vuelve a ejecutar esto:"
  printf "\n      nano %s\n\n" "$CONF"
  exit 1
fi

# shellcheck disable=SC1090
. "$CONF"
[ -n "${GITHUB_USUARIO:-}" ] || { mal "falta GITHUB_USUARIO en $CONF"; exit 1; }
GITHUB_REPO="${GITHUB_REPO:-redhornoma}"

# ── La llave ─────────────────────────────────────────────────────────
# Si no se dice cuál, se busca la de RedHornoma por su nombre. Coger «la
# primera que haya» sería un error aquí: en este equipo hay dos llaves y la
# otra es de un proyecto distinto.
if [ -z "${CLAVE_GPG:-}" ]; then
  CLAVE_GPG=$(gpg --list-secret-keys --keyid-format=long 2>/dev/null \
              | grep -B1 -i 'RedHornoma' | awk '/^sec/{print $2; exit}' | cut -d/ -f2)
fi
if [ -z "$CLAVE_GPG" ]; then
  mal "no encuentro ninguna llave de RedHornoma para firmar"
  nota "Créala así:"
  cat <<'AYUDA'

      gpg --batch --gen-key <<FIN
      %no-protection
      Key-Type: RSA
      Key-Length: 4096
      Name-Real: RedHornoma
      Name-Email: tu-correo@ejemplo.com
      Expire-Date: 5y
      %commit
      FIN

AYUDA
  exit 1
fi
gpg --list-secret-keys "$CLAVE_GPG" >/dev/null 2>&1 || { mal "la llave $CLAVE_GPG no existe en este equipo"; exit 1; }

URL="https://${GITHUB_USUARIO}.github.io/${GITHUB_REPO}"

titulo "REPOSITORIO DE PAQUETES DE REDHORNOMA"
ok "Dirección: $URL"
ok "Firma con: $CLAVE_GPG  ($(gpg --list-keys --keyid-format=long "$CLAVE_GPG" 2>/dev/null | awk '/^uid/{$1="";$2="";print;exit}' | xargs))"

# ── 1 · Comprobar que hay algo nuevo que publicar ────────────────────
#
# Publicar un paquete con un número igual o menor que el que ya está fuera
# es el fallo silencioso de este sistema: apt no dice nada, no instala nada,
# y quien lo publicó cree que los centros ya lo tienen. Se comprueba antes.
titulo "1/6 · ¿HAY ALGO NUEVO?"
DIST="$REPO/dists/$SUITE/$COMPONENTE/binary-$ARQ"
ANTERIOR="$DIST/Packages"
NUEVOS=0; IGUALES=0; PROBLEMA=0

for D in "$PAQUETES"/*.deb; do
  [ -f "$D" ] || continue
  N=$(dpkg-deb -f "$D" Package)
  VNUEVA=$(dpkg-deb -f "$D" Version)
  VVIEJA=""
  [ -f "$ANTERIOR" ] && VVIEJA=$(awk -v p="$N" '$1=="Package:"&&$2==p{f=1;next} f&&$1=="Version:"{print $2;exit}' "$ANTERIOR")

  if [ -z "$VVIEJA" ]; then
    printf "   %s●%s %-32s %-10s  nuevo\n" "$VE" "$V" "$N" "$VNUEVA"; NUEVOS=$((NUEVOS+1))
  elif dpkg --compare-versions "$VNUEVA" gt "$VVIEJA"; then
    printf "   %s●%s %-32s %-10s  sube desde %s\n" "$VE" "$V" "$N" "$VNUEVA" "$VVIEJA"; NUEVOS=$((NUEVOS+1))
  elif [ "$VNUEVA" = "$VVIEJA" ]; then
    printf "   %s=%s %-32s %-10s  ya publicado\n" "$GR" "$V" "$N" "$VNUEVA"; IGUALES=$((IGUALES+1))
  else
    printf "   %s✗%s %-32s %-10s  ¡MENOR que el publicado (%s)!\n" "$RO" "$V" "$N" "$VNUEVA" "$VVIEJA"; PROBLEMA=1
  fi
done

if [ "$PROBLEMA" = 1 ]; then
  printf "\n"
  mal "Hay un paquete con número MENOR que el que ya está publicado."
  nota "Ningún centro lo instalaría, y nadie se enteraría. Sube el número"
  nota "en su DEBIAN/control y vuelve a construir antes de publicar."
  exit 1
fi
[ $((NUEVOS+IGUALES)) -gt 0 ] || { mal "no hay paquetes en $PAQUETES"; nota "Constrúyelos: bash scripts/construir-paquetes.sh"; exit 1; }
printf "\n"
[ "$NUEVOS" -gt 0 ] && ok "$NUEVOS paquete(s) con novedades" || avis "nada nuevo — se republica igual, no hace daño"

# ── 2 · Ordenar ──────────────────────────────────────────────────────
titulo "2/6 · ORDENANDO LOS PAQUETES"
POOL="$REPO/pool/$COMPONENTE"
mkdir -p "$POOL" "$DIST"
# Fuera las versiones viejas del mismo paquete: dejarlas engorda el
# repositorio y confunde a quien mire la carpeta.
for D in "$PAQUETES"/*.deb; do
  [ -f "$D" ] || continue
  N=$(dpkg-deb -f "$D" Package)
  for VIEJO in "$POOL/${N}"_*.deb; do
    [ -e "$VIEJO" ] || continue
    [ "$(basename "$VIEJO")" = "$(basename "$D")" ] && continue
    rm -f "$VIEJO"; nota "retirado $(basename "$VIEJO")"
  done
  cp -f "$D" "$POOL/"
done
ok "$(ls -1 "$POOL"/*.deb 2>/dev/null | wc -l) paquete(s) en el almacén"

# ── 3 · El índice ────────────────────────────────────────────────────
titulo "3/6 · GENERANDO EL ÍNDICE"
( cd "$REPO" && dpkg-scanpackages --multiversion pool /dev/null > "dists/$SUITE/$COMPONENTE/binary-$ARQ/Packages" 2>/dev/null )
gzip -9kf "$DIST/Packages"
ok "$(grep -c '^Package:' "$DIST/Packages") paquete(s) indexados"

# ── 4 · La descripción ───────────────────────────────────────────────
titulo "4/6 · DESCRIBIENDO EL REPOSITORIO"
cat > "$REPO/dists/$SUITE/Release" <<REL
Origin: RedHornoma
Label: RedHornoma
Suite: $SUITE
Codename: $SUITE
Architectures: $ARQ amd64
Components: $COMPONENTE
Description: Paquetes de RedHornoma para centros de salud
Date: $(date -Ru)
REL
( cd "$REPO/dists/$SUITE" && apt-ftparchive release . > Release.tmp 2>/dev/null \
  && grep -vE '^(Origin|Label|Suite|Codename|Architectures|Components|Description|Date):' Release.tmp >> Release \
  && rm -f Release.tmp )
ok "Release con las sumas de verificación"

# ── 5 · Firmar, y comprobar la firma ─────────────────────────────────
#
# Firmar y no verificar es como cerrar con llave sin probar la puerta. Si la
# firma sale mal, cada centro verá un aviso de origen no fiable en cada
# «apt update» — y la gente aprende a ignorar avisos, que es como se pierden
# los sistemas.
titulo "5/6 · FIRMANDO"
( cd "$REPO/dists/$SUITE"
  rm -f Release.gpg InRelease
  gpg --default-key "$CLAVE_GPG" --batch --yes -abs -o Release.gpg Release 2>/dev/null
  gpg --default-key "$CLAVE_GPG" --batch --yes --clearsign -o InRelease Release 2>/dev/null )

[ -f "$REPO/dists/$SUITE/InRelease" ] || { mal "no se pudo firmar"; exit 1; }
if gpg --verify "$REPO/dists/$SUITE/InRelease" >/dev/null 2>&1 \
   && gpg --verify "$REPO/dists/$SUITE/Release.gpg" "$REPO/dists/$SUITE/Release" >/dev/null 2>&1; then
  ok "firmado Y comprobado"
else
  mal "la firma no se verifica — NO se publica"
  exit 1
fi

gpg --export "$CLAVE_GPG" > "$REPO/redhornoma-archive-keyring.gpg"
ok "llave pública exportada"

# ── 6 · La página ────────────────────────────────────────────────────
titulo "6/6 · PÁGINA DE INSTRUCCIONES"
cat > "$REPO/index.html" <<HTML
<!doctype html><html lang="es"><meta charset="utf-8">
<title>Repositorio de RedHornoma</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
 body{font-family:system-ui,sans-serif;max-width:44rem;margin:3rem auto;padding:0 1.2rem;
      line-height:1.7;color:#12210F;background:#F4F8F1}
 h1{color:#1F7A34} h2{margin-top:2.2rem;border-top:1px solid #D5E4CE;padding-top:1.4rem}
 pre{background:#10200C;color:#DCEFD6;padding:1rem;border-radius:7px;overflow-x:auto;font-size:.86rem}
 code{background:#E6F1E1;padding:.1em .35em;border-radius:3px}
 .nota{background:#fff;border:1px solid #D5E4CE;border-radius:7px;padding:1rem 1.2rem}
</style>
<h1>Repositorio de RedHornoma</h1>
<p><b>RedHornoma</b> es el sistema para las computadoras de un centro de salud:
la red interna, los programas del Ministerio dentro de Windows, y el respaldo
que se hace solo.</p>
<p>Aquí se publican sus mejoras. Una vez añadido este origen, un centro las
recibe con <code>apt upgrade</code>, sin reinstalar y sin pendrive.</p>

<h2>Añadirlo a una computadora</h2>
<p>Solo hace falta una vez. Las instaladas con el ISO ya lo traen puesto.</p>
<pre>sudo mkdir -p /usr/share/keyrings
wget -qO- $URL/redhornoma-archive-keyring.gpg \\
  | sudo tee /usr/share/keyrings/redhornoma.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/redhornoma.gpg] $URL $SUITE $COMPONENTE" \\
  | sudo tee /etc/apt/sources.list.d/redhornoma.list

sudo apt update
sudo apt install redhornoma-completo</pre>

<h2>Recibir las mejoras</h2>
<pre>sudo apt update && sudo apt upgrade</pre>

<div class="nota">
<p><b>Qué instala.</b> El informe del equipo, la virtualización de Windows,
la red del centro, el respaldo automático, los periféricos y la pantalla
única de control.</p>
<p>Software libre, construido sobre Debian, KDE, QEMU y decenas de proyectos
más.</p>
</div>
</html>
HTML
ok "index.html"

# GitHub Pages no publica carpetas que empiecen por guion bajo, y añade
# procesamiento que no queremos sobre archivos que deben viajar intactos.
touch "$REPO/.nojekyll"

# ── Subir ────────────────────────────────────────────────────────────
if [ "$SOLO_LOCAL" -eq 1 ]; then
  titulo "ARMADO, SIN SUBIR"
  ok "está en: $REPO"
  nota "usaste --local, así que no se subió a GitHub"
  exit 0
fi

titulo "SUBIENDO A GITHUB"
#
# El repositorio de GitHub «redhornoma» ya existe y guarda EL CÓDIGO FUENTE
# en la rama main. No se puede crear otro con el mismo nombre, ni haría
# falta: GitHub Pages sabe servir desde una rama distinta.
#
#     main       el código fuente del proyecto
#     gh-pages   los .deb firmados          →  la dirección de arriba
#
# Por eso repositorio/ tiene su propio git apuntando a gh-pages, y está
# ignorado desde main: si las dos ramas rastrearan los mismos archivos,
# pelearían en cada cambio.
cd "$REPO" || exit 1
if [ ! -d .git ]; then
  git init -q -b "$RAMA"
  # Se copia el origen del proyecto en vez de componer uno: así se usa la
  # misma forma de autenticarse que ya funciona (ssh o https), sin pedirle
  # a nadie que vuelva a configurar nada.
  ORIGEN=$(git -C "$BASE" remote get-url origin 2>/dev/null)
  [ -n "$ORIGEN" ] || ORIGEN="https://github.com/${GITHUB_USUARIO}/${GITHUB_REPO}.git"
  git remote add origin "$ORIGEN"
  ok "git iniciado en la rama $RAMA"
  nota "hacia $ORIGEN"
fi

git add -A
if git diff --cached --quiet && [ -n "$(git rev-parse --verify HEAD 2>/dev/null)" ]; then
  avis "no había ningún cambio que subir"
else
  git commit -q -m "Paquetes de RedHornoma — $(date '+%Y-%m-%d %H:%M')"
  ok "cambios guardados"
fi

if git push -q origin "$RAMA" 2>/dev/null || git push -q --set-upstream origin "$RAMA"; then
  ok "subido a la rama $RAMA"
else
  mal "no se pudo subir"
  nota "Comprueba que tienes acceso a $GITHUB_USUARIO/$GITHUB_REPO."
  nota "Se sube a la rama «$RAMA»; la rama «main» con el código no se toca."
  exit 1
fi

# ── Esperar a que GitHub lo despliegue de verdad ─────────────────────
#
# Subir no es publicar. GitHub Pages tarda uno o dos minutos en rehacer la
# página, y durante ese rato sigue sirviendo lo anterior.
#
# El 2026-08-06 esto engañó tres veces seguidas: el guion decía «LISTO», se
# corría «apt update» en el servidor, bajaba la versión vieja, y parecía que
# el paquete nuevo no existía. Una vez llegó a instalarse una herramienta que
# no era la que se acababa de corregir.
#
# Decir «listo» cuando todavía no lo está es la clase de mentira pequeña que
# hace perder media hora buscando un fallo que no existe.
titulo "ESPERANDO A QUE GITHUB LO PUBLIQUE"
LOCAL_SHA=$(sha256sum "$DIST/Packages" | cut -d' ' -f1)
BAJAR="$URL/dists/$SUITE/$COMPONENTE/binary-$ARQ/Packages"
TMPP=$(mktemp); trap 'rm -f "$TMPP"' EXIT
VIVO=0

if command -v wget >/dev/null 2>&1; then TRAER="wget -qO"
elif command -v curl >/dev/null 2>&1; then TRAER="curl -sfo"
else TRAER=""; fi

# No se espera hasta el final: la red de GitHub guarda cada archivo hasta
# DIEZ minutos (Cache-Control: max-age=600) y no hay forma de saltárselo —se
# probaron parámetros y cabeceras, y sigue devolviendo lo anterior—. Quedarse
# mirando una barra diez minutos no ayuda a nadie.
#
# Se espera tres minutos, que cubren el caso normal, y si no, se dice cuánto
# falta de verdad en vez de dejarlo en el aire.
if [ -n "$TRAER" ]; then
  for INTENTO in $(seq 1 18); do
    if $TRAER "$TMPP" "$BAJAR" 2>/dev/null \
       && [ "$(sha256sum "$TMPP" | cut -d' ' -f1)" = "$LOCAL_SHA" ]; then
      VIVO=1; break
    fi
    printf "\r   esperando… %s s de 180" "$((INTENTO*10))"
    sleep 10
  done
  printf "\r%*s\r" 44 ""
fi

if [ "$VIVO" = 1 ]; then
  ok "GitHub ya sirve estos paquetes — los centros pueden actualizarse YA"
elif [ -z "$TRAER" ]; then
  avis "no puedo comprobarlo (falta wget y curl). Espera unos minutos."
else
  # Cuánto falta, de la propia respuesta de GitHub, en vez de adivinar.
  EDAD=$(wget -qS --spider "$BAJAR" 2>&1 | grep -i '^ *Age:' | tr -dc '0-9')
  RESTA=$(( 600 - ${EDAD:-0} ))
  [ "$RESTA" -lt 0 ] && RESTA=0
  avis "subido, pero GitHub todavía sirve la copia anterior"
  nota "Su red guarda cada archivo 10 minutos y no se puede saltar."
  nota "Quedan unos $(( (RESTA + 59) / 60 )) minuto(s). Para comprobarlo:"
  printf "\n      wget -qO- %s | grep -E '^(Package|Version):'\n\n" "$BAJAR"
  nota "Hasta entonces, «apt update» en los centros traerá lo de antes."
fi

titulo "LISTO"
ok "$URL"
printf "\n"
nota "Si es la primera vez, falta encenderlo en GitHub — una sola vez:"
nota "   Settings → Pages → Branch: $RAMA → carpeta: / (root) → Save"
