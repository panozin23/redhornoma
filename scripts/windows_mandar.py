#!/usr/bin/env python3
"""Ejecuta un comando dentro de un Windows virtualizado, por el agente invitado.

Sirve para mirar y mandar dentro de un Windows sin abrir su ventana ni ir al
teclado de la máquina. Funciona aunque el Windows esté en red NAT: el agente
viaja por un canal serie de virtio, no por la red.

Uso:
    python3 windows_mandar.py cmd "dir C:\\"
    python3 windows_mandar.py ps  "Get-Service | Where-Object Status -eq Running"

Qué máquina, con variables de entorno:
    VM_URI  por omisión  qemu+ssh://flora@192.168.0.110/system   (servidor-ciudad)
    VM_DOM  por omisión  salud-servidor
    Para la del propio portátil:  VM_URI=qemu:///system VM_DOM=salud-puesto

Hace falta estar en el grupo «libvirt» — no pide sudo.

Avisos aprendidos a base de tropezar:
  - El agente corre como SISTEMA, no como el usuario que tiene la sesión
    abierta. «net use» y las unidades de red lanzadas desde aquí NO las ve el
    usuario. Para eso, una tarea programada con /RU <usuario> /IT.
  - Tras arrancar, el agente puede tardar más de cinco minutos en responder en
    máquinas viejas con disco mecánico. Que no conteste no significa que esté
    roto.
  - Nunca parar el agente sin arrancarlo en el mismo movimiento.
"""
import base64, json, os, subprocess, sys, time

URI = os.environ.get("VM_URI", "qemu+ssh://flora@192.168.0.110/system")
DOM = os.environ.get("VM_DOM", "salud-servidor")


def agente(payload):
    p = subprocess.run(
        ["virsh", "-c", URI, "qemu-agent-command", DOM, json.dumps(payload)],
        capture_output=True, text=True, timeout=60)
    if p.returncode != 0:
        raise SystemExit("ERROR virsh: " + p.stderr.strip())
    return json.loads(p.stdout)["return"]


def decodifica(b64):
    if not b64:
        return ""
    crudo = base64.b64decode(b64)
    for cp in ("utf-8", "cp850", "cp1252"):
        try:
            return crudo.decode(cp)
        except UnicodeDecodeError:
            continue
    return crudo.decode("latin-1", "replace")


def correr(path, args, espera=420):
    pid = agente({"execute": "guest-exec", "arguments": {
        "path": path, "arg": args, "capture-output": True}})["pid"]
    for _ in range(espera * 2):
        est = agente({"execute": "guest-exec-status", "arguments": {"pid": pid}})
        if est.get("exited"):
            return (est.get("exitcode"),
                    decodifica(est.get("out-data")),
                    decodifica(est.get("err-data")))
        time.sleep(0.5)
    raise SystemExit("el comando no termino a tiempo")


if __name__ == "__main__":
    modo = sys.argv[1]           # cmd | ps
    orden = sys.argv[2]
    if modo == "ps":
        cod, sal, err = correr("powershell.exe",
                               ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", orden])
    else:
        cod, sal, err = correr("cmd.exe", ["/c", orden])
    print(sal, end="")
    if err.strip():
        print("--- error ---\n" + err, end="")
    if cod:
        print(f"\n(codigo de salida {cod})")
