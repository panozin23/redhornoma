#!/usr/bin/env python3
"""
RECESA: quita del registro de Wine (system.reg / user.reg) todo bloque que
mencione alguna de las cadenas dadas (por ejemplo el codigo de producto de
una version vieja de Office, "90150000", o "Office15").

Sin esto, el Windows Installer entra en bucle de "Configurando..." al abrir
la version nueva, porque encuentra restos del estado de instalacion de la
version vieja. Descubierto el 23/08/2026 al pasar de Office 2013 a 2007.

Uso:
    python3 limpiar-vestigios-office.py --dry-run  archivo.reg cadena1 cadena2 ...
    python3 limpiar-vestigios-office.py            archivo.reg cadena1 cadena2 ...

Con Wine APAGADO (wineserver -k) antes de tocar los .reg.
"""
import sys
import shutil

def limpiar(ruta, cadenas, dry_run):
    with open(ruta, "r", encoding="utf-8", errors="surrogateescape") as f:
        lineas = f.readlines()

    # cabecera: todo lo de antes del primer bloque "[..."
    i = 0
    while i < len(lineas) and not lineas[i].startswith("["):
        i += 1
    cabecera = lineas[:i]

    bloques = []
    actual = []
    for linea in lineas[i:]:
        if linea.startswith("[") and actual:
            bloques.append(actual)
            actual = []
        actual.append(linea)
    if actual:
        bloques.append(actual)

    conservados = []
    quitados = 0
    for bloque in bloques:
        texto = "".join(bloque)
        if any(c in texto for c in cadenas):
            quitados += 1
        else:
            conservados.append(bloque)

    print(f"{ruta}: {len(bloques)} bloques, se quitan {quitados}, quedan {len(conservados)}")

    if dry_run:
        return

    shutil.copy2(ruta, ruta + ".antes-de-limpiar")
    with open(ruta, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.writelines(cabecera)
        for bloque in conservados:
            f.writelines(bloque)


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    if dry_run:
        args.remove("--dry-run")
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    ruta, *cadenas = args
    limpiar(ruta, cadenas, dry_run)


if __name__ == "__main__":
    main()
