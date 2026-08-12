# registrar-soaps.ps1 — Registrar en Windows los componentes de SOAPS 7.
#
# «Clase no registrada» no significa que falte un archivo: significa que el
# archivo está pero Windows no sabe que existe. Los programas hechos en
# Visual Basic 6 —y SOAPS lo es— piden sus piezas por un nombre apuntado en
# el registro de Windows, y si ese apunte no está, no las encuentran.
#
# Esto es el paso 4 de la receta que funcionó en Cochabamba el 06/08/2026.
#
# Se registra con el regsvr32 de 32 bits (el de SysWOW64), NO el de 64:
# SOAPS es un programa de 32 bits y el otro lo rechazaría.

$ErrorActionPreference = "Continue"
$reg = "C:\Windows\SysWOW64\regsvr32.exe"
$destino = "C:\Windows\SysWOW64"
$bien = 0
$fallos = @()

function Registrar($archivo) {
    $nombre = Split-Path $archivo -Leaf
    Copy-Item $archivo $destino -Force -ErrorAction SilentlyContinue
    $p = Start-Process $reg -ArgumentList "/s", $nombre -Wait -PassThru -WorkingDirectory $destino
    if ($p.ExitCode -eq 0) {
        $script:bien++
    } else {
        $script:fallos += "$nombre (codigo $($p.ExitCode))"
    }
}

Write-Output "=== 1. Los componentes que trae el instalador ==="
foreach ($f in Get-ChildItem "C:\SOAPS7\registrarDlls" -File -ErrorAction SilentlyContinue) {
    if ($f.Extension -match "\.(dll|ocx)$") { Registrar $f.FullName }
}
foreach ($f in Get-ChildItem "C:\Install_SOAPS\registrarDlls" -File -ErrorAction SilentlyContinue) {
    if ($f.Extension -match "\.(dll|ocx)$") { Registrar $f.FullName }
}

Write-Output "=== 2. Las piezas sueltas de la raiz de SOAPS7 ==="
# actskin4.ocx y TDBNumbr.ocx no vienen en registrarDlls y hacen falta.
foreach ($f in Get-ChildItem "C:\SOAPS7" -File -ErrorAction SilentlyContinue) {
    if ($f.Extension -match "\.(ocx)$") { Registrar $f.FullName }
}

Write-Output "=== 3. Los controles clasicos de Visual Basic 6 ==="
# Windows 10 ya no los trae registrados de fabrica.
$vb6 = @("mscomctl.ocx","msadodc.ocx","msdatgrd.ocx","msdatlst.ocx","msflxgrd.ocx",
         "msmask32.ocx","msrdo20.dll","msstdfmt.dll","comct332.ocx","comdlg32.ocx",
         "richtx32.ocx","tabctl32.ocx")
foreach ($n in $vb6) {
    $ruta = Join-Path $destino $n
    if (Test-Path $ruta) { Registrar $ruta }
}

Write-Output "=== 4. Crystal Reports, que dibuja los informes ==="
# Aqui es donde falla «Produccion de servicios»: es un informe.
$crystal = @("craxdrt.dll","crviewer.dll","CRPAIG32.DLL","crtdll.dll",
             "IMPLODE.DLL","P2SMON.DLL","cInterf.dll","cRegSiE.dll")
foreach ($n in $crystal) {
    $ruta = Join-Path $destino $n
    if (Test-Path $ruta) { Registrar $ruta }
}

Write-Output ""
Write-Output "════════════════════════════════════════"
Write-Output "  registrados bien : $bien"
Write-Output "  con problema     : $($fallos.Count)"
foreach ($f in $fallos) { Write-Output "     $f" }
Write-Output ""
Write-Output "  Nota: el codigo 4 no siempre es un fallo. Hay archivos que"
Write-Output "  simplemente no son componentes que se registren, y esta bien asi."
