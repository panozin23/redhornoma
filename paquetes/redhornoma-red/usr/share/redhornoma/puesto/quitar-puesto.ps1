# quitar-puesto.ps1 - Dejar el portatil del visitante como estaba.
#
# POR QUE ESTO EXISTE
#
# Un instalador que no sabe deshacerse no se deja usar en la maquina de
# otra persona. El dentista presta su portatil para atender un dia; si al
# irse se lleva accesos directos que no funcionan, una red que le quita el
# internet y carpetas conectadas a un servidor que ya no ve, la proxima vez
# no lo presta. Y con razon.
#
# LA REGLA: se deshace SOLO lo que se hizo, leyendolo de lo que se apunto
# al instalar. Nada de adivinar ni de barrer por si acaso.
#
# Si el archivo de apuntes no esta -alguien lo borro, o esto se instalo a
# mano-, se deshace solo lo que se puede reconocer sin ninguna duda: los
# cuatro accesos con nombre propio del centro. Lo demas se deja y se dice.

$ErrorActionPreference = "Continue"
$Registro = "$env:PUBLIC\redhornoma-puesto.txt"

function Titulo($t) { ""; "  == $t" }
function Bien($t)   { "     OK   $t" }
function Nota($t)   { "     ..   $t" }

""
"  ======================================================"
"   QUITAR EL PUESTO DEL CENTRO"
"  ======================================================"
""
"   Esto NO borra nada tuyo. Solo deshace lo que se puso"
"   para trabajar con los programas del centro."
""

$lineas = @()
if (Test-Path $Registro) {
  $lineas = Get-Content $Registro -EA SilentlyContinue
  Nota "leyendo lo que se instalo ($($lineas.Count) apuntes)"
} else {
  Nota "no encuentro los apuntes de la instalacion"
  Nota "se quitara solo lo que se reconozca con seguridad"
}

# ── 1 · Los accesos directos ──────────────────────────────────────────
Titulo "ACCESOS DIRECTOS"
$quitados = 0
foreach ($l in $lineas) {
  if ($l -notmatch '^acceso\|(.+)$') { continue }
  $ruta = $Matches[1]
  if (Test-Path $ruta) { Remove-Item $ruta -Force -EA SilentlyContinue; $quitados++ }
}
# Sin apuntes: los cuatro nombres son inconfundibles y los pone solo este
# instalador. Aun asi se comprueba que apunten a una carpeta de red, para
# no llevarse por delante un archivo que alguien llamara igual.
if ($lineas.Count -eq 0) {
  $ws = New-Object -ComObject WScript.Shell
  foreach ($d in @("$env:USERPROFILE\Desktop", "$env:PUBLIC\Desktop")) {
    foreach ($n in @("SOAPS del centro","SALMI del centro","SNIS del centro","Documentos del centro")) {
      $ruta = "$d\$n.lnk"
      if (-not (Test-Path $ruta)) { continue }
      if ($ws.CreateShortcut($ruta).TargetPath -match '^\\\\') {
        Remove-Item $ruta -Force -EA SilentlyContinue; $quitados++
      }
    }
  }
}
if ($quitados -gt 0) { Bien "$quitados accesos quitados" } else { Nota "no habia accesos que quitar" }

# ── 2 · Las carpetas conectadas ───────────────────────────────────────
#
# Se desconectan con «/persistent:no» ademas del borrado, porque se
# conectaron como permanentes: si no, Windows las vuelve a intentar en cada
# arranque y el portatil tarda en encender fuera del centro, buscando un
# servidor que ya no existe.
Titulo "CARPETAS DEL CENTRO"
$sueltas = 0
foreach ($l in $lineas) {
  if ($l -notmatch '^carpeta\|(.+)$') { continue }
  cmd /c "net use `"$($Matches[1])`" /delete /y" 2>&1 | Out-Null
  $sueltas++
}
if ($lineas.Count -eq 0) {
  # Sin apuntes: se sueltan las que apunten a SOAPS, SALMI o SNIS, sean del
  # servidor que sean. Son las tres carpetas de este instalador.
  foreach ($linea in (cmd /c "net use" 2>&1)) {
    if ($linea -match '(\\\\[^\s]+\\(SOAPS|SALMI|SNIS))\s*$') {
      cmd /c "net use `"$($Matches[1])`" /delete /y" 2>&1 | Out-Null
      $sueltas++
    }
  }
}
if ($sueltas -gt 0) { Bien "$sueltas carpetas desconectadas" } else { Nota "no habia carpetas conectadas" }

# ── 3 · La preferencia de red ─────────────────────────────────────────
#
# Se devuelve el valor EXACTO que tenia antes, apuntado al instalar. Poner
# uno "normal" a ojo seria cambiarle la red al dueño del portatil.
Titulo "PREFERENCIA DE RED"
$devuelta = $false
foreach ($l in $lineas) {
  if ($l -notmatch '^metrica\|(\d+)\|(\d+)$') { continue }
  $idx = [int]$Matches[1]; $antes = [int]$Matches[2]
  try {
    Set-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -InterfaceMetric $antes -EA Stop
    Bien "devuelta a como estaba ($antes)"
    $devuelta = $true
  } catch {
    Nota "no se pudo devolver (hace falta administrador)"
    Nota "se arregla solo al quitar y volver a poner esa red"
  }
}
if (-not $devuelta -and $lineas.Count -eq 0) {
  Nota "sin apuntes no se toca: no se cual era tu valor de antes"
}

# ── 4 · Los accesos que se habian apartado ────────────────────────────
$guardados = "$env:USERPROFILE\Accesos-de-antes-RedHornoma"
if (Test-Path $guardados) {
  Titulo "TUS ACCESOS DE ANTES"
  $n = (Get-ChildItem "$guardados\*.lnk" -EA SilentlyContinue).Count
  if ($n -gt 0) {
    foreach ($f in Get-ChildItem "$guardados\*.lnk" -EA SilentlyContinue) {
      Move-Item $f.FullName "$env:USERPROFILE\Desktop\$($f.Name)" -Force -EA SilentlyContinue
    }
    Bien "$n accesos tuyos devueltos al escritorio"
    Remove-Item $guardados -Force -Recurse -EA SilentlyContinue
  }
}

# Lo que NO se toca, y se dice para que nadie lo busque:
#
#   · los componentes copiados a SysWOW64 - son piezas comunes de Visual
#     Basic; quitarlas podria romper OTRO programa de la maquina que las
#     este usando. Ocupan poco y no molestan.
#   · la clave HKLM\...\SUIS - solo la lee SOAPS, que ya no esta.
#
# Deshacer de mas es peor que deshacer de menos: lo primero rompe la
# maquina de otra persona, lo segundo solo deja algo inofensivo.

if (Test-Path $Registro) { Remove-Item $Registro -Force -EA SilentlyContinue }

""
"  ======================================================"
"   LISTO. Esta computadora ya no es un puesto del centro."
""
"   Tu internet y tus accesos vuelven a ser los de siempre."
"  ======================================================"
