#Requires -RunAsAdministrator
<#  61-AppLocker-Pruefen.ps1
    Zeigt, was AppLocker blockiert hat oder im Audit-Modus blockiert haette.
    8003 = wuerde blockiert (Audit), 8004 = blockiert (Erzwingung), 8006/8007 = Skripte.
#>
[CmdletBinding()] param([int]$Anzahl = 60)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-AppLocker-Pruefen-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "AppLocker-Ereignisse"
    $logs = @(
        'Microsoft-Windows-AppLocker/EXE and DLL',
        'Microsoft-Windows-AppLocker/MSI and Script',
        'Microsoft-Windows-AppLocker/Packaged app-Execution',
        'Microsoft-Windows-AppLocker/Packaged app-Deployment'
    )
    foreach ($l in $logs) {
        try {
            $ev = Get-WinEvent -LogName $l -MaxEvents 500 -ErrorAction Stop |
                  Where-Object Id -in 8003,8004,8006,8007 |
                  Select-Object TimeCreated, Id, Message -First $Anzahl
            if ($ev) {
                Write-Info "---- $l ----"
                $ev | Format-List
            }
        } catch { }
    }
    Write-Info "Fehlt ein legitimes Programm: als Admin sauber unter Program Files installieren,"
    Write-Info "oder in AppLocker-Policy.xml eine Allow-Regel ergaenzen, dann 60-AppLocker-Einrichten.ps1 erneut."
    Write-Ok "Pruefung abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
