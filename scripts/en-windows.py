#!/usr/bin/env python3
"""Ejecuta PowerShell DENTRO del Windows de un servidor, desde aquí.

Usa el agente de QEMU, así que no hace falta ni red hacia el Windows ni
tocar su pantalla.  El código se manda en base64 (-EncodedCommand) para
que no haya que pelear con las comillas de tres capas: bash → ssh → virsh.
"""
import base64, json, os, subprocess, sys, time

HOST = sys.argv[1]
VM   = sys.argv[2]
CODE = sys.argv[3]
ESPERA = int(sys.argv[4]) if len(sys.argv) > 4 else 90


def agente(payload):
    j = json.dumps(payload)
    # «local» = la máquina donde se está ejecutando esto, sin dar el rodeo
    # por ssh. Hacía falta para mirar el Windows del propio portátil.
    if HOST in ("local", "localhost", "-"):
        orden = ["virsh", "-c", "qemu:///system",
                 "qemu-agent-command", VM, j]
    else:
        orden = ["ssh", "-o", "BatchMode=yes", HOST,
                 "virsh -c qemu:///system qemu-agent-command %s %s" %
                 (VM, "'" + j.replace("'", "'\\''") + "'")]
    r = subprocess.run(orden, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise SystemExit("❌ el agente no contestó:\n" + r.stderr.strip())
    return json.loads(r.stdout)["return"]


def sube(ruta_windows, contenido):
    """Escribe un archivo DENTRO del Windows, a trozos.

    Hace falta porque una orden larga no cabe: «guest-exec» tiene un tope y
    lo que devuelve es un «Permission denied» que despista mucho —parece un
    problema de permisos y es de tamaño—. Con el archivo subido, se ejecuta
    con «powershell -File» y ademas queda ahi para mirarlo si algo falla.
    """
    h = agente({"execute": "guest-file-open",
                "arguments": {"path": ruta_windows, "mode": "wb"}})
    try:
        # 🔴 La marca del principio (BOM) NO es un adorno: sin ella,
        # PowerShell lee el guion con la codificacion vieja de Windows y
        # cualquier acento o recuadro lo rompe con un error de sintaxis que
        # no dice nada de codificaciones. Costo un intento.
        datos = b"\xef\xbb\xbf" + contenido.encode("utf-8")
        TROZO = 48 * 1024
        for i in range(0, len(datos), TROZO):
            agente({"execute": "guest-file-write", "arguments": {
                "handle": h,
                "buf-b64": base64.b64encode(datos[i:i + TROZO]).decode()}})
    finally:
        agente({"execute": "guest-file-close", "arguments": {"handle": h}})
    return ruta_windows



if CODE.startswith("@"):
    # «@archivo.ps1» = subirlo y ejecutarlo como guion, no como orden.
    local = CODE[1:]
    destino = "C:\\Windows\\Temp\\" + os.path.basename(local)
    sube(destino, open(local, encoding="utf-8").read())
    # Solo para ESTE proceso: no se toca la politica del sistema, que
    # es una proteccion de verdad y no nuestra para cambiarla.
    CODE = ("Set-ExecutionPolicy Bypass -Scope Process -Force; & '"
            + destino + "'")

enc = base64.b64encode(CODE.encode("utf-16-le")).decode()
pid = agente({"execute": "guest-exec", "arguments": {
    "path": "powershell.exe",
    "arg": ["-NoProfile", "-NonInteractive", "-EncodedCommand", enc],
    "capture-output": True}})["pid"]

t = 0
while t < ESPERA:
    st = agente({"execute": "guest-exec-status", "arguments": {"pid": pid}})
    if st.get("exited"):
        break
    time.sleep(2); t += 2
else:
    raise SystemExit("❌ la orden no terminó en %s segundos" % ESPERA)


def sale(clave):
    d = st.get(clave)
    return base64.b64decode(d).decode("utf-8", "replace").strip() if d else ""


salida, error = sale("out-data"), sale("err-data")
if salida:
    print(salida)
if error:
    print("── error ──\n" + error, file=sys.stderr)
sys.exit(st.get("exitcode", 0))
