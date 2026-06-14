#Requires -RunAsAdministrator
<#  61-WDAC-Pruefen.ps1
    Zeigt die im Audit-Modus protokollierten Verstoesse, damit fehlende legitime
    Programme erkannt und nachgetragen werden koennen.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-WDAC-Pruefen-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "WDAC Audit-Verstoesse"
    Write-Info "Geblockte ausfuehrbare Dateien (3076 = Audit, 3077 = Erzwingung):"
    try {
        Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -MaxEvents 300 |
            Where-Object Id -in 3076,3077 |
            Select-Object TimeCreated, Id, Message -First 60 | Format-List
    } catch { Write-Info "Keine CodeIntegrity-Ereignisse gefunden." }
    Write-Info "Skript- und MSI-Verstoesse stehen unter 'Microsoft-Windows-AppLocker/MSI and Script'."
    Write-Info "Fehlt ein legitimes Programm: als Admin sauber unter Program Files installieren,"
    Write-Info "dann C:\WDAC\Base.xml loeschen und 60-WDAC-Audit.ps1 erneut laufen lassen."
    Write-Ok "Pruefung abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
