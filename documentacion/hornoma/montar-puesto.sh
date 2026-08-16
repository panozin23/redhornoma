#!/bin/bash
# Monta un puesto: saca la cuenta del servidor y lanza el instalador dentro
# del Windows indicado. La contraseña no se enseña en ningún momento.
set -u
SRV_LINUX=${SRV_LINUX:-192.168.1.101}
VM=${1:-salud-puesto}
BASE=$(dirname "$0")

echo "── pidiendo la cuenta al servidor (te pedirá TU contraseña de la $SRV_LINUX) ──"
CRED=$(ssh -t "hornoma@$SRV_LINUX" 'sudo cat /etc/redhornoma/windows-cifs.credenciales' 2>/dev/null | tr -d '\r')
U=$(printf '%s\n' "$CRED" | grep -oP '^username=\K.*' | head -1)
P=$(printf '%s\n' "$CRED" | grep -oP '^password=\K.*' | head -1)
[ -n "$U" ] && [ -n "$P" ] || { echo "   ❌ no pude leer la cuenta"; exit 1; }
echo "   ✅ cuenta obtenida: $U"

G=$(mktemp /tmp/rh-instalar-XXXX.ps1); trap 'rm -f "$G"' EXIT
sed -e "s|@@USUARIO@@|$U|" -e "s|@@CLAVE@@|$P|" "$BASE/instalar-puesto.ps1" > "$G"
echo "── instalando en «$VM» ──"
redhornoma-en-windows --maquina "$VM" --guion "$G"
