# instalar-puesto.ps1 — Convertir un Windows cualquiera en puesto del centro.
#
# Lo que hace, en orden:
#   1 · registra los componentes que SOAPS necesita
#   2 · le dice dónde está el motor de datos
#   3 · deja los accesos directos, y BORRA los que traiga de otro centro
#
# Nada de esto guarda información en la máquina: todo lo que se escriba va
# al servidor. Si el portátil se va, no se lleva nada.

# 🔴 Aquí había un bloque «param()». PowerShell lo exige como PRIMERA
# instrucción del guion, y por el camino que usamos —el agente invitado, que
# envuelve el texto antes de ejecutarlo— deja de serlo y revienta con «la
# expresión de asignación no es válida». Con variables normales no pasa.
$Servidor      = "192.168.1.50"    # el WINDOWS del servidor
$ServidorLinux = "192.168.1.101"   # su Linux, que sirve los documentos
$Instancia     = "SUIS"
$Usuario       = "@@USUARIO@@"     # los rellena quien lanza el instalador
$Clave         = "@@CLAVE@@"

$ErrorActionPreference = "Continue"
$raiz = "\\$Servidor\SOAPS"
$w    = "$env:WINDIR\SysWOW64"
$ok = 0; $mal = 0; $saltados = 0

function Paso($t) { ""; "== $t" }

# ── 0 · Conectarse a las carpetas del servidor ────────────────────────
#
# 🔴 El instalador se conecta EL MISMO, no da por hecho que ya lo esté.
#
# Las contraseñas de red en Windows son de cada sesión: lo que conecta una
# persona no lo ve otra, y lo que conecta un programa de sistema no lo ve
# nadie. El 16/08/2026 esto se aprendió a golpes — el instalador funcionó
# una vez y a la siguiente dijo «no se llega», sin que nadie hubiera tocado
# nada. Un instalador que depende de un paso previo invisible no es un
# instalador.
if ($Usuario -and $Usuario -notmatch '^@@') {
  foreach ($s in 'SOAPS','SALMI','SNIS') {
    $ruta = '\\' + $Servidor + '\' + $s
    net use $ruta /delete /y 2>&1 | Out-Null
    net use $ruta /user:$Usuario $Clave /persistent:yes 2>&1 | Out-Null
  }
}
if (-not (Test-Path $raiz)) {
  "   NO se llega a $raiz"
  "   Comprueba la cuenta y la contrasena de la carpeta compartida."
  exit 1
}

# ── 1 · Los componentes ───────────────────────────────────────────────
#
# Se copian al SysWOW64 y se registran. Son de 32 bits: SOAPS es un
# programa de Visual Basic 6, y en un Windows de 64 bits los de 32 viven
# ahí, no en System32. Confundirlo es el error clásico.
Paso "REGISTRANDO LOS COMPONENTES"
$origenes = @("$raiz\registrarDlls", "$raiz\PUESTO", $raiz)
foreach ($o in $origenes) {
  if (-not (Test-Path $o)) { continue }
  # 🔴 «-Include» sin comodín en la ruta NO filtra el contenido: filtra la
  # ruta misma, y devuelve casi nada. La primera vez proceso 4 archivos de
  # 36 y el guion dijo que había terminado bien. Con «\*» al final sí mira
  # dentro. Es de los errores que no avisan: no falla, hace menos.
  foreach ($f in Get-ChildItem "$o\*" -File -Include *.ocx,*.dll -EA SilentlyContinue) {
    try { Copy-Item $f.FullName "$w\$($f.Name)" -Force -EA Stop } catch { $mal++; continue }
    $p = Start-Process -FilePath "$env:WINDIR\SysWOW64\regsvr32.exe" `
         -ArgumentList "/s","`"$w\$($f.Name)`"" -Wait -PassThru -WindowStyle Hidden
    # Código 4 = no es un componente que se registre. No es un fallo: hay
    # piezas que solo tienen que ESTAR, como las de Crystal Reports.
    if ($p.ExitCode -eq 0)      { $ok++ }
    elseif ($p.ExitCode -eq 4)  { $saltados++ }
    else                        { $mal++; "   falló $($f.Name) (código $($p.ExitCode))" }
  }
}
"   {0} registrados · {1} copiados sin registrar · {2} con problema" -f $ok, $saltados, $mal

# ── 2 · Dónde está el motor de datos ──────────────────────────────────
#
# Sin esta clave, SOAPS dice «El sistema no está bien instalado, consulte
# con su proveedor» y no hay forma de adivinar por qué.
Paso "DICIENDOLE DONDE ESTA LA INFORMACION"
$reg = "$raiz\PUESTO\SUIS.reg"
if (Test-Path $reg) {
  reg import $reg 2>&1 | Out-Null
  $clave = "HKLM:\SOFTWARE\WOW6432Node\$Instancia"
  if (Test-Path $clave) {
    # El servidor exporta «.\SUIS», que significa «yo mismo». En un puesto
    # eso apuntaría a su propio Windows, donde no hay ninguna base.
    Set-ItemProperty -Path $clave -Name "SERVIDOR" -Value "$Servidor\$Instancia" -EA SilentlyContinue
    $v = (Get-ItemProperty -Path $clave -EA SilentlyContinue).SERVIDOR
    "   OK  apunta a: $v"
  } else { "   FALLO: la configuracion no quedó puesta" }
} else { "   NO encuentro $reg" }

# ── 3 · Los accesos, y los que sobran ─────────────────────────────────
#
# 🔴 Borrar los viejos es tan importante como poner los nuevos. Un portátil
# que estuvo en otro centro trae accesos que apuntan allá, y quien los
# pulse escribirá —o creerá escribir— en el sitio equivocado. Y el icono
# del SALMI LOCAL es peor todavía: abre una base vacía de la propia
# máquina, no ve ningún paciente, y parece que se perdió todo el centro.
Paso "ACCESOS DIRECTOS"
$escritorio = "$env:PUBLIC\Desktop"
$ws = New-Object -ComObject WScript.Shell
$quitados = 0
foreach ($l in Get-ChildItem "$escritorio\*.lnk" -EA SilentlyContinue) {
  $t = $ws.CreateShortcut($l.FullName).TargetPath
  $sospechoso = $false
  # Apunta a OTRO servidor.
  #
  # 🔴 Ojo con esto: el centro tiene DOS direcciones —el Windows con los
  # programas y su Linux, que sirve los documentos—. La primera versión solo
  # conocía la del Windows y borró el acceso a «Documentos del centro», que
  # era bueno. Un limpiador que se lleva lo bueno es peor que no limpiar.
  if ($t -match '^\\\\' -and
      $t -notmatch [regex]::Escape($Servidor) -and
      $t -notmatch [regex]::Escape($ServidorLinux)) { $sospechoso = $true }
  # O apunta a un programa de salud LOCAL, que es una base vacía
  if ($t -match '^[A-Za-z]:\\(SALMI|SOAPS|SNIS)') { $sospechoso = $true }
  if ($sospechoso) { Remove-Item $l.FullName -Force -EA SilentlyContinue; $quitados++; "   quitado: $($l.BaseName) -> $t" }
}
if ($quitados -eq 0) { "   no habia accesos de otro centro" }

# Los tres programas del Ministerio, cada uno con su ejecutable. Se ponen
# aunque desde aquí no se pueda comprobar que se llega: las contraseñas de
# red son de CADA PERSONA, y este guion puede estar corriendo con otra
# cuenta. El acceso se crea igual y funciona cuando lo pulsa quien tiene la
# contraseña. Comprobar aquí y no ponerlo por eso seria el error contrario.
$nuevos = [ordered]@{
  "SOAPS del centro"      = "\\$Servidor\SOAPS\SOAPS_7.exe"
  "SALMI del centro"      = "\\$Servidor\SALMI\SalmiDis.exe"
  "SNIS del centro"       = "\\$Servidor\SNIS\snis_2026.exe"
  "Documentos del centro" = "\\$ServidorLinux\documentos"
}
foreach ($n in $nuevos.Keys) {
  $destino = $nuevos[$n]
  $s = $ws.CreateShortcut("$escritorio\$n.lnk")
  $s.TargetPath = $destino
  $s.WorkingDirectory = Split-Path $destino -Parent
  $s.Save()
  "   puesto: $n -> $destino"
}

# ── Comprobar ─────────────────────────────────────────────────────────
Paso "COMPROBANDO"
"   carpeta del programa : {0}" -f $(if (Test-Path "$raiz\SOAPS_7.exe") { "se llega" } else { "NO" })
$c = "HKLM:\SOFTWARE\WOW6432Node\$Instancia"
"   apunta al servidor   : {0}" -f $(if (Test-Path $c) { (Get-ItemProperty $c).SERVIDOR } else { "sin configurar" })
"   componentes          : {0} registrados" -f $ok
