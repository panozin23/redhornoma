#!/usr/bin/env python3
"""Saca un archivo del Windows invitado por el agente, en trozos de 512 KB.

Uso:
    python3 windows_sacar_archivo.py 'C:\\ruta\\archivo.mdb'  destino.mdb

512 KB por trozo está medido, no supuesto: no cambiarlo sin volver a medir.

Si el archivo está EN USO (una base de Access abierta por SALMI, por ejemplo),
esto falla con «el proceso no tiene acceso al archivo». La salida es copiarlo
antes dentro de Windows abriéndolo con lectura compartida, y sacar la copia:

    $in  = New-Object System.IO.FileStream($origen,'Open','Read','ReadWrite')
    $out = New-Object System.IO.FileStream($copia,'Create','Write')
    $in.CopyTo($out); $out.Close(); $in.Close()
"""
import base64, sys
from windows_mandar import agente

TROZO = 512 * 1024          # medido: mas grande no aporta, mas chico va lento


def sacar(ruta_win, destino):
    h = agente({"execute": "guest-file-open",
                "arguments": {"path": ruta_win, "mode": "rb"}})
    total = 0
    try:
        with open(destino, "wb") as f:
            while True:
                r = agente({"execute": "guest-file-read",
                            "arguments": {"handle": h, "count": TROZO}})
                datos = base64.b64decode(r.get("buf-b64") or "")
                if datos:
                    f.write(datos)
                    total += len(datos)
                    print(f"\r  {total/1048576:.2f} MB", end="", flush=True)
                if r.get("eof") or not datos:
                    break
    finally:
        agente({"execute": "guest-file-close", "arguments": {"handle": h}})
    print(f"\r  {total/1048576:.2f} MB  -> {destino}")
    return total


if __name__ == "__main__":
    sacar(sys.argv[1], sys.argv[2])
