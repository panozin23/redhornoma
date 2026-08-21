# aligerar.ps1 - Quitarle al Windows del servidor lo que no usa nadie.
#
# EL PORQUE - 21/08/2026, medido, no supuesto
#
# El Windows de un servidor de salud gasta 2,48 GB. De esos, unos 800 MB se
# los comen programas que en un centro NO USA NADIE: el buscador de
# Windows, Copilot, OneDrive, el Edge que se queda en segundo plano. Y el
# freno de verdad no es la memoria: es el disco de platos, que se pasa el
# dia indexando archivos que nadie va a buscar.
#
# 🔴 LO QUE NO SE TOCA, Y ES A PROPOSITO
#
# NO se desactiva el antivirus. Es un servidor con datos de pacientes y
# salida a internet. Lo que se hace es lo que recomienda el propio
# fabricante del motor de datos: decirle al antivirus que NO revise los
# archivos de las bases. Eso quita el freno sin quitar la proteccion.
#
# Todo lo de aqui es reversible: -Deshacer lo devuelve como estaba.
param([switch]$Deshacer)

$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"
$REG = "C:\ProgramData\RedHornoma\aligerado.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $REG) | Out-Null

function Medir {
  $os = Get-CimInstance Win32_OperatingSystem
  $t = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
  $l = [math]::Round($os.FreePhysicalMemory/1MB,2)
  return [math]::Round($t-$l,2)
}
$antes = Medir
"   memoria en uso ANTES: $antes GB"
""

# ══ DESHACER ═════════════════════════════════════════════════════════
if ($Deshacer) {
  "── devolviendo todo como estaba ──"
  foreach ($s in @("WSearch")) {
    Set-Service -Name $s -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $s -ErrorAction SilentlyContinue
    "   servicio $s : " + (Get-Service $s -ErrorAction SilentlyContinue).StartType
  }
  Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled","BackgroundModeEnabled" -ErrorAction SilentlyContinue
  foreach ($t in @("\Microsoft\Windows\Application Experience\MareBackup",
                   "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                   "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                   "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator")) {
    Enable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue | Out-Null
  }
  Remove-Item $REG -ErrorAction SilentlyContinue
  "   listo - conviene reiniciar el Windows"
  exit 0
}

$hecho = @()

# ── 1 · El buscador de Windows ───────────────────────────────────────
# Es el que mas disco gasta: indexa todo el disco por si alguien busca
# algo. En un servidor no busca nadie: se entra al programa y se trabaja.
# El menu de inicio sigue funcionando igual.
$s = Get-Service WSearch -ErrorAction SilentlyContinue
if ($s -and $s.StartType -ne "Disabled") {
  Stop-Service WSearch -Force -ErrorAction SilentlyContinue
  Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue
}
$s = Get-Service WSearch -ErrorAction SilentlyContinue
if ($s -and $s.StartType -eq "Disabled") { "   ✅ buscador de Windows apagado"; $hecho += "WSearch" }
else { "   ⚠️  no se pudo apagar el buscador de Windows" }

# ── 2 · OneDrive y Copilot ───────────────────────────────────────────
# Ninguno de los dos hace nada util en un servidor de centro de salud, y
# los dos arrancan solos y se quedan en memoria.
foreach ($p in @("OneDrive","M365Copilot","Copilot")) {
  Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
# 🔴 CUIDADO CON «HKCU» AQUI - fallo el 21/08/2026
#
# Este guion lo lanza el agente, que corre como LA CUENTA DEL SISTEMA. Su
# «HKCU» es el del sistema, no el de la persona que ha iniciado sesion. Se
# quitaron los arranques del usuario equivocado y OneDrive y Copilot
# siguieron levantandose tan tranquilos.
#
# Hay que recorrer las cuentas de verdad, que cuelgan de HKU con su
# numero. Se saltan la plantilla («.DEFAULT»), las de servicio (S-1-5-18,
# -19, -20) y las auxiliares («_Classes»).
if (-not (Get-PSDrive HKU -ErrorAction SilentlyContinue)) {
  New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
}
$cuentas = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")
Get-ChildItem "HKU:\" -ErrorAction SilentlyContinue | ForEach-Object {
  $sid = $_.PSChildName
  if ($sid -notmatch "_Classes$" -and $sid -ne ".DEFAULT" -and
      $sid -notmatch "^S-1-5-(18|19|20)$") {
    $cuentas += "HKU:\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
  }
}
foreach ($k in $cuentas) {
  if (-not (Test-Path $k)) { continue }
  foreach ($n in @("OneDrive","OneDriveSetup","M365Copilot","Copilot")) {
    if (Get-ItemProperty -Path $k -Name $n -ErrorAction SilentlyContinue) {
      Remove-ItemProperty -Path $k -Name $n -ErrorAction SilentlyContinue
      $hecho += "arranque:$n"
    }
  }
}
# Y de nuevo a la memoria: pueden haber vuelto mientras se hacia lo de arriba.
foreach ($p in @("OneDrive","M365Copilot","Copilot")) {
  Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
$vivos = @("OneDrive","M365Copilot") | Where-Object { Get-Process $_ -ErrorAction SilentlyContinue }
if (-not $vivos) { "   ✅ OneDrive y Copilot fuera de memoria" }
else { "   ⚠️  siguen vivos: " + ($vivos -join ", ") }

# ── 3 · El Edge que no se va ─────────────────────────────────────────
# Se queda en segundo plano aunque se cierre. Ya costo 766 MB una vez.
$e = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
New-Item -Path $e -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $e -Name "StartupBoostEnabled"   -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $e -Name "BackgroundModeEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
$v = Get-ItemProperty -Path $e -ErrorAction SilentlyContinue
if ($v.StartupBoostEnabled -eq 0 -and $v.BackgroundModeEnabled -eq 0) {
  "   ✅ Edge ya no se queda en segundo plano"; $hecho += "Edge"
} else { "   ⚠️  no se pudo frenar el Edge de fondo" }

# ── 4 · Las tareas de telemetria ─────────────────────────────────────
# Se despiertan solas y ponen el disco al 100% en el peor momento.
$tareas = @(
 @{p="\Microsoft\Windows\Application Experience\"; n="MareBackup"},
 @{p="\Microsoft\Windows\Application Experience\"; n="Microsoft Compatibility Appraiser"},
 @{p="\Microsoft\Windows\Application Experience\"; n="ProgramDataUpdater"},
 @{p="\Microsoft\Windows\Customer Experience Improvement Program\"; n="Consolidator"})
$n = 0
foreach ($t in $tareas) {
  Disable-ScheduledTask -TaskPath $t.p -TaskName $t.n -ErrorAction SilentlyContinue | Out-Null
  $x = Get-ScheduledTask -TaskPath $t.p -TaskName $t.n -ErrorAction SilentlyContinue
  if ($x -and $x.State -eq "Disabled") { $n++ }
}
"   ✅ tareas de telemetria apagadas: $n de " + $tareas.Count
if ($n -gt 0) { $hecho += "telemetria" }

# ── 5 · El antivirus y las bases de datos ────────────────────────────
# 🔴 NO se apaga el antivirus. Se le dice que no revise los archivos de
# las bases, que es justo lo que recomienda el fabricante del motor: son
# archivos enormes que el motor abre y cierra mil veces por minuto, y
# revisarlos cada vez es el freno mas grande que puede tener un servidor.
$exc = @("C:\SOAPS7\BD","C:\SALMI-PN_Dispensacion_BO","C:\SNIS2026")
$ext = @(".mdf",".ldf",".ndf",".bak",".mdb",".ldb")
foreach ($d in $exc) { if (Test-Path $d) { Add-MpPreference -ExclusionPath $d -ErrorAction SilentlyContinue } }
foreach ($x in $ext) { Add-MpPreference -ExclusionExtension $x -ErrorAction SilentlyContinue }
$sq = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter "sqlservr.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sq) { Add-MpPreference -ExclusionProcess $sq.FullName -ErrorAction SilentlyContinue }
$pref = Get-MpPreference -ErrorAction SilentlyContinue
$ne = ($pref.ExclusionExtension | Where-Object { $ext -contains $_ }).Count
if ($ne -ge 4) { "   ✅ el antivirus deja en paz a las bases ($ne extensiones)"; $hecho += "antivirus-exclusiones" }
else { "   ⚠️  no se pudieron poner las exclusiones del antivirus" }

# ── 6 · La hibernacion ───────────────────────────────────────────────
# Reserva en disco tanto como memoria tenga la maquina - 4 GB tirados. Y
# una maquina virtual no hiberna nunca.
& powercfg.exe /h off 2>&1 | Out-Null
if (-not (Test-Path "C:\hiberfil.sys")) { "   ✅ hibernacion quitada (libera disco)"; $hecho += "hibernacion" }
else { "   ⚠️  el archivo de hibernacion sigue ahi" }

# ── 7 · Que no se duerma el procesador ───────────────────────────────
& powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
$plan = (& powercfg.exe /getactivescheme) -join " "
if ($plan -match "alto|High") { "   ✅ el procesador ya no se frena solo" }

Set-Content -Path $REG -Value ((Get-Date -Format "yyyy-MM-dd HH:mm") + "`n" + ($hecho -join "`n")) -Encoding UTF8

""
Start-Sleep -Seconds 5
$despues = Medir
"   memoria en uso ANTES  : $antes GB"
"   memoria en uso DESPUES: $despues GB"
"   liberado ahora mismo  : " + [math]::Round($antes-$despues,2) + " GB"
""
"   ⚠️ Lo que mas se nota llega al REINICIAR el Windows: el buscador y las"
"      tareas de fondo no vuelven a arrancar."
