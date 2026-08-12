#!/bin/bash
# en-windows.sh — Ejecutar una orden DENTRO del Windows y traer su respuesta.
#
# Usa el agente invitado, así que no hace falta abrir la pantalla de Windows
# ni que haya nadie delante. Es lo mismo que hace «redhornoma-en-windows»,
# escrito aquí suelto porque el .101 tiene la versión vieja de esa herramienta.
#
# Uso:  en-windows.sh 'dir C:\SOAPS7'
set -u
VM=${VM:-salud-servidor}

# Dos modos:
#   en-windows.sh 'dir C:\SOAPS7'          → por cmd
#   en-windows.sh --ps 'Get-ChildItem …'   → por PowerShell
#
# El modo --ps existe porque meter PowerShell DENTRO de cmd obliga a anidar
# comillas, y ahí se rompe: el 10/08/2026 la orden salió escrita en la
# pantalla en vez de ejecutarse. Al agente se le pasan los argumentos en una
# lista, así que hablándole directo a powershell.exe no hay comillas que
# escapar.
MOTOR=cmd
if [ "${1:-}" = "--ps" ]; then MOTOR=ps; shift; fi
ORDEN="${1:?falta la orden}"

vsh(){ LC_ALL=C virsh -c qemu:///system "$@"; }

# El agente recibe la orden en JSON, así que hay que escapar las comillas y
# las barras invertidas de las rutas de Windows. Python lo hace bien; hacerlo
# con sed a mano es donde se rompen estas cosas.
JSON=$(python3 -c '
import json, sys
motor, orden = sys.argv[1], sys.argv[2]
if motor == "ps":
    prog, args = "powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", orden]
else:
    prog, args = "cmd.exe", ["/c", orden]
print(json.dumps({"execute":"guest-exec","arguments":{
  "path":prog, "arg":args, "capture-output":True}}))' "$MOTOR" "$ORDEN")

PID=$(vsh qemu-agent-command "$VM" "$JSON" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["return"]["pid"])' 2>/dev/null)
[ -n "${PID:-}" ] || { echo "no pude lanzar la orden dentro de Windows" >&2; exit 1; }

# Se espera a que termine. Sin esperar, la salida llega vacía y parece que la
# orden no hizo nada.
for _ in $(seq 1 40); do
  RES=$(vsh qemu-agent-command "$VM" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$PID}}" 2>/dev/null)
  echo "$RES" | grep -q '"exited":true' && break
  sleep 1
done

python3 - "$RES" <<'PY'
import base64, json, sys
try:
    r = json.loads(sys.argv[1])["return"]
except Exception:
    print("(sin respuesta del agente)"); raise SystemExit
for campo in ("out-data", "err-data"):
    d = r.get(campo)
    if d:
        try:    print(base64.b64decode(d).decode("cp850", "replace"))
        except Exception: print(base64.b64decode(d).decode("utf-8", "replace"))
print("  [código de salida: %s]" % r.get("exitcode"))
PY
