#!/usr/bin/env python3
"""Ejecuta PowerShell DENTRO del Windows de un servidor, desde aquí.

Usa el agente de QEMU, así que no hace falta ni red hacia el Windows ni
tocar su pantalla.  El código se manda en base64 (-EncodedCommand) para
que no haya que pelear con las comillas de tres capas: bash → ssh → virsh.
"""
import base64, json, subprocess, sys, time

HOST = sys.argv[1]
VM   = sys.argv[2]
CODE = sys.argv[3]
ESPERA = int(sys.argv[4]) if len(sys.argv) > 4 else 90


def agente(payload):
    j = json.dumps(payload)
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", HOST,
         "virsh -c qemu:///system qemu-agent-command %s %s" %
         (VM, "'" + j.replace("'", "'\\''") + "'")],
        capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise SystemExit("❌ el agente no contestó:\n" + r.stderr.strip())
    return json.loads(r.stdout)["return"]


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
