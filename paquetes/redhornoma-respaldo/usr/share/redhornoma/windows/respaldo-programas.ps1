# redhornoma · respaldo-programas.ps1
#
# Se ejecuta DENTRO del Windows del centro, una vez al dia, y deja en la
# carpeta compartida una copia de SOAPS y de SNIS lista para recoger.
#
# Por que existe: hasta el 08/08/2026 esas dos copias las tenia que generar
# una persona a mano desde cada programa. Al mirarlo, el ultimo respaldo de
# SOAPS era del 1 de julio: cinco semanas. Un respaldo que depende de que
# alguien se acuerde es un respaldo que no ocurre.
#
# SALMI no se toca aqui: de eso ya se encarga redhornoma-respaldo desde
# Linux, que ademas congela el disco para que la copia salga entera.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File respaldo-programas.ps1
#   powershell ... -File respaldo-programas.ps1 -Destino D:\RESPALDOS

# Cuantos paquetes se guardan en el Windows. El historial largo lo lleva
# Linux, que tiene disco y ademas se lo lleva fuera del edificio.
$Conservar = 2

# Se puede fijar el destino por delante:  $Destino = "D:\RESPALDOS"
# Si no, se elige solo mas abajo.
if (-not (Test-Path variable:Destino)) { $Destino = "" }

# ── Donde dejarlo ─────────────────────────────────────────────────────
# Si este Windows vive dentro de RedHornoma, tiene la carpeta compartida
# del anfitrion: dejarlo ahi es INSTANTANEO, porque esa carpeta ya ES un
# directorio de Linux. Sacar 60 MB por el canal del agente invitado serian
# cientos de viajes de medio mega.
#
# Si no la alcanza —el Windows fisico de un centro que ya estaba— se deja
# en disco local y Linux lo recoge por la red con smbclient.
if (-not $Destino) {
    $compartida = "\\192.168.122.1\compartido"
    if (Test-Path $compartida) { $Destino = Join-Path $compartida "RESPALDOS" }
    else                       { $Destino = "C:\RESPALDOS" }
}

$ErrorActionPreference = "Continue"
$hoy    = Get-Date -Format "yyyyMMdd"
$inicio = Get-Date
$trabajo = Join-Path $env:TEMP "redhornoma-respaldo-$hoy"
$avisos = New-Object System.Collections.ArrayList

function Paso($t) { Write-Output "== $t" }
function Bien($t) { Write-Output "   OK   $t" }
function Mal($t)  { Write-Output "   FALLO $t"; [void]$avisos.Add($t) }
function Ojo($t)  { Write-Output "   AVISO $t"; [void]$avisos.Add($t) }

if (Test-Path $trabajo) { Remove-Item $trabajo -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $trabajo -Force | Out-Null
if (-not (Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino -Force | Out-Null }

# ── SOAPS: se lo pedimos a SQL Server ─────────────────────────────────
# Copiar los .mdf a mano NO vale: el motor los tiene abiertos y la copia
# sale rota. Hay que pedirle un respaldo de verdad, y verificarlo despues:
# un respaldo sin verificar no es un respaldo.
Paso "SOAPS (SQL Server)"

$sqlcmd = $null
foreach ($v in @(160,150,140,130,120,110,100)) {
    $p = "C:\Program Files\Microsoft SQL Server\$v\Tools\Binn\SQLCMD.EXE"
    if (Test-Path $p) { $sqlcmd = $p; break }
}

if (-not $sqlcmd) {
    Ojo "no encuentro sqlcmd - se salta SOAPS"
} else {
    # Que instancia. La de SOAPS se llama SUIS, pero se busca por si acaso.
    $inst = Get-Service | Where-Object { $_.Name -like "MSSQL`$*" -and $_.Status -eq "Running" } |
            ForEach-Object { $_.Name -replace '^MSSQL\$','' } | Select-Object -First 1
    if (-not $inst) { $inst = "SUIS" }
    $srv = ".\$inst"

    # Las bases del usuario, preguntando al motor. Nada de listas fijas:
    # si manana anaden una base, esto la coge sola.
    $bases = & $sqlcmd -S $srv -E -h -1 -W -Q `
        "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0;" 2>&1 |
        Where-Object { $_ -match '^\S+$' -and $_ -notmatch 'Msg |Level |Sqlcmd' }

    if (-not $bases) {
        Mal "no pude preguntarle sus bases a SQL Server ($srv)"
    }
    foreach ($b in $bases) {
        $bak = Join-Path $trabajo "$b.bak"
        & $sqlcmd -S $srv -E -b -Q "BACKUP DATABASE [$b] TO DISK = N'$bak' WITH INIT, CHECKSUM;" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Mal "no se pudo respaldar $b"; continue }
        & $sqlcmd -S $srv -E -b -Q "RESTORE VERIFYONLY FROM DISK = N'$bak' WITH CHECKSUM;" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Mal "$b se respaldo pero NO VERIFICA"; Remove-Item $bak -Force -EA SilentlyContinue; continue }
        Bien ("{0}  ({1} MB)" -f $b, [math]::Round((Get-Item $bak).Length/1MB,1))
    }
}

# ── SNIS: la carpeta ENTERA ───────────────────────────────────────────
# Aqui si vale copiar archivos, pero solo si NADIE los tiene abiertos.
# Access deja un .ldb junto a cada base mientras alguien esta dentro; si
# lo hay, la copia puede salir a medias. Se copia igual —mejor eso que
# nada— pero se deja dicho en el nombre, para que nadie confie en ella
# sin saberlo.
#
# Se lleva la CARPETA ENTERA, no solo los .mdb. Hasta el 08/08/2026 solo
# se copiaban las bases, y al mirarlo se vio lo que quedaba fuera:
#
#   Conexion2026.bin   la configuracion de ESTE centro: donde estan sus
#                      datos. Sin ella, SNIS vuelve con la informacion
#                      pero sin saber donde buscarla
#   los 16 .exe        los programas de SNIS. Sin ellos habria que
#                      encontrar el instalador del Ministerio, y en un
#                      centro rural eso un martes es una odisea
#   los 10 .xlt        las plantillas de Excel de los informes
#   el .sin y el .ico
#
# Son 19 MB mas en crudo y unos 10 comprimidos. A cambio, el respaldo
# pasa de «tengo los datos» a «puedo levantar SNIS entero sin buscar
# nada». Para un centro, esa diferencia es el dia entero.
#
# Los .ldb no: son candados de sesiones vivas, no sirven para nada fuera.
Paso "SNIS (carpeta entera)"

$snis = "C:\SNIS2026"
if (-not (Test-Path $snis)) {
    Ojo "no existe $snis - se salta SNIS"
} else {
    $abierto = @(Get-ChildItem $snis -Filter *.ldb -EA SilentlyContinue).Count -gt 0
    $carpeta = Join-Path $trabajo "SNIS2026"
    New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
    $n = 0; $mb = 0
    foreach ($f in Get-ChildItem $snis -File -Recurse -EA SilentlyContinue |
                   Where-Object { $_.Extension -ne ".ldb" }) {
        try {
            $rel = $f.FullName.Substring($snis.Length + 1)
            $dest = Join-Path $carpeta $rel
            $dir = Split-Path $dest -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item $f.FullName -Destination $dest -ErrorAction Stop
            $n++; $mb += $f.Length
        } catch { Mal ("no se pudo copiar {0}" -f $f.Name) }
    }
    Bien ("{0} archivos  ({1} MB)" -f $n, [math]::Round($mb/1MB,1))

    # Las piezas que, si faltan, dejan el respaldo cojo sin que se note.
    foreach ($clave in @("Conexion2026.bin", "snis2026.mdb", "snismain.mdb")) {
        if (Test-Path (Join-Path $carpeta $clave)) { Bien ("esta {0}" -f $clave) }
        else { Mal ("FALTA {0} - el respaldo de SNIS queda incompleto" -f $clave) }
    }
    if ($n -eq 0) { Mal "no se copio ningun archivo de SNIS" }
    if ($abierto) { Ojo "SNIS estaba ABIERTO: la copia de sus bases puede estar a medias" }
}

# ── Empaquetar ────────────────────────────────────────────────────────
# Los .bak de SQL Server son muy repetitivos y encogen mucho. Eso es lo
# que hace que quepan en la nube de un centro con internet rural, que era
# la razon por la que hasta ahora no se recogian.
Paso "Empaquetando"

$sufijo = ""
if ($avisos.Count -gt 0) { $sufijo = "-CON-AVISOS" }
$zip = Join-Path $Destino ("programas-{0}{1}.zip" -f $hoy, $sufijo)
if (Test-Path $zip) { Remove-Item $zip -Force -EA SilentlyContinue }

# Un parte dentro del paquete: quien lo hizo, cuando, y que fallo.
$parte = Join-Path $trabajo "PARTE.txt"
@(
  "Respaldo de programas - RedHornoma"
  ("Equipo:  {0}" -f $env:COMPUTERNAME)
  ("Fecha:   {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  ""
  "Contenido:"
) + @(Get-ChildItem $trabajo -Recurse -File | ForEach-Object {
        "  {0}  ({1} MB)" -f $_.Name, [math]::Round($_.Length/1MB,1) }) + @(
  ""
  $(if ($avisos.Count -eq 0) { "Sin avisos: la copia es de fiar." }
    else { "AVISOS - no fiarse del todo:" })
) + @($avisos | ForEach-Object { "  - $_" }) | Set-Content $parte -Encoding UTF8

try {
    # Hacen falta LAS DOS: ZipFile y ZipFileExtensions viven en
    # .FileSystem, pero ZipArchiveMode vive en la otra.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # Se arma entrada por entrada en vez de con CreateFromDirectory porque
    # ese metodo guarda las rutas con barra INVERTIDA (SNIS2026\base.mdb).
    # El formato zip pide barra normal, y con la invertida un Linux no ve
    # la carpeta: se encuentra un archivo con una barra en el nombre. Eso
    # se descubrio el 08/08 y estorbaria justo el dia que haga falta abrir
    # el respaldo desde fuera de Windows.
    $z = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
    foreach ($f in Get-ChildItem $trabajo -Recurse -File) {
        $rel = $f.FullName.Substring($trabajo.Length + 1).Replace('\','/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $z, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
    }
    $z.Dispose()
    $mb = [math]::Round((Get-Item $zip).Length/1MB,1)
    Bien ("{0}  ({1} MB)" -f (Split-Path $zip -Leaf), $mb)
} catch {
    Mal ("no se pudo empaquetar: {0}" -f $_.Exception.Message)
}

# ── Dejar sitio ───────────────────────────────────────────────────────
# En el Windows solo se guardan las ultimas: el historial largo lo lleva
# Linux, que tiene disco y ademas se lo lleva fuera del edificio.
Get-ChildItem $Destino -Filter "programas-*.zip" -EA SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip $Conservar |
    ForEach-Object { Remove-Item $_.FullName -Force -EA SilentlyContinue }

Remove-Item $trabajo -Recurse -Force -EA SilentlyContinue

$seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds)
Write-Output ""
if ($avisos.Count -eq 0) { Write-Output "LISTO en $seg s - sin avisos" }
else { Write-Output ("TERMINADO en {0} s CON {1} AVISO(S)" -f $seg, $avisos.Count) }
