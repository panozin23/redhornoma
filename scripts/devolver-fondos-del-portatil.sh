#!/bin/bash
# Devuelve a este portátil los 6 fondos de escritorio que la construcción
# de la ISO le sobrescribió el 18/08/2026.
#
# Los originales se sacan de la carpeta de construcción, donde están
# intactos: son los que trae el paquete «desktop-base» de Debian.
set -u
H=/usr/share/desktop-base/ceratopsian-theme/wallpaper/contents/images
C=/home/euflo/PROYECTOS-CURSALIA/redhornoma/receta/chroot/usr/share/desktop-base/ceratopsian-theme/wallpaper/contents/images

[ "$(id -u)" = "0" ] || { echo "Hace falta sudo."; exit 1; }

echo "── ANTES ──"
for f in "$H"/*.svg; do printf "   %-16s %s bytes\n" "$(basename "$f")" "$(stat -c %s "$f")"; done

fallos=0
for f in "$C"/*.svg; do
  n=$(basename "$f")
  # No se copia a ciegas: solo si el original es más grande que lo que hay
  # ahora, que es la señal de que lo de ahora es el mío.
  if [ "$(stat -c %s "$f")" -gt 3000 ]; then
    cp -f "$f" "$H/$n" || fallos=$((fallos+1))
  else
    echo "   ⚠️  $n en la construcción tampoco parece el original — NO se toca"
    fallos=$((fallos+1))
  fi
done

echo
echo "── DESPUÉS ──"
for f in "$H"/*.svg; do
  t=$(stat -c %s "$f")
  [ "$t" -gt 3000 ] && printf "   ✅ %-16s %s bytes\n" "$(basename "$f")" "$t" \
                    || printf "   🔴 %-16s %s bytes — sigue mal\n" "$(basename "$f")" "$t"
done
echo
[ "$fallos" = "0" ] && echo "   Devueltos los 6. Tu fondo vuelve a ser el de siempre." \
                    || echo "   Quedaron $fallos sin devolver."
