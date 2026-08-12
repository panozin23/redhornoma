# ajustar-windows-bolivia.ps1 — Dejar el Windows del servidor en Bolivia.
#
# Tres cosas, y las tres importan por motivos distintos:
#
# 1 · LA ZONA HORARIA. Venía en «Central Standard Time (Mexico)», UTC-6, y
#     Bolivia es UTC-4. Ahora mismo la hora que se ve es correcta porque la
#     máquina virtual toma la del Linux, pero Windows CREE que está en México:
#     el día que sincronice con internet, el reloj salta dos horas atrás. Y
#     todo lo que SOAPS registre cerca de medianoche cae en el día anterior.
#     En un cambio de mes, eso va al informe equivocado del SEDES.
#     Se descubrió lo mismo en Cochabamba el 05/08/2026.
#
# 2 · EL TECLADO. El Linux de abajo usa el mapa de España («es», pc105) y el
#     Windows de dentro usaba el Latinoamericano. Las pulsaciones pasan tal
#     cual de uno a otro, así que cada uno las leía distinto: de ahí que las
#     tildes y la ñ no salieran. Se ponen LOS DOS mapas, con el de España
#     primero, y se cambia entre ellos con Alt+Mayús si hiciera falta.
#
# 3 · EL IDIOMA DE LOS PROGRAMAS ANTIGUOS. Estaba en es-MX. SOAPS es un
#     programa de Visual Basic 6, de los que no usan Unicode, y ese ajuste es
#     el que decide cómo lee los caracteres. Se pone es-BO.
#
# Uso:  powershell -ExecutionPolicy Bypass -File ajustar-windows-bolivia.ps1

Write-Output "=== ANTES ==="
Write-Output ("  zona horaria : " + (tzutil /g))
Write-Output ("  cultura      : " + (Get-Culture).Name)
Write-Output ("  sistema      : " + (Get-WinSystemLocale).Name)

Write-Output ""
Write-Output "=== 1. Zona horaria de Bolivia (UTC-4, sin horario de verano) ==="
try {
    Set-TimeZone -Id "SA Western Standard Time" -ErrorAction Stop
    Write-Output ("  ahora es : " + (tzutil /g))
} catch {
    Write-Output ("  NO se pudo: " + $_.Exception.Message)
}

Write-Output ""
Write-Output "=== 2. Idioma y teclados ==="
try {
    $lista = New-WinUserLanguageList -Language es-BO
    $lista[0].InputMethodTips.Clear()
    $lista[0].InputMethodTips.Add("400A:0000040A")   # teclado de España
    $lista[0].InputMethodTips.Add("400A:0000080A")   # teclado Latinoamericano
    Set-WinUserLanguageList $lista -Force
    Write-Output "  puestos los dos mapas, el de España el primero"
    Get-WinUserLanguageList | ForEach-Object {
        $_.InputMethodTips | ForEach-Object { Write-Output ("    teclado: " + $_) }
    }
} catch {
    Write-Output ("  NO se pudo: " + $_.Exception.Message)
}

Write-Output ""
Write-Output "=== 3. Formatos y programas antiguos ==="
try {
    Set-Culture es-BO
    Set-WinHomeLocation -GeoId 26      # Bolivia
    Set-WinSystemLocale es-BO          # esto es lo que lee SOAPS
    Write-Output "  cultura, ubicacion y sistema puestos en es-BO"
} catch {
    Write-Output ("  NO se pudo: " + $_.Exception.Message)
}

Write-Output ""
Write-Output "=== DESPUES ==="
Write-Output ("  zona horaria : " + (tzutil /g))
Write-Output ("  cultura      : " + (Get-Culture).Name)
Write-Output ("  sistema      : " + (Get-WinSystemLocale).Name + "   (cambia al reiniciar)")
Write-Output ("  fecha ahora  : " + (Get-Date -Format "dd/MM/yyyy HH:mm"))
Write-Output ""
Write-Output "  HACE FALTA REINICIAR para que el idioma de los programas"
Write-Output "  antiguos y los teclados queden puestos del todo."
