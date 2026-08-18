# instalar-puesto.ps1 - Convertir el Windows de un visitante en puesto del centro.
#
# PARA QUIEN ES
#
# Para el portatil que trae un medico que viene un dia: el dentista, la
# doctora del Bono. No es una maquina del centro, no tiene RedHornoma, y al
# terminar la jornada se va. Tiene que quedar como estaba.
#
# Nada de lo que escriba esa persona se guarda aqui: todo va al servidor.
# Si el portatil se va, no se lleva informacion del centro.
#
# ══════════════════════════════════════════════════════════════════════
# LA TRAMPA QUE ORDENA TODO ESTE GUION, Y QUE COSTO EL 16/08/2026
#
# En Windows hacen falta DOS permisos distintos, y son incompatibles:
#
#   registrar los componentes  ->  hace falta ADMINISTRADOR
#   conectar las carpetas      ->  hace falta LA SESION DE LA PERSONA
#
# Y las contraseñas de red en Windows son de cada sesion: lo que conecta
# el administrador NO lo ve la persona, aunque sea la misma computadora.
# Por eso un instalador que se eleve entero deja los accesos directos
# apuntando a carpetas que la persona no tiene conectadas: al pulsarlos
# dice "no se puede llegar", sin mas explicacion.
#
# Asi que el guion se ejecuta DOS VECES, a proposito:
#
#   1a vez - como la persona: conecta las carpetas para SU sesion, pone
#            los accesos directos y aparta la red del centro de su internet
#   2a vez - se relanza pidiendo permiso de administrador: copia y
#            registra los componentes y escribe la configuracion del motor
#            de datos, con su propia conexion temporal, que suelta al salir
# ══════════════════════════════════════════════════════════════════════
#
# Uso:
#   Instalar.bat                 lo normal, doble clic
#   instalar-puesto.ps1 -Admin   la segunda pasada; la lanza el propio guion

param([switch]$Admin)

$ErrorActionPreference = "Continue"

# ── Donde esta el centro ──────────────────────────────────────────────
# Los rellena «redhornoma-visitante» al publicar la carpeta, con las
# direcciones de ESTE centro. Si alguien copia el archivo a otro centro y
# no los cambia, se ve a simple vista que estan sin rellenar.
$Servidor      = "@@SERVIDOR_WINDOWS@@"   # el Windows con los programas
$ServidorLinux = "@@SERVIDOR_LINUX@@"     # su Linux, que sirve los documentos
$NombreCentro  = "@@NOMBRE_CENTRO@@"
$Instancia     = "SUIS"

$raiz    = "\\$Servidor\SOAPS"
$w       = "$env:WINDIR\SysWOW64"
$carpetas = @('SOAPS','SALMI','SNIS')
# Lo que se toca queda apuntado aqui, para que «Quitar.bat» deshaga
# exactamente esto y nada mas.
$Registro = "$env:PUBLIC\redhornoma-puesto.txt"

function Titulo($t) { ""; "  == $t" }
function Bien($t)   { "     OK   $t" }
function Mal($t)    { "     ---  $t" }

function EsAdministrador {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ══════════════════════════════════════════════════════════════════════
#  SEGUNDA PASADA - lo que necesita permiso de administrador
# ══════════════════════════════════════════════════════════════════════
if ($Admin) {
  # La cuenta viene por variable de entorno y no por la linea de comandos:
  # lo que se escribe en la linea de comandos lo puede leer cualquiera que
  # mire la lista de procesos mientras corre.
  $Usuario = $env:RH_USUARIO
  $Clave   = $env:RH_CLAVE

  Titulo "REGISTRANDO LOS COMPONENTES (como administrador)"

  # Esta sesion es OTRA sesion: necesita su propia conexion, aunque la
  # persona ya la tenga hecha en la suya.
  if ($Usuario) {
    cmd /c "net use $raiz /delete /y" 2>&1 | Out-Null
    cmd /c "net use $raiz /user:$Usuario $Clave" 2>&1 | Out-Null
  }

  if (-not (Test-Path $raiz)) {
    Mal "no se llega a $raiz ni como administrador"
    Mal "los componentes no se registraron"
    exit 1
  }

  $ok = 0; $mal = 0; $saltados = 0
  # Se copian al SysWOW64 y se registran. Son de 32 bits: SOAPS es un
  # programa de Visual Basic 6, y en un Windows de 64 bits los de 32 viven
  # ahi, no en System32. Confundirlo es el error clasico.
  foreach ($o in @("$raiz\registrarDlls", "$raiz\PUESTO", $raiz)) {
    if (-not (Test-Path $o)) { continue }
    # El «\*» del final NO sobra. «-Include» sin comodin en la ruta filtra
    # LA RUTA, no el contenido: devuelve casi nada. La primera vez proceso
    # 4 archivos de 36 y dijo que habia terminado bien.
    foreach ($f in Get-ChildItem "$o\*" -File -Include *.ocx,*.dll -EA SilentlyContinue) {
      try { Copy-Item $f.FullName "$w\$($f.Name)" -Force -EA Stop } catch { $mal++; continue }
      $p = Start-Process -FilePath "$env:WINDIR\SysWOW64\regsvr32.exe" `
           -ArgumentList "/s","`"$w\$($f.Name)`"" -Wait -PassThru -WindowStyle Hidden
      # Codigo 4 = no es un componente que se registre. No es un fallo: hay
      # piezas que solo tienen que ESTAR, como las de Crystal Reports.
      if     ($p.ExitCode -eq 0) { $ok++ }
      elseif ($p.ExitCode -eq 4) { $saltados++ }
      else                       { $mal++ }
    }
  }
  "     {0} registrados - {1} copiados sin registrar - {2} con problema" -f $ok, $saltados, $mal

  # ── Donde esta el motor de datos ──
  # Sin esta clave, SOAPS dice "El sistema no esta bien instalado, consulte
  # con su proveedor" y no hay forma de adivinar por que.
  Titulo "DICIENDOLE DONDE ESTA LA INFORMACION"
  $reg = "$raiz\PUESTO\SUIS.reg"
  if (Test-Path $reg) {
    cmd /c "reg import `"$reg`"" 2>&1 | Out-Null
    $clave = "HKLM:\SOFTWARE\WOW6432Node\$Instancia"
    if (Test-Path $clave) {
      # El servidor exporta «.\SUIS», que significa "yo mismo". En un puesto
      # eso apuntaria a su propio Windows, donde no hay ninguna base.
      Set-ItemProperty -Path $clave -Name "SERVIDOR" -Value "$Servidor\$Instancia" -EA SilentlyContinue
      Bien ("apunta a: " + (Get-ItemProperty -Path $clave -EA SilentlyContinue).SERVIDOR)
    } else { Mal "la configuracion no quedo puesta" }
  } else { Mal "no encuentro $reg" }

  # Esta sesion de administrador se va: que no deje la conexion abierta.
  if ($Usuario) { cmd /c "net use $raiz /delete /y" 2>&1 | Out-Null }
  exit 0
}

# ══════════════════════════════════════════════════════════════════════
#  PRIMERA PASADA - como la persona que va a trabajar
# ══════════════════════════════════════════════════════════════════════
""
"  ======================================================"
"   PUESTO DEL CENTRO $NombreCentro"
"  ======================================================"
""
"   Esta computadora va a poder abrir SOAPS, SALMI y SNIS del centro."
"   Nada se guarda aqui: todo se escribe en el servidor."
""

if ($Servidor -like '@@*') {
  Mal "este instalador no esta preparado para ningun centro"
  Mal "hay que publicarlo con 'redhornoma-visitante' en el servidor"
  exit 1
}

# ── La cuenta de las carpetas compartidas ─────────────────────────────
# Se pide aqui y no viene escrita en el archivo: la carpeta desde la que se
# lanza esto se lee SIN contraseña -tiene que ser asi, si no el visitante
# no podria llegar a ella- y dejar ahi la clave del centro seria dejarla a
# la vista de cualquiera que se conecte al wifi.
"   Pide al encargado del centro la cuenta de las carpetas."
""
$Usuario = Read-Host "   Usuario  (normalmente salmired)"
if (-not $Usuario) { $Usuario = "salmired" }
$ClaveSegura = Read-Host "   Contrasena" -AsSecureString
$Clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
           [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClaveSegura))

Titulo "CONECTANDO LAS CARPETAS DEL CENTRO"
$conectadas = 0
foreach ($s in $carpetas) {
  $ruta = "\\$Servidor\$s"
  cmd /c "net use $ruta /delete /y" 2>&1 | Out-Null
  # «/persistent:yes» para que siga conectado despues de reiniciar: el
  # medico no tiene por que volver a hacer esto cada manana.
  cmd /c "net use $ruta /user:$Usuario $Clave /persistent:yes" 2>&1 | Out-Null
  if (Test-Path $ruta) { Bien $ruta; $conectadas++ } else { Mal "$ruta no responde" }
}
if ($conectadas -eq 0) {
  ""
  Mal "No se llego a ninguna carpeta del centro."
  Mal "Puede ser la contrasena, o que esta computadora no este en el wifi"
  Mal "del centro. Nada ha cambiado en esta maquina."
  exit 1
}

# ── Que su internet siga siendo el suyo ───────────────────────────────
#
# El medico llega con su propio internet -un modem de Entel, o el telefono
# compartiendo datos- y al conectarse al wifi del centro Windows puede
# decidir que la salida a internet es por ahi. Pero el wifi del centro NO
# tiene internet: es una red interna. Resultado: se queda sin internet y
# nadie entiende por que.
#
# La «metrica» es lo que Windows usa para elegir por donde salir: cuanto
# mas alta, menos preferida. Poniendole 9000 a la red del centro, esa red
# sirve para llegar al servidor y para nada mas.
Titulo "DEJANDO TU INTERNET COMO ESTABA"
$mio = $null
try {
  # La tarjeta por la que se llega al servidor: esa, y solo esa.
  $ruta1 = Find-NetRoute -RemoteIPAddress $Servidor -EA Stop | Select-Object -First 1
  $mio = $ruta1.InterfaceIndex
} catch { }
if ($mio) {
  try {
    $antes = (Get-NetIPInterface -InterfaceIndex $mio -AddressFamily IPv4 -EA Stop).InterfaceMetric
    Set-NetIPInterface -InterfaceIndex $mio -AddressFamily IPv4 -InterfaceMetric 9000 -EA Stop
    $nombre = (Get-NetAdapter -InterfaceIndex $mio -EA SilentlyContinue).Name
    Bien "la red del centro ($nombre) ya no te quita el internet"
    "metrica|$mio|$antes" | Out-File -FilePath $Registro -Encoding ASCII -Append
  } catch {
    Mal "no se pudo cambiar la preferencia de red (hace falta administrador)"
  }
} else {
  Mal "no supe por que tarjeta se llega al servidor - se deja como esta"
}

# ── Los accesos, y los que sobran ─────────────────────────────────────
#
# Borrar los viejos es tan importante como poner los nuevos. Un portatil
# que estuvo en otro centro trae accesos que apuntan alla, y quien los
# pulse escribira -o creera escribir- en el sitio equivocado. Y el icono
# del SALMI LOCAL es peor todavia: abre una base vacia de la propia
# maquina, no ve ningun paciente, y parece que se perdio todo el centro.
Titulo "ACCESOS DIRECTOS"
$escritorio = "$env:USERPROFILE\Desktop"
if (-not (Test-Path $escritorio)) { $escritorio = "$env:PUBLIC\Desktop" }
$ws = New-Object -ComObject WScript.Shell
$quitados = 0
foreach ($l in Get-ChildItem "$escritorio\*.lnk" -EA SilentlyContinue) {
  $t = $ws.CreateShortcut($l.FullName).TargetPath
  $sospechoso = $false
  # Apunta a OTRO servidor.
  #
  # Ojo: el centro tiene DOS direcciones -el Windows con los programas y su
  # Linux, que sirve los documentos-. La primera version solo conocia la del
  # Windows y borro el acceso a "Documentos del centro", que era bueno. Un
  # limpiador que se lleva lo bueno es peor que no limpiar.
  if ($t -match '^\\\\' -and
      $t -notmatch [regex]::Escape($Servidor) -and
      $t -notmatch [regex]::Escape($ServidorLinux)) { $sospechoso = $true }
  # O apunta a un programa de salud LOCAL, que es una base vacia.
  if ($t -match '^[A-Za-z]:\\(SALMI|SOAPS|SNIS)') { $sospechoso = $true }
  if ($sospechoso) {
    # Se GUARDA, no se borra: es de otra persona y de otro centro, y quien
    # instala aqui no tiene por que decidir que se pierda.
    $guardados = "$env:USERPROFILE\Accesos-de-antes-RedHornoma"
    if (-not (Test-Path $guardados)) { New-Item -ItemType Directory -Path $guardados -Force | Out-Null }
    Move-Item $l.FullName "$guardados\$($l.Name)" -Force -EA SilentlyContinue
    $quitados++
    "     apartado: $($l.BaseName)"
  }
}
if ($quitados -eq 0) { "     no habia accesos de otro centro" }
else { Bien "los apartados estan en 'Accesos-de-antes-RedHornoma', por si acaso" }

# Los tres programas del Ministerio, cada uno con su ejecutable.
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
  "     puesto: $n"
  "acceso|$escritorio\$n.lnk" | Out-File -FilePath $Registro -Encoding ASCII -Append
}
foreach ($s in $carpetas) { "carpeta|\\$Servidor\$s" | Out-File -FilePath $Registro -Encoding ASCII -Append }

# ── La segunda pasada, con permiso de administrador ───────────────────
Titulo "AHORA HACE FALTA PERMISO DE ADMINISTRADOR"
"     Windows va a preguntar si permites los cambios. Di que SI."
"     Es para registrar las piezas que SOAPS necesita."
""
$env:RH_USUARIO = $Usuario
$env:RH_CLAVE   = $Clave
try {
  $yo = $MyInvocation.MyCommand.Path
  $p = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$yo`"","-Admin" `
        -Verb RunAs -Wait -PassThru -EA Stop
  if ($p.ExitCode -eq 0) { Bien "componentes registrados" }
  else { Mal "la parte de administrador no termino bien" }
} catch {
  Mal "no se pudo pedir permiso de administrador."
  Mal "SOAPS puede quejarse de que falta un componente."
}
$env:RH_CLAVE = ""

# ── Comprobar de verdad ───────────────────────────────────────────────
Titulo "COMPROBANDO"
"     el programa SOAPS      : {0}" -f $(if (Test-Path "$raiz\SOAPS_7.exe") { "se llega" } else { "NO se llega" })
$c = "HKLM:\SOFTWARE\WOW6432Node\$Instancia"
"     apunta al servidor     : {0}" -f $(if (Test-Path $c) { (Get-ItemProperty $c -EA SilentlyContinue).SERVIDOR } else { "sin configurar" })
"     accesos en el escritorio: {0}" -f (Get-ChildItem "$escritorio\*del centro.lnk" -EA SilentlyContinue).Count
""
"  ======================================================"
"   LISTO. Abre 'SOAPS del centro' desde el escritorio."
""
"   Cuando termines la jornada, abre 'Quitar.bat' de la misma"
"   carpeta del servidor: deja esta computadora como estaba."
"  ======================================================"
